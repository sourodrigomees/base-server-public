#!/usr/bin/env bash
set -Eeuo pipefail

readonly PROJECT_DIR="${BASE_SERVER_PROJECT_DIR:-/opt/base-server}"
readonly INSTALL_SCRIPT="${BASE_SERVER_INSTALL_SCRIPT:-install.sh}"
readonly GIT_HOST="${BASE_SERVER_GIT_HOST:-github.com}"
readonly REPOSITORY_SLUG="${BASE_SERVER_REPOSITORY_SLUG:-sourodrigomees/base-server}"
readonly SSH_DIR="/root/.ssh"
readonly SSH_KEY_PATH="${SSH_DIR}/id_ed25519"

CLONE_METHOD="${BASE_SERVER_CLONE_METHOD:-}"
REPOSITORY_URL=""

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

choose_clone_method() {
  if [[ -n "${CLONE_METHOD}" ]]; then
    case "${CLONE_METHOD,,}" in
      ssh|1) CLONE_METHOD="ssh" ;;
      https|http|2) CLONE_METHOD="https" ;;
      *) fail "BASE_SERVER_CLONE_METHOD inválido: use 'ssh' ou 'https'." ;;
    esac
    return
  fi

  require_tty "não há um terminal disponível para escolher o método de clone. Defina BASE_SERVER_CLONE_METHOD=ssh|https."

  while true; do
    printf '\nComo deseja clonar o repositório %s?\n' "${REPOSITORY_SLUG}" >/dev/tty
    printf '  [1] SSH   - cola uma chave privada autorizada (padrão)\n' >/dev/tty
    printf '  [2] HTTPS - usa um fine-grained personal access token do GitHub\n' >/dev/tty
    printf 'Escolha [1/2]: ' >/dev/tty

    local answer=""
    if ! read -r answer </dev/tty; then
      fail "não foi possível ler a escolha do terminal. Rode o instalador em um terminal interativo ou defina BASE_SERVER_CLONE_METHOD=ssh|https."
    fi

    case "${answer,,}" in
      ''|1|ssh) CLONE_METHOD="ssh"; return ;;
      2|https|http) CLONE_METHOD="https"; return ;;
      *) printf '\nOpção inválida.\n' >/dev/tty ;;
    esac
  done
}

install_dependencies() {
  local packages=(git ca-certificates)
  local missing=0

  command -v git >/dev/null 2>&1 || missing=1

  if [[ "${CLONE_METHOD}" == "ssh" ]]; then
    packages+=(openssh-client)
    command -v ssh >/dev/null 2>&1 || missing=1
  fi

  if [[ ${missing} -eq 1 ]]; then
    apt-get update
    apt-get install -y "${packages[@]}"
  fi
}

setup_ssh_auth() {
  install -d -m 700 "${SSH_DIR}"

  if [[ ! -s "${SSH_KEY_PATH}" ]]; then
    require_tty "não há um terminal disponível para receber a chave SSH."

    TEMP_KEY_FILE="$(mktemp)"
    trap 'rm -f "${TEMP_KEY_FILE:-}"' EXIT

    printf '\nCole a chave privada SSH que possui acesso ao repositório base-server.\n'
    printf 'Quando terminar, pressione Enter e depois Ctrl-D:\n\n'
    cat </dev/tty >"${TEMP_KEY_FILE}"

    if ! grep -Fq 'BEGIN OPENSSH PRIVATE KEY' "${TEMP_KEY_FILE}" && \
       ! grep -Fq 'BEGIN RSA PRIVATE KEY' "${TEMP_KEY_FILE}"; then
      fail "a chave privada SSH não foi reconhecida."
    fi

    install -m 600 "${TEMP_KEY_FILE}" "${SSH_KEY_PATH}"
  else
    log "Usando a chave SSH existente em ${SSH_KEY_PATH}."
  fi

  touch "${SSH_DIR}/known_hosts"
  chmod 600 "${SSH_DIR}/known_hosts"
  if ! ssh-keygen -F "${GIT_HOST}" -f "${SSH_DIR}/known_hosts" >/dev/null 2>&1; then
    ssh-keyscan -H "${GIT_HOST}" >>"${SSH_DIR}/known_hosts" 2>/dev/null
  fi

  cat >"${SSH_DIR}/config" <<EOF
Host ${GIT_HOST}
  HostName ${GIT_HOST}
  User git
  IdentityFile ${SSH_KEY_PATH}
  IdentitiesOnly yes
EOF
  chmod 600 "${SSH_DIR}/config"

  REPOSITORY_URL="${BASE_SERVER_REPOSITORY_URL:-git@${GIT_HOST}:${REPOSITORY_SLUG}.git}"
}

setup_https_auth() {
  if [[ -n "${BASE_SERVER_REPOSITORY_URL:-}" ]]; then
    REPOSITORY_URL="${BASE_SERVER_REPOSITORY_URL}"
    return
  fi

  require_tty "não há um terminal disponível para receber o token do GitHub."

  printf '\nInforme o fine-grained personal access token do GitHub com permissão\n'
  printf '"Contents: Read" no repositório %s.\n' "${REPOSITORY_SLUG}"
  printf 'O token não será exibido nem gravado em disco.\n\n'
  printf 'Token: '

  local token=""
  read -rs token </dev/tty || true
  printf '\n'

  [[ -n "${token}" ]] || fail "nenhum token informado."

  REPOSITORY_URL="https://x-access-token:${token}@${GIT_HOST}/${REPOSITORY_SLUG}.git"
  unset token
}

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  fail "execute o instalador como root: curl -fsSL <URL> | sudo bash"
fi

if ! command -v apt-get >/dev/null 2>&1; then
  fail "este instalador requer uma distribuição baseada em Debian/Ubuntu (apt-get)."
fi

export DEBIAN_FRONTEND=noninteractive

choose_clone_method

log "Verificando dependências..."
install_dependencies

if [[ "${CLONE_METHOD}" == "ssh" ]]; then
  setup_ssh_auth
else
  setup_https_auth
fi

if [[ -e "${PROJECT_DIR}" ]]; then
  fail "o diretório ${PROJECT_DIR} já existe. Remova-o ou use BASE_SERVER_PROJECT_DIR com outro caminho."
fi

log "Baixando o base-server (${REPOSITORY_SLUG}, via ${CLONE_METHOD}) em ${PROJECT_DIR}..."
git clone "${REPOSITORY_URL}" "${PROJECT_DIR}"

if [[ "${CLONE_METHOD}" == "https" ]]; then
  git -C "${PROJECT_DIR}" remote set-url origin "https://${GIT_HOST}/${REPOSITORY_SLUG}.git"
fi
REPOSITORY_URL=""

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
