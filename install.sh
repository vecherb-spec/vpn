#!/usr/bin/env bash
# install.sh — развёртывание VPN-сервиса AmneziaWG 2.0 с веб-админкой
#
# Использование:
#   sudo ./install.sh              # интерактивная установка
#   sudo AUTO_INSTALL=y ./install.sh  # автоматическая установка
#
# Требования: Ubuntu ≥ 22.04 или Debian ≥ 11, root-доступ

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="${SCRIPT_DIR}/scripts"
ENV_FILE="${SCRIPT_DIR}/.env"

# ── Цвета ────────────────────────────────────────────────────────────────────

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

# ── Проверки ─────────────────────────────────────────────────────────────────

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    err "Запустите скрипт от root: sudo $0"
    exit 1
  fi
}

check_os() {
  if [[ ! -f /etc/os-release ]]; then
    err "Неподдерживаемая ОС. Требуется Ubuntu ≥ 22.04 или Debian ≥ 11."
    exit 1
  fi

  # shellcheck source=/dev/null
  source /etc/os-release
  case "${ID:-}" in
    ubuntu)
      local ver="${VERSION_ID%%.*}"
      if [[ "${ver}" -lt 22 ]]; then
        err "Требуется Ubuntu ≥ 22.04 (обнаружено: ${VERSION_ID})"
        exit 1
      fi
      ;;
    debian)
      local ver="${VERSION_ID%%.*}"
      if [[ "${ver}" -lt 11 ]]; then
        err "Требуется Debian ≥ 11 (обнаружено: ${VERSION_ID})"
        exit 1
      fi
      ;;
    *)
      warn "ОС ${ID} не проверена официально. Продолжаем на свой риск."
      ;;
  esac
}

load_env() {
  if [[ -f "${ENV_FILE}" ]]; then
    info "Загружаем конфигурацию из ${ENV_FILE}"
    set -a
    # shellcheck source=/dev/null
    source "${ENV_FILE}"
    set +a
  elif [[ -f "${SCRIPT_DIR}/.env.example" ]]; then
    warn "Файл .env не найден. Используем значения по умолчанию."
    warn "Скопируйте .env.example в .env для настройки: cp .env.example .env"
  fi

  # Значения по умолчанию
  export SERVER_PORT="${SERVER_PORT:-51820}"
  export SERVER_AWG_IPV4="${SERVER_AWG_IPV4:-10.66.66.1}"
  export SERVER_AWG_IPV6="${SERVER_AWG_IPV6:-fd42:42:42::1}"
  export ENABLE_IPV6="${ENABLE_IPV6:-y}"
  export CLIENT_DNS_1="${CLIENT_DNS_1:-1.1.1.1}"
  export CLIENT_DNS_2="${CLIENT_DNS_2:-1.0.0.1}"
  export ALLOWED_IPS="${ALLOWED_IPS:-0.0.0.0/0,::/0}"
  export ADMIN_USERNAME="${ADMIN_USERNAME:-admin}"
  export AWG_WEB_HOST="${AWG_WEB_HOST:-127.0.0.1}"
  export AWG_WEB_PORT="${AWG_WEB_PORT:-8080}"
  export AWG_POLL_INTERVAL="${AWG_POLL_INTERVAL:-30}"
  export AUTH_SESSION_TTL_SECS="${AUTH_SESSION_TTL_SECS:-86400}"
  export INSTALL_CADDY="${INSTALL_CADDY:-n}"
  export AUTO_INSTALL="${AUTO_INSTALL:-n}"
  export AMNEZIAWG_REPO_REF="${AMNEZIAWG_REPO_REF:-main}"
}

prompt_password() {
  if [[ -n "${ADMIN_PASSWORD:-}" ]]; then
    return 0
  fi

  if [[ "${AUTO_INSTALL}" == "y" ]]; then
    err "Укажите ADMIN_PASSWORD в .env для автоматической установки"
    exit 1
  fi

  printf '%s' "Введите пароль администратора: "
  read -rs ADMIN_PASSWORD
  printf '\n'
  export ADMIN_PASSWORD
}

print_banner() {
  printf '\n'
  printf '%b╔══════════════════════════════════════════════════╗%b\n' "${BOLD}" "${RESET}"
  printf '%b║     AmneziaWG 2.0 VPN + Веб-админка              ║%b\n' "${BOLD}" "${RESET}"
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
  info "VPN сервер:"
  printf '  Протокол:  AmneziaWG 2.0\n'
  printf '  Порт:      UDP %s\n' "${SERVER_PORT}"
  printf '  IP:        %s\n' "${pub_ip}"
  printf '\n'
  info "Веб-админка:"
  if [[ "${INSTALL_CADDY}" == "y" ]] && [[ -n "${ADMIN_DOMAIN:-}" ]]; then
    printf '  URL:       https://%s\n' "${ADMIN_DOMAIN}"
  else
    printf '  URL:       http://%s:%s (только локально)\n' "${AWG_WEB_HOST}" "${AWG_WEB_PORT}"
    warn "  Для внешнего доступа: ssh -L 8080:127.0.0.1:8080 root@${pub_ip}"
  fi
  printf '  Логин:     %s\n' "${ADMIN_USERNAME}"
  printf '\n'
  info "Управление:"
  printf '  Добавить клиента:  sudo ./scripts/add-client.sh <имя>\n'
  printf '  Статус:            ./scripts/status.sh\n'
  printf '  Список клиентов:   sudo ./scripts/add-client.sh --list\n'
  printf '\n'
  info "Клиентские приложения:"
  printf '  Android:   AmneziaWG / WG Tunnel\n'
  printf '  iOS:       AmneziaWG\n'
  printf '  Windows:   WireSock Secure Connect\n'
  printf '  macOS:     AmneziaWG\n'
  printf '\n'
}

# ── Основной процесс ─────────────────────────────────────────────────────────

main() {
  require_root
  check_os
  load_env
  print_banner

  if [[ "${AUTO_INSTALL}" != "y" ]]; then
    warn "Перед установкой рекомендуется обновить систему и перезагрузить сервер."
    printf 'Продолжить установку? [y/N] '
    read -r answer
    case "${answer}" in
      [Yy]|[Yy][Ee][Ss]) ;;
      *) info "Установка отменена."; exit 0 ;;
    esac
  fi

  prompt_password

  info "[1/3] Установка VPN-сервера AmneziaWG 2.0..."
  bash "${SCRIPTS_DIR}/install-vpn.sh"

  info "[2/3] Установка веб-админки..."
  bash "${SCRIPTS_DIR}/install-admin.sh"

  if [[ "${INSTALL_CADDY}" == "y" ]]; then
    if [[ -z "${ADMIN_DOMAIN:-}" ]]; then
      err "Укажите ADMIN_DOMAIN в .env для установки Caddy"
      exit 1
    fi
    info "[3/3] Настройка Caddy reverse proxy..."
    bash "${SCRIPTS_DIR}/setup-caddy.sh"
  else
    info "[3/3] Caddy пропущен (INSTALL_CADDY=n)"
  fi

  print_summary
}

main "$@"
