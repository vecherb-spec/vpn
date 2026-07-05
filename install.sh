#!/usr/bin/env bash
# install.sh — развёртывание VPN-сервиса AmneziaWG 2.0 с Amnezia Web Panel
#
# Использование:
#   sudo ./install.sh              # интерактивная установка
#   sudo AUTO_INSTALL=y ./install.sh  # автоматическая установка
#
# Требования: Ubuntu 20.04/22.04/24.04 или Debian 11+, root-доступ

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="${SCRIPT_DIR}/scripts"
ENV_FILE="${SCRIPT_DIR}/.env"

if [[ -t 1 ]] && [[ -z "${NO_COLOR+x}" ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
  BLUE='\033[0;34m'; BOLD='\033[1m'; RESET='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; BOLD=''; RESET=''
fi

info()  { printf '%b%s%b\n' "${BLUE}" "$*" "${RESET}"; }
ok()    { printf '%b%s%b\n' "${GREEN}" "$*" "${RESET}"; }
warn()  { printf '%b%s%b\n' "${YELLOW}" "$*" "${RESET}"; }
err()   { printf '%b%s%b\n' "${RED}" "$*" "${RESET}" >&2; }

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    err "Запустите скрипт от root: sudo $0"
    exit 1
  fi
}

check_os() {
  if [[ ! -f /etc/os-release ]]; then
    err "Неподдерживаемая ОС."
    exit 1
  fi
  # shellcheck source=/dev/null
  source /etc/os-release
  case "${ID:-}" in
    ubuntu|debian) ;;
    *) warn "ОС ${ID} не проверена официально панелью. Продолжаем на свой риск." ;;
  esac
}

load_env() {
  if [[ -f "${ENV_FILE}" ]]; then
    info "Загружаем конфигурацию из ${ENV_FILE}"
    set -a
    # shellcheck source=/dev/null
    source "${ENV_FILE}"
    set +a
  else
    warn "Файл .env не найден. Скопируйте: cp .env.example .env"
  fi

  export APP_PORT="${APP_PORT:-5000}"
  export AWG2_PORT="${AWG2_PORT:-51820}"
  export ADMIN_USERNAME="${ADMIN_USERNAME:-admin}"
  export ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin}"
  export SSH_HOST="${SSH_HOST:-127.0.0.1}"
  export SSH_USER="${SSH_USER:-root}"
  export SSH_PORT="${SSH_PORT:-22}"
  export PANEL_IMAGE="${PANEL_IMAGE:-prvtpro/amnezia-panel:1.4.4}"
  export INSTALL_CADDY="${INSTALL_CADDY:-n}"
  export AUTO_INSTALL="${AUTO_INSTALL:-n}"
  export BOOTSTRAP_AWG="${BOOTSTRAP_AWG:-y}"
}

prompt_ssh_password() {
  if [[ -n "${SSH_PASSWORD:-}" ]]; then
    return 0
  fi
  if [[ -n "${SSH_PRIVATE_KEY:-}" ]]; then
    return 0
  fi
  if [[ "${AUTO_INSTALL}" == "y" ]]; then
    err "Укажите SSH_PASSWORD в .env для автоматической установки"
    exit 1
  fi
  printf '%s' "Введите SSH-пароль root для управления сервером: "
  read -rs SSH_PASSWORD
  printf '\n'
  export SSH_PASSWORD
}

print_banner() {
  printf '\n'
  printf '%b╔══════════════════════════════════════════════════╗%b\n' "${BOLD}" "${RESET}"
  printf '%b║  AmneziaWG 2.0 + Amnezia Web Panel (PRVTPRO)     ║%b\n' "${BOLD}" "${RESET}"
  printf '%b╚══════════════════════════════════════════════════╝%b\n' "${BOLD}" "${RESET}"
  printf '\n'
}

print_summary() {
  local pub_ip
  pub_ip="$(curl -4 -s --max-time 5 ifconfig.me 2>/dev/null || echo 'YOUR_SERVER_IP')"

  printf '\n'
  ok "═══════════════════════════════════════════════════"
  ok "  Установка завершена!"
  ok "═══════════════════════════════════════════════════"
  printf '\n'
  info "Веб-панель Amnezia:"
  if [[ "${INSTALL_CADDY}" == "y" ]] && [[ -n "${ADMIN_DOMAIN:-}" ]]; then
    printf '  URL:       https://%s\n' "${ADMIN_DOMAIN}"
  else
    printf '  URL:       http://%s:%s\n' "${pub_ip}" "${APP_PORT}"
  fi
  printf '  Логин:     %s\n' "${ADMIN_USERNAME}"
  printf '  Пароль:    %s (смените после первого входа!)\n' "${ADMIN_PASSWORD}"
  printf '\n'
  info "VPN (AmneziaWG 2.0):"
  printf '  Протокол:  awg2\n'
  printf '  Порт:      UDP %s\n' "${AWG2_PORT}"
  printf '\n'
  info "Управление:"
  printf '  Добавить клиента:  ./scripts/add-client.sh <имя>\n'
  printf '  Статус:            ./scripts/status.sh\n'
  printf '  Логи панели:       docker compose logs -f\n'
  printf '\n'
  warn "Сразу смените пароль admin в разделе Users панели!"
  printf '\n'
}

main() {
  require_root
  check_os
  load_env
  print_banner

  if [[ "${AUTO_INSTALL}" != "y" ]]; then
    warn "Рекомендуется обновить систему перед установкой."
    printf 'Продолжить? [y/N] '
    read -r answer
    case "${answer}" in
      [Yy]|[Yy][Ee][Ss]) ;;
      *) info "Установка отменена."; exit 0 ;;
    esac
  fi

  prompt_ssh_password

  info "[1/4] Подготовка хоста (Docker, SSH)..."
  bash "${SCRIPTS_DIR}/prepare-host.sh"

  info "[2/4] Установка Amnezia Web Panel..."
  bash "${SCRIPTS_DIR}/install-admin.sh"

  if [[ "${BOOTSTRAP_AWG}" == "y" ]]; then
    info "[3/4] Установка AmneziaWG 2.0 через панель..."
    bash "${SCRIPTS_DIR}/bootstrap-awg.sh"
  else
    info "[3/4] AWG2 bootstrap пропущен (BOOTSTRAP_AWG=n)"
    warn "Установите AWG 2.0 вручную: панель → Сервер → Install → AmneziaWG 2.0"
  fi

  if [[ "${INSTALL_CADDY}" == "y" ]]; then
    if [[ -z "${ADMIN_DOMAIN:-}" ]]; then
      err "Укажите ADMIN_DOMAIN в .env"
      exit 1
    fi
    info "[4/4] Настройка Caddy reverse proxy..."
    bash "${SCRIPTS_DIR}/setup-caddy.sh"
  else
    info "[4/4] Caddy пропущен (INSTALL_CADDY=n)"
  fi

  print_summary
}

main "$@"
