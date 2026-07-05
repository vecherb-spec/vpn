#!/usr/bin/env bash
# setup-caddy.sh — настройка Caddy reverse proxy для веб-админки
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CADDY_TEMPLATE="${PROJECT_DIR}/config/caddy/Caddyfile.example"
CADDY_CONFIG="/etc/caddy/Caddyfile"

: "${ADMIN_DOMAIN:?Укажите ADMIN_DOMAIN в .env}"
: "${CADDY_EMAIL:?Укажите CADDY_EMAIL в .env}"

APP_PORT="${APP_PORT:-5000}"
ADMIN_ALLOWED_IPS="${ADMIN_ALLOWED_IPS:-}"

install_caddy() {
  if command -v caddy >/dev/null 2>&1; then
    echo "Caddy уже установлен."
    return 0
  fi

  echo "Устанавливаем Caddy..."
  apt-get update -qq
  apt-get install -y -qq debian-keyring debian-archive-keyring apt-transport-https curl

  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
    | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg 2>/dev/null

  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
    | tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null

  apt-get update -qq
  apt-get install -y -qq caddy
}

generate_caddyfile() {
  local allowed_ips_block=""
  local respond_block=""

  if [[ -n "${ADMIN_ALLOWED_IPS}" ]]; then
    IFS=',' read -ra IPS <<< "${ADMIN_ALLOWED_IPS}"
    for ip in "${IPS[@]}"; do
      ip="$(echo "${ip}" | xargs)"
      allowed_ips_block+="    @allowed remote_ip ${ip}"$'\n'
    done
    allowed_ips_block+="    handle @allowed {"$'\n'
    allowed_ips_block+="        reverse_proxy 127.0.0.1:${APP_PORT}"$'\n'
    allowed_ips_block+="    }"$'\n'
    respond_block='    respond "Forbidden" 403'
  else
    allowed_ips_block="    reverse_proxy 127.0.0.1:${APP_PORT}"$'\n'
  fi

  mkdir -p /etc/caddy
  cat > "${CADDY_CONFIG}" << EOF
# AmneziaWG VPN Admin Panel
# Сгенерировано setup-caddy.sh

{
    email ${CADDY_EMAIL}
}

${ADMIN_DOMAIN} {
${allowed_ips_block}${respond_block}
}
EOF

  echo "Caddyfile создан: ${CADDY_CONFIG}"
}

enable_and_start() {
  systemctl enable caddy
  systemctl restart caddy
  echo "Caddy запущен."
}

install_caddy
generate_caddyfile
enable_and_start

echo "Reverse proxy настроен: https://${ADMIN_DOMAIN}"
