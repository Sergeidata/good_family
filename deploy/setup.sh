#!/usr/bin/env bash
# =============================================================================
#  Good Family — развёртывание сервера с нуля (Ubuntu 22.04/24.04/26.04 LTS)
#
#  Идемпотентный: повторный запуск безопасен (перегенерирует пароли только
#  если /root/credentials.txt отсутствует).
#
#  Использование:
#     scp setup.sh root@89.108.66.36:/root/
#     ssh root@89.108.66.36 "bash /root/setup.sh"
#
#  Итоговый отчёт: /root/credentials.txt  и  /var/log/goodfamily_setup.log
# =============================================================================

set -Eeuo pipefail

# ---------------------------------------------------------------------------
# Константы
# ---------------------------------------------------------------------------
REPO_URL="https://github.com/Sergeidata/good_family.git"
APP_DIR="/opt/goodfamily"
APP_USER="root"
VENV_DIR="${APP_DIR}/venv"
DB_NAME="familyfocus"
DB_USER="familyfocus_user"
SERVICE_NAME="goodfamily"
GUNICORN_PORT="8000"
GUNICORN_WORKERS="2"
CRED_FILE="/root/credentials.txt"
LOG_FILE="/var/log/goodfamily_setup.log"
PUBLIC_IP="$(curl -s --max-time 5 https://api.ipify.org || echo '89.108.66.36')"

# SMTP передаётся через переменные окружения, НЕ хардкодится в скрипте:
#   SMTP_USER=... SMTP_PASSWORD=... bash setup.sh
SMTP_USER_VAL="${SMTP_USER:-}"
SMTP_PASSWORD_VAL="${SMTP_PASSWORD:-}"
SMTP_HOST_VAL="${SMTP_HOST:-smtp.yandex.com}"
SMTP_PORT_VAL="${SMTP_PORT:-465}"

# ---------------------------------------------------------------------------
# Логирование
# ---------------------------------------------------------------------------
if [[ -t 1 ]]; then
  C_RESET='\033[0m'; C_BLUE='\033[1;34m'; C_GREEN='\033[1;32m'
  C_YELLOW='\033[1;33m'; C_RED='\033[1;31m'
else
  C_RESET=''; C_BLUE=''; C_GREEN=''; C_YELLOW=''; C_RED=''
fi

mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

_step_no=0
step() {
  _step_no=$((_step_no + 1))
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] ▶ ШАГ ${_step_no}: $*"
  echo -e "${C_BLUE}${msg}${C_RESET}"
  echo "$msg" >> "$LOG_FILE"
}
ok()   { local m="[$(date '+%F %T')]   ✓ $*"; echo -e "${C_GREEN}${m}${C_RESET}";   echo "$m" >> "$LOG_FILE"; }
warn() { local m="[$(date '+%F %T')]   ! $*"; echo -e "${C_YELLOW}${m}${C_RESET}"; echo "$m" >> "$LOG_FILE"; }
die()  { local m="[$(date '+%F %T')]   ✗ $*"; echo -e "${C_RED}${m}${C_RESET}";    echo "$m" >> "$LOG_FILE"; exit 1; }

# Ловушка: печатаем строку и код ошибки
trap 'die "Скрипт прерван на шаге ${_step_no} (строка $LINENO, код $?)"' ERR

# Выполнить команду, показав её в логе
run() {
  echo "+ $*" >> "$LOG_FILE"
  "$@" >> "$LOG_FILE" 2>&1
}

# ---------------------------------------------------------------------------
# ШАГ 0. Проверки окружения
# ---------------------------------------------------------------------------
step "Проверка окружения"
[[ $EUID -eq 0 ]] || die "Скрипт нужно запускать от root"
[[ -f /etc/os-release ]] || die "Не найден /etc/os-release"
# shellcheck disable=SC1091
. /etc/os-release
ok "ОС: ${PRETTY_NAME}"
command -v curl >/dev/null || { run apt-get update; run apt-get install -y curl; }
ok "curl доступен"

# ---------------------------------------------------------------------------
# ШАГ 1. Обновление системы
# ---------------------------------------------------------------------------
step "Обновление пакетов (apt update && upgrade)"
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a          # не спрашивать про рестарт сервисов
run apt-get update -y
run apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
ok "Система обновлена"

# ---------------------------------------------------------------------------
# ШАГ 2. Установка пакетов
# ---------------------------------------------------------------------------
step "Установка пакетов"
run apt-get install -y \
  python3 python3-pip python3-venv python3-dev \
  postgresql postgresql-contrib libpq-dev \
  nginx git ufw openssl build-essential
