#!/bin/bash
set -e

echo "🚀 X-Net + sing-box + nginx on Railway..."

XNET_PANEL_PORT=2053
XNET_SUB_PORT=2096
XNET_INBOUND_PORT=8080
NGINX_PORT="${PORT:-3000}"
export NGINX_PORT XNET_PANEL_PORT XNET_SUB_PORT XNET_INBOUND_PORT

# ── .env ─────────────────────────────────────────────────────────────────
mkdir -p /opt/xnet/data
ENV_FILE="/opt/xnet/data/.env"
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

# ── sing-box config ────────────────────────────────────────────────────────
# اگه X-Net هنوز config نساخته یه VLESS+WS inbound روی 8080 میذاریم
# X-Net بعداً این رو override میکنه وقتی inbound میسازی
if [ ! -f "/etc/sing-box/config.json" ]; then
    cat > /etc/sing-box/config.json << 'SBEOF'
{
  "log": { "level": "info", "timestamp": true },
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-in",
      "listen": "0.0.0.0",
      "listen_port": 8080,
      "users": [],
      "transport": {
        "type": "ws",
        "path": "/vl"
      }
    }
  ],
  "outbounds": [
    { "type": "direct", "tag": "direct" },
    { "type": "block", "tag": "block" }
  ]
}
SBEOF
fi

# ── sing-box start ─────────────────────────────────────────────────────────
echo "▶️  Starting sing-box on port $XNET_INBOUND_PORT..."
/usr/local/bin/sing-box run -c /etc/sing-box/config.json &
SINGBOX_PID=$!
sleep 2

if kill -0 $SINGBOX_PID 2>/dev/null; then
    echo "✅ sing-box running (pid $SINGBOX_PID)"
else
    echo "⚠️  sing-box failed to start — check config"
fi

# ── nginx config ──────────────────────────────────────────────────────────
envsubst '${NGINX_PORT} ${XNET_PANEL_PORT} ${XNET_SUB_PORT} ${XNET_INBOUND_PORT} ${WEB_BASE_PATH}' \
    < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf
nginx -t

# ── xnet-server ───────────────────────────────────────────────────────────
echo "▶️  Starting xnet-server on port $XNET_PANEL_PORT..."
cd /opt/xnet
env \
    PORT="${XNET_PANEL_PORT}" \
    DATABASE_PATH="/opt/xnet/data/xnet.db" \
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
