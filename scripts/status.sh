#!/usr/bin/env bash
# status.sh — проверка статуса Amnezia Web Panel и AmneziaWG 2.0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

APP_PORT="${APP_PORT:-5000}"
AWG2_PORT="${AWG2_PORT:-51820}"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'; RESET='\033[0m'

status_line() {
  local name="$1"
  local state="$2"
  if [[ "${state}" == "active" ]] || [[ "${state}" == "running" ]] || [[ "${state}" == "ok" ]]; then
    printf '  %-24s %b%s%b\n' "${name}" "${GREEN}" "${state}" "${RESET}"
  else
    printf '  %-24s %b%s%b\n' "${name}" "${RED}" "${state:-inactive}" "${RESET}"
  fi
}

printf '\n=== Статус VPN-сервиса (Amnezia Web Panel) ===\n\n'

# Docker panel
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^amnezia_panel$'; then
  status_line "Amnezia Web Panel" "running"
else
  status_line "Amnezia Web Panel" "stopped"
fi

# Panel health
if python3 -c "import socket; s=socket.socket(); s.settimeout(1); s.connect(('127.0.0.1', ${APP_PORT})); s.close()" 2>/dev/null; then
  status_line "Panel API" "ok"
else
  status_line "Panel API" "unavailable"
fi

# Docker service
if systemctl is-active docker &>/dev/null; then
  status_line "Docker" "active"
else
  status_line "Docker" "inactive"
fi

# AWG2 container
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^amnezia-awg2$'; then
  status_line "AmneziaWG 2.0 (awg2)" "running"
else
  status_line "AmneziaWG 2.0 (awg2)" "not installed"
fi

# Caddy
if systemctl list-unit-files caddy.service &>/dev/null 2>&1; then
  state="$(systemctl is-active caddy 2>/dev/null || echo inactive)"
  status_line "Caddy" "${state}"
fi

printf '\n=== Порты ===\n'
ss -tlnp 2>/dev/null | grep -E ":${APP_PORT}|:443 " || true
ss -ulnp 2>/dev/null | grep -E ":${AWG2_PORT} " || true

printf '\n=== Docker ===\n'
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null \
  | grep -E 'amnezia|NAMES' || echo "  Нет контейнеров Amnezia"

printf '\n'