ok "Пакеты установлены"

PY_VER="$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')"
ok "Python ${PY_VER}"

# ---------------------------------------------------------------------------
# ШАГ 3. Пароли
# ---------------------------------------------------------------------------
step "Подготовка паролей"
if [[ -f "$CRED_FILE" ]] && grep -q '^DB_PASSWORD=' "$CRED_FILE" 2>/dev/null; then
  # shellcheck disable=SC1090
  . "$CRED_FILE"
  ok "Пароли уже существуют — используем из $CRED_FILE"
else
  DB_PASSWORD="$(openssl rand -base64 24 | tr -d '/+=' | cut -c1-28)"
  EXPORT_STATS_SECRET="$(openssl rand -base64 24 | tr -d '/+=' | cut -c1-28)"
  ok "Сгенерированы новые пароли"
fi

# ---------------------------------------------------------------------------
# ШАГ 4. PostgreSQL
# ---------------------------------------------------------------------------
step "Настройка PostgreSQL (только localhost)"

PG_SERVICE="postgresql"
systemctl enable --now "$PG_SERVICE" >> "$LOG_FILE" 2>&1
ok "Служба PostgreSQL запущена"

# listen_addresses = '127.0.0.1' — найти конфиг текущего кластера
PG_CONF_DIR="$(ls -d /etc/postgresql/*/main 2>/dev/null | sort -V | tail -1)"
[[ -n "$PG_CONF_DIR" ]] || die "Не найден каталог конфигурации PostgreSQL"
PG_CONF="${PG_CONF_DIR}/postgresql.conf"
ok "Конфиг PostgreSQL: ${PG_CONF}"

if grep -qE "^[#[:space:]]*listen_addresses" "$PG_CONF"; then
  sed -i -E "s|^[#[:space:]]*listen_addresses.*|listen_addresses = '127.0.0.1'|" "$PG_CONF"
else
  echo "listen_addresses = '127.0.0.1'" >> "$PG_CONF"
fi
ok "listen_addresses = 127.0.0.1"

systemctl restart "$PG_SERVICE" >> "$LOG_FILE" 2>&1
sleep 2

# Пользователь и база (идемпотентно)
if sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'" | grep -q 1; then
  sudo -u postgres psql -c "ALTER USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';" >> "$LOG_FILE" 2>&1
  ok "Пользователь ${DB_USER} уже есть — пароль синхронизирован"
else
  sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';" >> "$LOG_FILE" 2>&1
  ok "Пользователь ${DB_USER} создан"
fi

if sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1; then
  ok "База ${DB_NAME} уже существует"
else
  sudo -u postgres createdb -O "$DB_USER" "$DB_NAME" >> "$LOG_FILE" 2>&1
  ok "База ${DB_NAME} создана"
fi

sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};" >> "$LOG_FILE" 2>&1 || true
sudo -u postgres psql -d "$DB_NAME" -c "GRANT ALL ON SCHEMA public TO ${DB_USER};" >> "$LOG_FILE" 2>&1 || true

# Проверка подключения
PGPASSWORD="$DB_PASSWORD" psql -h 127.0.0.1 -U "$DB_USER" -d "$DB_NAME" -tAc "SELECT 1;" >/dev/null 2>&1 \
  && ok "Подключение к БД от ${DB_USER} работает" \
  || die "Не удалось подключиться к БД"

# ---------------------------------------------------------------------------
# ШАГ 5. Клонирование репозитория
# ---------------------------------------------------------------------------
step "Репозиторий в ${APP_DIR}"

if [[ -d "${APP_DIR}/.git" ]]; then
  run git -C "$APP_DIR" fetch --all
  run git -C "$APP_DIR" reset --hard origin/main
  ok "Репозиторий обновлён (git reset --hard origin/main)"
else
  mkdir -p "$(dirname "$APP_DIR")"
  run git clone "$REPO_URL" "$APP_DIR"
  ok "Репозиторий склонирован"
fi

[[ -f "${APP_DIR}/server/server.py" ]] || die "Не найден ${APP_DIR}/server/server.py"
ok "server.py на месте"

mkdir -p "${APP_DIR}/uploads/avatars"
chmod -R 755 "${APP_DIR}/uploads"
ok "Каталог загрузок: ${APP_DIR}/uploads/avatars"

# ---------------------------------------------------------------------------
# ШАГ 6. Виртуальное окружение и зависимости
# ---------------------------------------------------------------------------
step "Python venv и зависимости"

