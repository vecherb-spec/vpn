# AmneziaWG 2.0 VPN Service

Self-hosted VPN-сервис на протоколе **AmneziaWG 2.0** с веб-админкой для управления клиентами.

## Возможности

- **AmneziaWG 2.0** — обфусцированный WireGuard с параметрами S3/S4 и H1–H4 для обхода DPI
- **Веб-админка** — управление клиентами, статистика, включение/отключение доступа
- **Caddy reverse proxy** — HTTPS-доступ к админке через Let's Encrypt (опционально)
- **Автоматизация** — скрипты для установки, добавления клиентов и мониторинга

## Требования

| Компонент | Минимум |
|-----------|---------|
| ОС | Ubuntu ≥ 22.04 или Debian ≥ 11 |
| RAM | 512 MB (рекомендуется 1 GB) |
| Диск | 2 GB свободного места |
| Сеть | Публичный IPv4, открытый UDP-порт |
| Доступ | root (sudo) |

## Быстрый старт

### 1. Подготовка сервера

```bash
# Обновите систему
sudo apt update && sudo apt upgrade -y
sudo reboot
```

### 2. Клонирование и настройка

```bash
git clone <repo-url> vpn
cd vpn

# Создайте конфигурацию
cp .env.example .env
nano .env   # укажите ADMIN_PASSWORD и другие параметры
```

### 3. Установка

```bash
chmod +x install.sh scripts/*.sh
sudo ./install.sh
```

Для полностью автоматической установки:

```bash
sudo AUTO_INSTALL=y ./install.sh
```

### 4. Добавление клиента

```bash
sudo ./scripts/add-client.sh alice
```

Конфиг сохранится в `~/awg0-client-alice.conf`. Импортируйте его в клиентское приложение.

## Конфигурация (.env)

| Переменная | По умолчанию | Описание |
|------------|--------------|----------|
| `SERVER_PORT` | `51820` | UDP-порт VPN |
| `CLIENT_DNS_1` | `1.1.1.1` | Первичный DNS |
| `ADMIN_USERNAME` | `admin` | Логин админки |
| `ADMIN_PASSWORD` | — | Пароль админки (обязателен) |
| `AWG_WEB_HOST` | `127.0.0.1` | Адрес прослушивания панели |
| `INSTALL_CADDY` | `n` | Установить HTTPS reverse proxy |
| `ADMIN_DOMAIN` | — | Домен для админки (если Caddy) |
| `ADMIN_ALLOWED_IPS` | — | Ограничение IP для админки |

Полный список — в файле `.env.example`.

## Веб-админка

После установки панель доступна по адресу:

- **Локально:** `http://127.0.0.1:8080`
- **Через SSH-туннель:** `ssh -L 8080:127.0.0.1:8080 root@SERVER_IP`
- **Через Caddy:** `https://vpn-admin.example.com` (если `INSTALL_CADDY=y`)

### Функции админки

- Просмотр списка клиентов и их статуса
- Добавление и удаление клиентов
- Включение/отключение доступа
- Статистика трафика (передано/получено)
- Скачивание конфигов клиентов

## Клиентские приложения

| Платформа | Приложение |
|-----------|------------|
| Android | [AmneziaWG](https://play.google.com/store/apps/details?id=org.amnezia.awg) / WG Tunnel |
| iOS | [AmneziaWG](https://apps.apple.com/app/amneziawg/id6476402488) |
| Windows | [WireSock Secure Connect](https://www.wiresock.net/) |
| macOS | AmneziaWG |
| Linux | `awg-quick up client.conf` |

## Управление

```bash
# Статус всех сервисов
./scripts/status.sh

# Добавить клиента
sudo ./scripts/add-client.sh <имя>

# Удалить клиента
sudo ./scripts/add-client.sh --remove <имя>

# Список клиентов
sudo ./scripts/add-client.sh --list

# Статус веб-админки
./vendor/amneziawg-install/amneziawg-web.sh status

# Обновить админку
sudo ./vendor/amneziawg-install/amneziawg-web.sh upgrade
```

## Архитектура

```
┌─────────────────────────────────────────────────────┐
│                    VPS / Сервер                      │
│                                                      │
│  ┌──────────────┐    ┌──────────────────────────┐   │
│  │   Caddy      │───▶│  amneziawg-web (админка) │   │
│  │  :443 HTTPS  │    │  127.0.0.1:8080          │   │
│  └──────────────┘    └──────────┬───────────────┘   │
│                                 │ управление         │
│  ┌──────────────────────────────▼───────────────┐   │
│  │           AmneziaWG 2.0 (awg0)               │   │
│  │           UDP :51820                         │   │
│  └──────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
         ▲                              ▲
         │ UDP                          │ HTTPS
    VPN-клиенты                    Администратор
```

## Безопасность

- Админка по умолчанию слушает только `127.0.0.1` — не открывайте порт 8080 наружу
- Используйте Caddy с HTTPS или SSH-туннель для удалённого доступа
- Ограничьте IP через `ADMIN_ALLOWED_IPS` в `.env`
- Пароли хранятся как Argon2id-хеши
- Регулярно обновляйте систему и компоненты

## AmneziaWG 2.0 — параметры обфускации

Протокол автоматически генерирует параметры для обхода DPI:

| Параметр | Назначение |
|----------|------------|
| Jc, Jmin, Jmax | Junk-пакеты |
| S1–S4 | Padding префиксы |
| H1–H4 | Диапазоны заголовков |

Все значения генерируются автоматически при установке.

## Устранение неполадок

### VPN не подключается

```bash
# Проверьте статус
./scripts/status.sh

# Проверьте firewall
sudo ufw status
sudo ufw allow 51820/udp

# Логи
sudo journalctl -u awg-quick@awg0 -f
```

### Админка недоступна

```bash
sudo systemctl status amneziawg-web
sudo journalctl -u amneziawg-web -f
curl http://127.0.0.1:8080/api/health
```

### Переустановка

```bash
sudo ./vendor/amneziawg-install/amneziawg-web.sh uninstall --force
sudo ./vendor/amneziawg-install/amneziawg-install.sh  # выберите uninstall
sudo ./install.sh
```

## Основа проекта

Установщики основаны на [wiresock/amneziawg-install](https://github.com/wiresock/amneziawg-install) — community-проект для AmneziaWG 2.0.

## Лицензия

MIT
