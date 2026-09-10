#!/bin/bash
set -e

echo "🚀 X-Net + nginx on Railway..."

XNET_PANEL_PORT=2053
XNET_SUB_PORT=2096
XNET_INBOUND_PORT=8080
# Railway این رو inject میکنه — قبل از هر چیز ذخیره کن
NGINX_PORT="${PORT:-3000}"
export NGINX_PORT XNET_PANEL_PORT XNET_SUB_PORT XNET_INBOUND_PORT

ENV_FILE="/opt/xnet/data/.env"
mkdir -p /opt/xnet/data

if [ ! -f "$ENV_FILE" ]; then
    echo "📝 First run — generating .env..."
    JWT="$(cat /proc/sys/kernel/random/uuid | tr -d '-')$(cat /proc/sys/kernel/random/uuid | tr -d '-')"
    BASE="$(cat /proc/sys/kernel/random/uuid | tr -d '-' | cut -c1-16)"
    cat > "$ENV_FILE" <<EOF
PORT=${XNET_PANEL_PORT}
DATABASE_PATH=/opt/xnet/data/xnet.db
STATIC_DIR=/app/dist
JWT_SECRET=${JWT}
WEB_BASE_PATH=${BASE}
ADMIN_USERNAME=admin
ADMIN_PASSWORD=Admin@Railway1
SINGBOX_CONFIG_PATH=/etc/sing-box/config.json
SINGBOX_BINARY_PATH=/usr/local/bin/sing-box
NODE_ROLE=panel
AGENT_ALLOWED_CIDRS=
NODE_CLIENT_SCHEME=http
NODE_ID=
NODE_API_KEY=
NODE_SECRET_KEY=
EOF
    chmod 600 "$ENV_FILE"
    echo ""
    echo "╔═══════════════════════════════════════════════╗"
    echo "║  Panel URL path : /${BASE}/           ║"
    echo "║  Username       : admin                       ║"
    echo "║  Password       : Admin@Railway1              ║"
    echo "╚═══════════════════════════════════════════════╝"
    echo ""
else
    echo "♻️  Reusing existing .env"
    BASE="$(grep '^WEB_BASE_PATH=' "$ENV_FILE" | cut -d= -f2-)"
    echo "   Panel path: /${BASE}/"
fi

export WEB_BASE_PATH="$BASE"

# nginx config — از NGINX_PORT که قبلاً ذخیره شد استفاده میکنه
envsubst '${NGINX_PORT} ${XNET_PANEL_PORT} ${XNET_SUB_PORT} ${XNET_INBOUND_PORT} ${WEB_BASE_PATH}' \
    < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf
nginx -t

echo "▶️  Starting xnet-server on port $XNET_PANEL_PORT..."
# فقط env var های .env رو به xnet-server پاس بده — PORT محیطی Railway دست نخوره
env \
    PORT="${XNET_PANEL_PORT}" \
    DATABASE_PATH="$(grep '^DATABASE_PATH=' $ENV_FILE | cut -d= -f2-)" \
    STATIC_DIR="/app/dist" \
    JWT_SECRET="$(grep '^JWT_SECRET=' $ENV_FILE | cut -d= -f2-)" \
    WEB_BASE_PATH="${BASE}" \
    ADMIN_USERNAME="$(grep '^ADMIN_USERNAME=' $ENV_FILE | cut -d= -f2-)" \
    ADMIN_PASSWORD="$(grep '^ADMIN_PASSWORD=' $ENV_FILE | cut -d= -f2-)" \
    SINGBOX_CONFIG_PATH="/etc/sing-box/config.json" \
    SINGBOX_BINARY_PATH="/usr/local/bin/sing-box" \
    NODE_ROLE="panel" \
    /app/xnet-server &

echo "⏳ Waiting for xnet-server..."
for i in $(seq 1 20); do
    if bash -c "echo >/dev/tcp/127.0.0.1/${XNET_PANEL_PORT}" 2>/dev/null; then
        echo "✅ xnet-server ready."
        break
    fi
    sleep 1
done

echo "▶️  Starting nginx on port $NGINX_PORT..."
exec nginx -g "daemon off;"
