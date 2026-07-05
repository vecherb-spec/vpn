#!/usr/bin/env bash
# install-vpn.sh — установка AmneziaWG 2.0 VPN-сервера
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
INSTALL_DIR="${PROJECT_DIR}/vendor/amneziawg-install"
INSTALL_SCRIPT="${INSTALL_DIR}/amneziawg-install.sh"

REPO_URL="${AMNEZIAWG_REPO_URL:-https://github.com/wiresock/amneziawg-install.git}"
REPO_REF="${AMNEZIAWG_REPO_REF:-main}"

clone_or_update_repo() {
  if [[ -d "${INSTALL_DIR}/.git" ]]; then
    echo "Обновляем amneziawg-install..."
    git -C "${INSTALL_DIR}" fetch --depth 1 origin "${REPO_REF}" 2>/dev/null || true
    git -C "${INSTALL_DIR}" checkout "${REPO_REF}" 2>/dev/null || true
    git -C "${INSTALL_DIR}" pull --depth 1 origin "${REPO_REF}" 2>/dev/null || true
  else
    echo "Клонируем amneziawg-install..."
    mkdir -p "$(dirname "${INSTALL_DIR}")"
    git clone --depth 1 --branch "${REPO_REF}" "${REPO_URL}" "${INSTALL_DIR}"
  fi
}

install_dependencies() {
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update -qq
    apt-get install -y -qq git curl qrencode python3 python3-pip
    pip3 install -q argon2-cffi 2>/dev/null || pip3 install -q argon2 2>/dev/null || true
  fi
}

run_installer() {
  chmod +x "${INSTALL_SCRIPT}"

  local -a env_vars=(
    "AUTO_INSTALL=${AUTO_INSTALL:-y}"
    "SERVER_PORT=${SERVER_PORT:-51820}"
    "SERVER_AWG_IPV4=${SERVER_AWG_IPV4:-10.66.66.1}"
    "SERVER_AWG_IPV6=${SERVER_AWG_IPV6:-fd42:42:42::1}"
    "ENABLE_IPV6=${ENABLE_IPV6:-y}"
    "CLIENT_DNS_1=${CLIENT_DNS_1:-1.1.1.1}"
    "CLIENT_DNS_2=${CLIENT_DNS_2:-1.0.0.1}"
    "ALLOWED_IPS=${ALLOWED_IPS:-0.0.0.0/0,::/0}"
  )

  if [[ -n "${SERVER_PUB_IP:-}" ]]; then
    env_vars+=("SERVER_PUB_IP=${SERVER_PUB_IP}")
  fi

  echo "Запускаем amneziawg-install.sh..."
  env "${env_vars[@]}" bash "${INSTALL_SCRIPT}"
}

install_dependencies
clone_or_update_repo
run_installer

echo "VPN-сервер AmneziaWG 2.0 установлен."