if [[ ! -x "${VENV_DIR}/bin/python" ]]; then
  run python3 -m venv "$VENV_DIR"
  ok "venv создан: ${VENV_DIR}"
else
  ok "venv уже существует"
fi

run "${VENV_DIR}/bin/pip" install --upgrade pip setuptools wheel
run "${VENV_DIR}/bin/pip" install -r "${APP_DIR}/server/requirements.txt"

# Pillow нужен для обработки загружаемых аватаров (from PIL import Image),
# но отсутствует в requirements.txt — ставим отдельно.
run "${VENV_DIR}/bin/pip" install Pillow

ok "Зависимости установлены"
"${VENV_DIR}/bin/python" -c "import flask, psycopg2, gunicorn, PIL; print('imports ok')" >> "$LOG_FILE" 2>&1 \
  && ok "Проверка импортов: flask, psycopg2, gunicorn, PIL" \
  || die "Не импортируются зависимости"

# ---------------------------------------------------------------------------
# ШАГ 7. .env
# ---------------------------------------------------------------------------
step "Файл окружения .env"

DATABASE_URL="postgresql://${DB_USER}:${DB_PASSWORD}@127.0.0.1:5432/${DB_NAME}"

cat > "${APP_DIR}/.env" <<EOF
# Сгенерировано setup.sh $(date '+%Y-%m-%d %H:%M:%S')
DATABASE_URL=${DATABASE_URL}
EXPORT_STATS_SECRET=${EXPORT_STATS_SECRET}
SMTP_USER=${SMTP_USER_VAL}
SMTP_PASSWORD=${SMTP_PASSWORD_VAL}
SMTP_HOST=${SMTP_HOST_VAL}
SMTP_PORT=${SMTP_PORT_VAL}
EOF
chmod 600 "${APP_DIR}/.env"
ok "Создан ${APP_DIR}/.env (chmod 600)"

if [[ -n "$SMTP_USER_VAL" && -n "$SMTP_PASSWORD_VAL" ]]; then
  ok "SMTP настроен для ${SMTP_USER_VAL}"
else
  warn "SMTP не задан: регистрация по почте вернёт 'email send failed'."
  warn "Запустите: SMTP_USER=... SMTP_PASSWORD=... bash setup.sh"
fi

# ---------------------------------------------------------------------------
# ШАГ 8. systemd-сервис
# ---------------------------------------------------------------------------
step "systemd-сервис ${SERVICE_NAME}"

cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<EOF
[Unit]
Description=Good Family API (gunicorn)
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
User=${APP_USER}
Group=${APP_USER}
WorkingDirectory=${APP_DIR}/server
EnvironmentFile=${APP_DIR}/.env
ExecStart=${VENV_DIR}/bin/gunicorn \
    --workers ${GUNICORN_WORKERS} \
    --bind 127.0.0.1:${GUNICORN_PORT} \
    --timeout 120 \
    --access-logfile - \
    --error-logfile - \
    server:app
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload >> "$LOG_FILE" 2>&1
systemctl enable "$SERVICE_NAME" >> "$LOG_FILE" 2>&1
systemctl restart "$SERVICE_NAME" >> "$LOG_FILE" 2>&1
ok "Сервис ${SERVICE_NAME} установлен и запущен"

# ---------------------------------------------------------------------------
# ШАГ 9. Nginx
# ---------------------------------------------------------------------------
step "Nginx reverse proxy (80 → 127.0.0.1:${GUNICORN_PORT})"

cat > "/etc/nginx/sites-available/${SERVICE_NAME}" <<'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    # Загружаемые аватары (до 5 МБ)
    client_max_body_size 10M;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_connect_timeout 15s;
        proxy_send_timeout 120s;
        proxy_read_timeout 120s;
    }

    location /uploads/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        expires 7d;
        add_header Cache-Control "public";
    }
}
EOF

rm -f /etc/nginx/sites-enabled/default
ln -sfn "/etc/nginx/sites-available/${SERVICE_NAME}" "/etc/nginx/sites-enabled/${SERVICE_NAME}"

run nginx -t
systemctl enable nginx >> "$LOG_FILE" 2>&1
systemctl restart nginx >> "$LOG_FILE" 2>&1
ok "Nginx настроен и перезапущен"

# ---------------------------------------------------------------------------
# ШАГ 10. Firewall
# ---------------------------------------------------------------------------
step "ufw: разрешаем 22, 80, 443"

run ufw allow 22/tcp
run ufw allow 80/tcp
run ufw allow 443/tcp
ufw --force enable >> "$LOG_FILE" 2>&1
ufw reload >> "$LOG_FILE" 2>&1
ok "ufw включён: 22/tcp, 80/tcp, 443/tcp"

