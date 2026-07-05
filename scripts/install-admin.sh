#!/usr/bin/env bash
# install-admin.sh — установка PRVTPRO/Amnezia-Web-Panel через Docker
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

export APP_PORT="${APP_PORT:-5000}"
export PANEL_IMAGE="${PANEL_IMAGE:-prvtpro/amnezia-panel:1.4.4}"

if [[ -z "${SECRET_KEY:-}" ]]; then
  SECRET_KEY="$(openssl rand -hex 32)"
  export SECRET_KEY
  if [[ -f "${PROJECT_DIR}/.env" ]] && grep -q '^SECRET_KEY=' "${PROJECT_DIR}/.env"; then
    sed -i "s/^SECRET_KEY=.*/SECRET_KEY=${SECRET_KEY}/" "${PROJECT_DIR}/.env"
  elif [[ -f "${PROJECT_DIR}/.env" ]]; then
    echo "SECRET_KEY=${SECRET_KEY}" >> "${PROJECT_DIR}/.env"
  else
    cp "${PROJECT_DIR}/.env.example" "${PROJECT_DIR}/.env"
    sed -i "s/^SECRET_KEY=.*/SECRET_KEY=${SECRET_KEY}/" "${PROJECT_DIR}/.env"
  fi
  echo "Сгенерирован SECRET_KEY и сохранён в .env"
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Ошибка: Docker не установлен. Запустите prepare-host.sh" >&2
  exit 1
fi

cd "${PROJECT_DIR}"

echo "Запускаем Amnezia Web Panel (${PANEL_IMAGE})..."
docker compose pull
docker compose up -d

wait_for_service() {
  local port="$1"
  python3 -c "
import socket, sys
s = socket.socket()
s.settimeout(1)
try:
    s.connect(('127.0.0.1', ${port}))
    s.close()
    sys.exit(0)
except Exception:
    sys.exit(1)
"
}

echo "Ожидаем готовности панели..."
for i in $(seq 1 60); do
  if wait_for_service "${APP_PORT}"; then
    echo "Панель доступна на порту ${APP_PORT}."
    exit 0
  fi
  sleep 2
done

echo "Предупреждение: панель ещё запускается. Проверьте: docker compose logs -f" >&2
