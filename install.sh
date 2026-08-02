#!/usr/bin/env bash
set -Eeuo pipefail

readonly REPOSITORY_URL="${BASE_SERVER_REPOSITORY_URL:-git@github.com:sourodrigomees/base-server.git}"
readonly PROJECT_DIR="${BASE_SERVER_PROJECT_DIR:-/opt/base-server}"
readonly INSTALL_SCRIPT="${BASE_SERVER_INSTALL_SCRIPT:-install.sh}"
readonly GIT_HOST="${BASE_SERVER_GIT_HOST:-github.com}"
readonly SSH_DIR="/root/.ssh"
readonly SSH_KEY_PATH="${SSH_DIR}/id_ed25519"

log() {
  printf '\n\033[1;32m[base-server]\033[0m %s\n' "$*"
}

fail() {
  printf '\n\033[1;31m[base-server] Erro:\033[0m %s\n' "$*" >&2
  exit 1
}

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  fail "execute o instalador como root: curl -fsSL <URL> | sudo bash"
fi

if ! command -v apt-get >/dev/null 2>&1; then
  fail "este instalador requer uma distribuição baseada em Debian/Ubuntu (apt-get)."
fi

export DEBIAN_FRONTEND=noninteractive

log "Verificando dependências..."
if ! command -v git >/dev/null 2>&1 || ! command -v ssh >/dev/null 2>&1; then
  apt-get update
  apt-get install -y git openssh-client ca-certificates
fi

install -d -m 700 "${SSH_DIR}"

if [[ ! -s "${SSH_KEY_PATH}" ]]; then
  [[ -r /dev/tty ]] || fail "não há um terminal disponível para receber a chave SSH."

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

if [[ -e "${PROJECT_DIR}" ]]; then
  fail "o diretório ${PROJECT_DIR} já existe. Remova-o ou use BASE_SERVER_PROJECT_DIR com outro caminho."
fi

log "Baixando o base-server em ${PROJECT_DIR}..."
git clone "${REPOSITORY_URL}" "${PROJECT_DIR}"

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
