#!/usr/bin/env bash
# bootstrap-awg.sh — автоматическая настройка сервера и установка AmneziaWG 2.0 через API панели
set -euo pipefail

APP_PORT="${APP_PORT:-5000}"
PANEL_URL="http://127.0.0.1:${APP_PORT}"
SSH_HOST="${SSH_HOST:-127.0.0.1}"
SSH_USER="${SSH_USER:-root}"
SSH_PORT="${SSH_PORT:-22}"
AWG2_PORT="${AWG2_PORT:-51820}"
SERVER_NAME="${SERVER_NAME:-Local VPN}"

LOGIN_USER="${ADMIN_USERNAME:-admin}"
LOGIN_PASS="${ADMIN_PASSWORD:-admin}"

if [[ -z "${SSH_PASSWORD:-}" ]] && [[ -z "${SSH_PRIVATE_KEY:-}" ]]; then
  echo "Ошибка: укажите SSH_PASSWORD или SSH_PRIVATE_KEY в .env" >&2
  exit 1
fi

COOKIE_JAR="$(mktemp)"
trap 'rm -f "${COOKIE_JAR}"' EXIT

panel_request() {
  local method="$1"
  local path="$2"
  local data="${3:-}"

  if [[ -n "${data}" ]]; then
    curl -sf -b "${COOKIE_JAR}" -c "${COOKIE_JAR}" \
      -X "${method}" "${PANEL_URL}${path}" \
      -H "Content-Type: application/json" \
      -d "${data}"
  else
    curl -sf -b "${COOKIE_JAR}" -c "${COOKIE_JAR}" \
      -X "${method}" "${PANEL_URL}${path}"
  fi
}

wait_for_panel() {
  for _ in $(seq 1 60); do
    if python3 -c "import socket; s=socket.socket(); s.settimeout(1); s.connect(('127.0.0.1', ${APP_PORT})); s.close()" 2>/dev/null; then
      return 0
    fi
    sleep 2
  done
  echo "Ошибка: панель не отвечает на ${PANEL_URL}" >&2
  exit 1
}

login() {
  panel_request POST /api/auth/login \
    "{\"username\":\"${LOGIN_USER}\",\"password\":\"${LOGIN_PASS}\"}" >/dev/null
}

panel_request_allow_fail() {
  local method="$1"
  local path="$2"
  local data="${3:-}"
  local http_code

  if [[ -n "${data}" ]]; then
    http_code="$(curl -s -o /tmp/awp_resp.json -w '%{http_code}' \
      -b "${COOKIE_JAR}" -c "${COOKIE_JAR}" \
      -X "${method}" "${PANEL_URL}${path}" \
      -H "Content-Type: application/json" \
      -d "${data}")"
  else
    http_code="$(curl -s -o /tmp/awp_resp.json -w '%{http_code}' \
      -b "${COOKIE_JAR}" -c "${COOKIE_JAR}" \
      -X "${method}" "${PANEL_URL}${path}")"
  fi
  echo "${http_code}"
}

get_server_id() {
  local code
  code="$(panel_request_allow_fail POST "/api/servers/0/check")"
  if [[ "${code}" == "200" ]]; then
    echo "0"
    return 0
  fi

  local payload
  if [[ -n "${SSH_PRIVATE_KEY:-}" ]]; then
    payload="$(jq -n \
      --arg host "${SSH_HOST}" \
      --arg user "${SSH_USER}" \
      --argjson port "${SSH_PORT}" \
      --arg name "${SERVER_NAME}" \
      --arg key "${SSH_PRIVATE_KEY}" \
      '{host: $host, username: $user, ssh_port: $port, name: $name, private_key: $key}')"
  else
    payload="$(jq -n \
      --arg host "${SSH_HOST}" \
      --arg user "${SSH_USER}" \
      --argjson port "${SSH_PORT}" \
      --arg name "${SERVER_NAME}" \
      --arg pass "${SSH_PASSWORD}" \
      '{host: $host, username: $user, ssh_port: $port, name: $name, password: $pass}')"
  fi

  panel_request POST /api/servers/add "${payload}" | jq -r '.server_id'
}

is_awg2_installed() {
  local server_id="$1"
  local status
  status="$(panel_request POST "/api/servers/${server_id}/check")"
  echo "${status}" | jq -e '.protocols.awg2.container_exists == true' >/dev/null 2>&1
}

install_awg2() {
  local server_id="$1"
  echo "Устанавливаем AmneziaWG 2.0 (это может занять несколько минут)..."
  curl -sf --max-time 600 -b "${COOKIE_JAR}" -c "${COOKIE_JAR}" \
    -X POST "${PANEL_URL}/api/servers/${server_id}/install" \
    -H "Content-Type: application/json" \
    -d "{\"protocol\":\"awg2\",\"port\":\"${AWG2_PORT}\"}"
}

wait_for_panel
login

server_id="$(get_server_id)"
echo "Сервер добавлен в панель (id=${server_id})."

if is_awg2_installed "${server_id}"; then
  echo "AmneziaWG 2.0 уже установлен."
else
  install_awg2 "${server_id}"
  echo "AmneziaWG 2.0 установлен на порту UDP ${AWG2_PORT}."
fi
