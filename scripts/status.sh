#!/usr/bin/env bash
# status.sh — проверка статуса VPN-сервиса и админки
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
WEB_SCRIPT="${PROJECT_DIR}/vendor/amneziawg-install/amneziawg-web.sh"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'; RESET='\033[0m'

status_line() {
  local name="$1"
  local state="$2"
  if [[ "${state}" == "active" ]] || [[ "${state}" == "running" ]]; then
    printf '  %-20s %b%s%b\n' "${name}" "${GREEN}" "${state}" "${RESET}"
  else
    printf '  %-20s %b%s%b\n' "${name}" "${RED}" "${state:-inactive}" "${RESET}"
  fi
}

printf '\n=== Статус VPN-сервиса AmneziaWG 2.0 ===\n\n'

# VPN interface
if ip link show awg0 &>/dev/null; then
  status_line "VPN (awg0)" "active"
  peers="$(awg show awg0 peers 2>/dev/null | wc -l || echo 0)"
  printf '  %-20s %s подключено\n' "Пиры" "${peers}"
else
  status_line "VPN (awg0)" "inactive"
fi

# systemd services
for svc in "awg-quick@awg0" "amneziawg-web" "caddy"; do
  if systemctl list-unit-files "${svc}.service" &>/dev/null 2>&1; then
    state="$(systemctl is-active "${svc}" 2>/dev/null || echo inactive)"
    status_line "${svc}" "${state}"
  fi
done

# Web panel status
if [[ -f "${WEB_SCRIPT}" ]]; then
  printf '\n'
  bash "${WEB_SCRIPT}" status 2>/dev/null || true
fi

# Listening ports
printf '\n=== Порты ===\n'
ss -ulnp 2>/dev/null | grep -E 'awg|51820|51821' || echo "  VPN UDP-порт не обнаружен"
ss -tlnp 2>/dev/null | grep -E ':8080|:443' || true

printf '\n'
