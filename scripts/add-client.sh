#!/usr/bin/env bash
# add-client.sh — управление VPN-клиентами
#
# Использование:
#   sudo ./scripts/add-client.sh <имя>       # добавить клиента
#   sudo ./scripts/add-client.sh --remove <имя>  # удалить клиента
#   sudo ./scripts/add-client.sh --list      # список клиентов

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
INSTALL_SCRIPT="${PROJECT_DIR}/vendor/amneziawg-install/amneziawg-install.sh"

if [[ ! -f "${INSTALL_SCRIPT}" ]]; then
  echo "Ошибка: VPN не установлен. Запустите: sudo ./install.sh" >&2
  exit 1
fi

chmod +x "${INSTALL_SCRIPT}"

case "${1:-}" in
  --list)
    bash "${INSTALL_SCRIPT}" --list-clients
    ;;
  --remove)
    if [[ -z "${2:-}" ]]; then
      echo "Использование: $0 --remove <имя>" >&2
      exit 1
    fi
    bash "${INSTALL_SCRIPT}" --remove-client "${2}"
    echo "Клиент '${2}' удалён."
    ;;
  --help|-h)
    cat << 'EOF'
Управление VPN-клиентами AmneziaWG 2.0

Использование:
  sudo ./scripts/add-client.sh <имя>         Добавить клиента
  sudo ./scripts/add-client.sh --remove <имя> Удалить клиента
  sudo ./scripts/add-client.sh --list         Список клиентов

Конфиг клиента сохраняется в ~/awg0-client-<имя>.conf
Импортируйте его в приложение AmneziaWG.
EOF
    ;;
  "")
    echo "Использование: $0 <имя> | --remove <имя> | --list" >&2
    exit 1
    ;;
  *)
    bash "${INSTALL_SCRIPT}" --add-client "${1}"
    local_config="${HOME}/awg0-client-${1}.conf"
    if [[ -f "${local_config}" ]]; then
      echo ""
      echo "Конфиг клиента: ${local_config}"
      if command -v qrencode >/dev/null 2>&1; then
        echo ""
        echo "QR-код для мобильного приложения:"
        qrencode -t ANSIUTF8 < "${local_config}"
      fi
    fi
    ;;
esac
