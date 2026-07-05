#!/usr/bin/env bash
# prepare-host.sh — подготовка сервера для Amnezia-Web-Panel и AmneziaWG 2.0
set -euo pipefail

echo "Подготовка хоста..."

install_packages() {
  if ! command -v apt-get >/dev/null 2>&1; then
    echo "Ошибка: поддерживается только Debian/Ubuntu" >&2
    exit 1
  fi

  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq \
    ca-certificates \
    curl \
    jq \
    openssh-server \
    iptables \
    iproute2
}

install_docker() {
  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    echo "Docker уже установлен."
    return 0
  fi

  echo "Устанавливаем Docker..."
  apt-get install -y -qq docker.io docker-compose-v2
  systemctl enable --now docker
  sleep 3
}

configure_network() {
  sysctl -w net.ipv4.ip_forward=1
  if ! grep -q '^net.ipv4.ip_forward=1' /etc/sysctl.conf 2>/dev/null; then
    echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
  fi
}

configure_ssh() {
  systemctl enable --now ssh 2>/dev/null || systemctl enable --now sshd 2>/dev/null || true

  if [[ -n "${SSH_PASSWORD:-}" ]] && [[ "${SSH_USER:-root}" == "root" ]]; then
    echo "root:${SSH_PASSWORD}" | chpasswd
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true
  fi
}

install_packages
install_docker
configure_network
configure_ssh

echo "Хост подготовлен."