# ---------------------------------------------------------------------------
# ШАГ 11. Проверка работоспособности
# ---------------------------------------------------------------------------
step "Проверка сервисов"

sleep 3

systemctl is-active --quiet "$SERVICE_NAME" \
  && ok "goodfamily: active" \
  || { journalctl -u "$SERVICE_NAME" -n 40 --no-pager >> "$LOG_FILE" 2>&1; die "Сервис goodfamily не запустился (см. journalctl -u goodfamily -n 50)"; }

systemctl is-active --quiet nginx && ok "nginx: active" || die "nginx не запущен"

LOCAL_CODE="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8000/ || true)"
ok "backend 127.0.0.1:${GUNICORN_PORT} → HTTP ${LOCAL_CODE}"

PUBLIC_CODE="$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1/" || true)"
ok "nginx :80 → HTTP ${PUBLIC_CODE}"

TEST_RESP="$(curl -s "http://127.0.0.1/family_info?family_id=test" | head -c 300 || true)"
ok "curl /family_info?family_id=test → ${TEST_RESP}"

# ---------------------------------------------------------------------------
# ШАГ 12. Сохранение доступов и финальный отчёт
# ---------------------------------------------------------------------------
step "Сохранение доступов в ${CRED_FILE}"

cat > "$CRED_FILE" <<EOF
================================================================
 GOOD FAMILY — доступы сервера
 Создано: $(date '+%Y-%m-%d %H:%M:%S')
================================================================

СЕРВЕР
  IP:        ${PUBLIC_IP}
  API:       http://${PUBLIC_IP}
  SSH:       ssh root@${PUBLIC_IP}

БАЗА ДАННЫХ (PostgreSQL, только 127.0.0.1)
  DB:        ${DB_NAME}
  DB user:   ${DB_USER}
  DB passwd: ${DB_PASSWORD}

  DATABASE_URL=${DATABASE_URL}

СЕКРЕТ ЭКСПОРТА СТАТИСТИКИ
  EXPORT_STATS_SECRET=${EXPORT_STATS_SECRET}

SMTP (регистрация по почте)
  Хост:    ${SMTP_HOST_VAL}:${SMTP_PORT_VAL}
  Логин:   ${SMTP_USER_VAL:-НЕ ЗАДАН}
  Пароль:  ${SMTP_PASSWORD_VAL:-НЕ ЗАДАН}

ПРИЛОЖЕНИЕ
  Каталог:   ${APP_DIR}
  venv:      ${VENV_DIR}
  Сервис:    ${SERVICE_NAME}
  Порт:      127.0.0.1:${GUNICORN_PORT} (за nginx :80)

ПОЛЕЗНЫЕ КОМАНДЫ
  Логи:        journalctl -u ${SERVICE_NAME} -f
  Статус:      systemctl status ${SERVICE_NAME}
  Рестарт:     systemctl restart ${SERVICE_NAME}
  Обновление:  cd ${APP_DIR} && git pull && systemctl restart ${SERVICE_NAME}
  Nginx-логи:  tail -f /var/log/nginx/access.log /var/log/nginx/error.log
  Бэкап БД:    sudo -u postgres pg_dump ${DB_NAME} > /root/backup_\$(date +%F).sql

ВАЖНО: файл содержит пароли — chmod 600, не коммитить в git.
================================================================
EOF
chmod 600 "$CRED_FILE"
ok "Доступы сохранены: ${CRED_FILE}"

echo ""
echo -e "${C_GREEN}================================================================${C_RESET}"
echo -e "${C_GREEN} РАЗВЁРТЫВАНИЕ ЗАВЕРШЕНО${C_RESET}"
echo -e "${C_GREEN}================================================================${C_RESET}"
echo ""
echo "  IP сервера:    ${PUBLIC_IP}"
echo "  API:           http://${PUBLIC_IP}"
echo "  Проверка:      curl http://${PUBLIC_IP}/family_info?family_id=test"
echo ""
echo "  База:          ${DB_NAME} (пользователь ${DB_USER})"
echo "  Пароль БД:     ${DB_PASSWORD}"
echo "  Секрет статы:  ${EXPORT_STATS_SECRET}"
echo ""
echo "  Все доступы:   ${CRED_FILE}"
echo "  Лог установки: ${LOG_FILE}"
echo ""
echo "  Логи сервиса:  journalctl -u ${SERVICE_NAME} -f"
echo ""
echo -e "${C_GREEN}================================================================${C_RESET}"
