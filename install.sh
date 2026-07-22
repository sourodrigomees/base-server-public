#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Execute com sudo: sudo ./install.sh" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
if ! command -v git >/dev/null 2>&1 || ! command -v ssh >/dev/null 2>&1; then
  apt-get update
  apt-get install -y git openssh-client ca-certificates
fi

SSH_DIR=/root/.ssh
SSH_KEY_PATH=${SSH_DIR}/id_ed25519
GIT_HOST=github.com
REPOSITORY_URL=git@github.com:sourodrigomees/base-server.git
PROJECT_DIR=/opt/base-server

TEMP_KEY_FILE="$(mktemp)"
trap 'rm -f "${TEMP_KEY_FILE}"' EXIT

echo "Cole o conteúdo da chave privada SSH id_ed25519 e finalize com Ctrl-D:"
cat > "${TEMP_KEY_FILE}"

grep -Fq 'BEGIN OPENSSH PRIVATE KEY' "${TEMP_KEY_FILE}" || \
  grep -Fq 'BEGIN RSA PRIVATE KEY' "${TEMP_KEY_FILE}" || {
    echo "A chave privada SSH não foi reconhecida." >&2
    exit 1
  }

install -d -m 700 "${SSH_DIR}"
install -m 600 "${TEMP_KEY_FILE}" "${SSH_KEY_PATH}"
ssh-keyscan -H "${GIT_HOST}" >> /root/.ssh/known_hosts 2>/dev/null
chmod 600 /root/.ssh/known_hosts

cat > /root/.ssh/config <<EOF
Host ${GIT_HOST}
  HostName ${GIT_HOST}
  User git
  IdentityFile /root/.ssh/id_ed25519
  IdentitiesOnly yes
EOF
chmod 600 /root/.ssh/config

if [[ -e "${PROJECT_DIR}" ]]; then
  echo "O diretório já existe: ${PROJECT_DIR}" >&2
  exit 1
fi

git clone "${REPOSITORY_URL}" "${PROJECT_DIR}"
chmod +x "${PROJECT_DIR}/install.sh" 2>/dev/null || true

echo "Projeto clonado em ${PROJECT_DIR}."
