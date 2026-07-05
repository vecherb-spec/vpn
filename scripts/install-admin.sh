#!/usr/bin/env bash
# install-admin.sh — установка веб-админки amneziawg-web
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
INSTALL_DIR="${PROJECT_DIR}/vendor/amneziawg-install"
WEB_SCRIPT="${INSTALL_DIR}/amneziawg-web.sh"

generate_password_hash() {
  local password="$1"
  ADMIN_PASSWORD="${password}" python3 -c "
import os
from argon2 import PasswordHasher
print(PasswordHasher().hash(os.environ['ADMIN_PASSWORD']))
" 2>/dev/null || {
    echo "Ошибка: установите argon2: pip3 install argon2-cffi" >&2
    exit 1
  }
}

install_rust_if_needed() {
  if command -v cargo >/dev/null 2>&1; then
    return 0
  fi
  echo "Rust не найден, будет установлен автоматически..."
}

run_web_installer() {
  if [[ ! -f "${WEB_SCRIPT}" ]]; then
    echo "Ошибка: ${WEB_SCRIPT} не найден. Сначала запустите install-vpn.sh" >&2
    exit 1
  fi

  chmod +x "${WEB_SCRIPT}"

  local password_hash
  password_hash="$(generate_password_hash "${ADMIN_PASSWORD}")"

  local -a args=(
    install
    --non-interactive
    --source-dir "${INSTALL_DIR}/amneziawg-web"
    --install-rust
    --username "${ADMIN_USERNAME:-admin}"
    --password-hash "${password_hash}"
    --host "${AWG_WEB_HOST:-127.0.0.1}"
    --port "${AWG_WEB_PORT:-8080}"
    --poll-interval "${AWG_POLL_INTERVAL:-30}"
    --session-ttl "${AUTH_SESSION_TTL_SECS:-86400}"
    --force
  )

  echo "Устанавливаем веб-админку..."
  bash "${WEB_SCRIPT}" "${args[@]}"

  # Включаем secure cookie, если используется Caddy
  if [[ "${INSTALL_CADDY:-n}" == "y" ]]; then
    local env_file="/etc/amneziawg-web/env.conf"
    if [[ -f "${env_file}" ]]; then
      if grep -q '^AUTH_SECURE_COOKIE=' "${env_file}"; then
        sed -i 's/^AUTH_SECURE_COOKIE=.*/AUTH_SECURE_COOKIE=true/' "${env_file}"
      else
        echo 'AUTH_SECURE_COOKIE=true' >> "${env_file}"
      fi
      systemctl restart amneziawg-web 2>/dev/null || true
    fi
  fi
}

install_rust_if_needed
run_web_installer

echo "Веб-админка установлена."
