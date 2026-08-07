#!/usr/bin/env bash
set -Eeuo pipefail

readonly PROJECT_DIR="${BASE_SERVER_PROJECT_DIR:-/opt/base-server}"
readonly INSTALL_SCRIPT="${BASE_SERVER_INSTALL_SCRIPT:-install.sh}"
readonly GIT_HOST="${BASE_SERVER_GIT_HOST:-github.com}"
readonly REPOSITORY_SLUG="${BASE_SERVER_REPOSITORY_SLUG:-sourodrigomees/base-server}"
readonly CREDENTIALS_FILE="${BASE_SERVER_CREDENTIALS_FILE:-/root/.git-credentials}"

REPOSITORY_URL=""
GIT_TOKEN=""

log() {
  printf '\n\033[1;32m[base-server]\033[0m %s\n' "$*"
}

fail() {
  printf '\n\033[1;31m[base-server] Erro:\033[0m %s\n' "$*" >&2
  exit 1
}

require_tty() {
  [[ -r /dev/tty ]] || fail "$1"
}

install_dependencies() {
  if ! command -v git >/dev/null 2>&1; then
    apt-get update
    apt-get install -y git ca-certificates
  fi
}

prompt_github_token() {
  if [[ -n "${BASE_SERVER_GITHUB_TOKEN:-}" ]]; then
    GIT_TOKEN="${BASE_SERVER_GITHUB_TOKEN}"
    return
  fi

  require_tty "não há um terminal disponível para receber o token do GitHub. Defina BASE_SERVER_GITHUB_TOKEN."

  printf '\nInforme o fine-grained personal access token do GitHub com permissão\n'
  printf '"Contents: Read" no repositório %s.\n' "${REPOSITORY_SLUG}"
  printf 'O token não aparece na tela enquanto é digitado.\n\n'
  printf 'Token: '

  read -rs GIT_TOKEN </dev/tty || true
  printf '\n'

  [[ -n "${GIT_TOKEN}" ]] || fail "nenhum token informado."
}

# Grava o token no formato do credential helper "store" do Git, para que os
# "git pull" seguintes funcionem sem pedir a credencial novamente. O token fica
# fora de .git/config e do remote, apenas neste arquivo com permissão 600.
save_git_credentials() {
  local entry="https://x-access-token:${GIT_TOKEN}@${GIT_HOST}"
  local existing=""

  if [[ -s "${CREDENTIALS_FILE}" ]]; then
    existing="$(grep -v "@${GIT_HOST}\$" "${CREDENTIALS_FILE}" || true)"
  fi

  install -m 600 /dev/null "${CREDENTIALS_FILE}"
  if [[ -n "${existing}" ]]; then
    printf '%s\n' "${existing}" >>"${CREDENTIALS_FILE}"
  fi
  printf '%s\n' "${entry}" >>"${CREDENTIALS_FILE}"

  log "Token salvo em ${CREDENTIALS_FILE} (permissão 600) para as próximas atualizações."
}

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  fail "execute o instalador como root: curl -fsSL <URL> | sudo bash"
fi

if ! command -v apt-get >/dev/null 2>&1; then
  fail "este instalador requer uma distribuição baseada em Debian/Ubuntu (apt-get)."
fi

export DEBIAN_FRONTEND=noninteractive

log "Verificando dependências..."
install_dependencies

prompt_github_token
REPOSITORY_URL="https://x-access-token:${GIT_TOKEN}@${GIT_HOST}/${REPOSITORY_SLUG}.git"

if [[ -e "${PROJECT_DIR}" ]]; then
  fail "o diretório ${PROJECT_DIR} já existe. Remova-o ou use BASE_SERVER_PROJECT_DIR com outro caminho."
fi

log "Baixando o base-server (${REPOSITORY_SLUG}) em ${PROJECT_DIR}..."
git clone "${REPOSITORY_URL}" "${PROJECT_DIR}"
REPOSITORY_URL=""

# O remote fica sem credencial; a autenticação passa a vir do credential helper.
git -C "${PROJECT_DIR}" remote set-url origin "https://${GIT_HOST}/${REPOSITORY_SLUG}.git"
git -C "${PROJECT_DIR}" config credential.helper "store --file=${CREDENTIALS_FILE}"
save_git_credentials
GIT_TOKEN=""

readonly INSTALL_SCRIPT_PATH="${PROJECT_DIR}/${INSTALL_SCRIPT}"
[[ -f "${INSTALL_SCRIPT_PATH}" ]] || \
  fail "o projeto foi baixado, mas ${INSTALL_SCRIPT_PATH} não foi encontrado."

chmod +x "${INSTALL_SCRIPT_PATH}"
log "Executando o instalador do base-server..."
(
  cd "${PROJECT_DIR}"
  bash "./${INSTALL_SCRIPT}" </dev/tty
)

log "Base-server instalado e executado com sucesso."
log "Para atualizar depois: sudo git -C ${PROJECT_DIR} pull"
