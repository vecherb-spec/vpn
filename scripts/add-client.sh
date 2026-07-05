#!/usr/bin/env bash
# add-client.sh — управление VPN-клиентами через Amnezia Web Panel API
#
# Использование:
#   ./scripts/add-client.sh <имя>              # добавить клиента AWG2
#   ./scripts/add-client.sh --remove <имя>     # удалить клиента
#   ./scripts/add-client.sh --list             # список клиентов

set -euo pipefail

APP_PORT="${APP_PORT:-5000}"
PANEL_URL="http://127.0.0.1:${APP_PORT}"
PROTOCOL="${AWG_PROTOCOL:-awg2}"
SERVER_ID="${SERVER_ID:-0}"
LOGIN_USER="${ADMIN_USERNAME:-admin}"
LOGIN_PASS="${ADMIN_PASSWORD:-admin}"

COOKIE_JAR="$(mktemp)"
trap 'rm -f "${COOKIE_JAR}"' EXIT

panel_login() {
  curl -sf -c "${COOKIE_JAR}" -b "${COOKIE_JAR}" \
    -X POST "${PANEL_URL}/api/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"${LOGIN_USER}\",\"password\":\"${LOGIN_PASS}\"}" >/dev/null
}

panel_get() {
  curl -sf -b "${COOKIE_JAR}" "${PANEL_URL}$1"
}

panel_post() {
  curl -sf -b "${COOKIE_JAR}" \
    -X POST "${PANEL_URL}$1" \
    -H "Content-Type: application/json" \
    -d "$2"
}

find_client_id() {
  local name="$1"
  panel_get "/api/servers/${SERVER_ID}/connections?protocol=${PROTOCOL}" \
    | jq -r --arg name "${name}" '.clients[] | select(.name == $name) | .client_id' \
    | head -1
}

case "${1:-}" in
  --list)
    panel_login
    panel_get "/api/servers/${SERVER_ID}/connections?protocol=${PROTOCOL}" \
      | jq -r '.clients[] | "\(.name)\t\(.client_id)\t\(.enabled // true)"'
    ;;
  --remove)
    if [[ -z "${2:-}" ]]; then
      echo "Использование: $0 --remove <имя>" >&2
      exit 1
    fi
    panel_login
    client_id="$(find_client_id "${2}")"
    if [[ -z "${client_id}" ]]; then
      echo "Клиент '${2}' не найден." >&2
      exit 1
    fi
    panel_post "/api/servers/${SERVER_ID}/connections/remove" \
      "{\"protocol\":\"${PROTOCOL}\",\"client_id\":\"${client_id}\"}" >/dev/null
    echo "Клиент '${2}' удалён."
    ;;
  --help|-h)
    cat << 'EOF'
Управление VPN-клиентами через Amnezia Web Panel

Использование:
  ./scripts/add-client.sh <имя>         Добавить клиента AmneziaWG 2.0
  ./scripts/add-client.sh --remove <имя> Удалить клиента
  ./scripts/add-client.sh --list         Список клиентов

Конфиг скачивается через веб-панель или из ответа API.
EOF
    ;;
  "")
    echo "Использование: $0 <имя> | --remove <имя> | --list" >&2
    exit 1
    ;;
  *)
    panel_login
    result="$(panel_post "/api/servers/${SERVER_ID}/connections/add" \
      "{\"protocol\":\"${PROTOCOL}\",\"name\":\"${1}\"}")"

    echo "Клиент '${1}' создан."
    echo ""
    echo "${result}" | jq -r '.config // empty'
    echo ""
    echo "Скачать конфиг также можно в веб-панели: Сервер → AmneziaWG 2.0 → Клиенты"
    ;;
esac
