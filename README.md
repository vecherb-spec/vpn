# AmneziaWG 2.0 VPN Service

Self-hosted VPN на протоколе **AmneziaWG 2.0** с веб-панелью **[Amnezia Web Panel](https://github.com/PRVTPRO/Amnezia-Web-Panel)** для управления серверами и клиентами.

## Возможности

- **AmneziaWG 2.0** — обфусцированный WireGuard с параметрами S3/S4 и H1–H4
- **Amnezia Web Panel** — полноценная админка с UI, ролями, статистикой, Telegram-ботом
- **Совместимость** с официальным клиентом Amnezia
- **Docker** — панель и VPN работают в контейнерах
- **Caddy** — HTTPS для админки (опционально)

## Требования

| Компонент | Минимум |
|-----------|---------|
| ОС | Ubuntu 20.04/22.04/24.04 (x86_64 или ARM64) |
| RAM | 1 GB |
| Диск | 5 GB |
| Сеть | Публичный IPv4 |
| Доступ | root (sudo) |

## Быстрый старт

```bash
git clone <repo-url> vpn && cd vpn
cp .env.example .env
nano .env   # SSH_PASSWORD, ADMIN_PASSWORD

chmod +x install.sh scripts/*.sh
sudo ./install.sh
```

После установки откройте `http://SERVER_IP:5000`, войдите как `admin` / `admin` и **сразу смените пароль** в разделе Users.

## Конфигурация (.env)

| Переменная | По умолчанию | Описание |
|------------|--------------|----------|
| `APP_PORT` | `5000` | Порт веб-панели |
| `PANEL_IMAGE` | `prvtpro/amnezia-panel:1.4.4` | Docker-образ панели |
| `ADMIN_USERNAME` | `admin` | Логин панели |
| `ADMIN_PASSWORD` | `admin` | Пароль (смените!) |
| `SSH_PASSWORD` | — | Пароль root для SSH (обязателен) |
| `AWG2_PORT` | `51820` | UDP-порт AmneziaWG 2.0 |
| `BOOTSTRAP_AWG` | `y` | Автоустановка AWG2 через API |
| `INSTALL_CADDY` | `n` | HTTPS reverse proxy |

## Архитектура

```
┌─────────────────────────────────────────────────────────┐
│                      VPS / Сервер                        │
│                                                          │
│  ┌──────────────────┐      SSH (127.0.0.1:22)            │
│  │ Amnezia Web Panel│ ─────────────────────────┐        │
│  │  :5000 (Docker)  │                          │        │
│  └────────┬─────────┘                          ▼        │
│           │ HTTPS (Caddy)            ┌─────────────────┐│
│           ▼                          │ amnezia-awg2    ││
│      Администратор                   │ AmneziaWG 2.0   ││
│                                      │ UDP :51820      ││
│                                      └────────┬────────┘│
└───────────────────────────────────────────────┼─────────┘
                                                │ UDP
                                           VPN-клиенты
```

Панель управляет VPN через SSH, устанавливая протокол AWG 2.0 в Docker-контейнер `amnezia-awg2` — так же, как официальный клиент Amnezia.

## Управление

```bash
# Статус
./scripts/status.sh

# Добавить VPN-клиента
./scripts/add-client.sh alice

# Удалить клиента
./scripts/add-client.sh --remove alice

# Список клиентов
./scripts/add-client.sh --list

# Логи панели
docker compose logs -f

# Перезапуск панели
docker compose restart
```

## Веб-панель — основные функции

- Установка/удаление протоколов: AWG 2.0, Xray, WireGuard, Telemt, DNS
- Управление клиентами, лимиты трафика, срок действия
- Роли: Admin, Support, User
- Публичные ссылки для скачивания конфигов
- Telegram-бот, Remnawave sync, JSON backup
- Интерфейс на русском, английском, французском, китайском, персидском

Документация панели: [PRVTPRO/Amnezia-Web-Panel](https://github.com/PRVTPRO/Amnezia-Web-Panel)

## Клиентские приложения

| Платформа | Приложение |
|-----------|------------|
| Android | [AmneziaWG](https://play.google.com/store/apps/details?id=org.amnezia.awg) |
| iOS | [AmneziaWG](https://apps.apple.com/app/amneziawg/id6476402488) |
| Windows | [Amnezia VPN](https://amnezia.org/) / WireSock |
| macOS | Amnezia VPN |
| Linux | Amnezia VPN |

## HTTPS для админки (Caddy)

```bash
# В .env:
INSTALL_CADDY=y
ADMIN_DOMAIN=vpn-admin.example.com
CADDY_EMAIL=admin@example.com

sudo ./scripts/setup-caddy.sh
```

## Ручная установка AWG 2.0

Если `BOOTSTRAP_AWG=n`:

1. Откройте панель → **Add Server** → IP `127.0.0.1`, root + пароль
2. Дождитесь проверки сервера
3. **Install Protocol** → **AmneziaWG 2.0 (awg2)**
4. Добавляйте клиентов через UI или `./scripts/add-client.sh`

## Безопасность

- Смените пароль `admin` сразу после установки
- Не открывайте порт 5000 публично без HTTPS
- Используйте Caddy или SSH-туннель: `ssh -L 5000:127.0.0.1:5000 root@SERVER`
- Ограничьте IP через `ADMIN_ALLOWED_IPS`
- Для продакшена настройте `SECRET_KEY` в `.env`

## Устранение неполадок

```bash
# Панель не запускается
docker compose logs amnezia_panel

# AWG2 не установился
docker ps -a | grep awg2
./scripts/status.sh

# Переустановка AWG2 через панель
# UI: Server → Protocols → AmneziaWG 2.0 → Reinstall
```

## Основа проекта

- Панель: [PRVTPRO/Amnezia-Web-Panel](https://github.com/PRVTPRO/Amnezia-Web-Panel) (GPL-3.0)
- Docker-образ: [prvtpro/amnezia-panel](https://hub.docker.com/r/prvtpro/amnezia-panel)
- Протокол: [AmneziaWG 2.0](https://docs.amnezia.org/documentation/amnezia-wg/)

## Лицензия

MIT (скрипты развёртывания). Amnezia Web Panel — GPL-3.0.
