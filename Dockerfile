FROM alpine:3.19

RUN apk add --no-cache \
    curl \
    bash \
    ca-certificates \
    tzdata \
    nginx \
    gettext \
    sqlite \
    libcap \
    && ln -sf /usr/share/zoneinfo/Asia/Tehran /etc/localtime \
    && setcap 'cap_net_bind_service=+ep' /usr/sbin/nginx

# ── X-Net panel ───────────────────────────────────────────────────────────
ARG XNET_VERSION=v1.3.0
RUN mkdir -p /app \
    && curl -fsSL \
       "https://github.com/xpanel-cp/x-net/releases/download/${XNET_VERSION}/xnet-panel-${XNET_VERSION}-linux-amd64.tar.gz" \
       -o /tmp/xnet.tar.gz \
    && tar -xzf /tmp/xnet.tar.gz -C /app --strip-components=1 \
    && chmod +x /app/xnet-server \
    && rm /tmp/xnet.tar.gz

# ── sing-box core ─────────────────────────────────────────────────────────
ARG SINGBOX_VERSION=1.14.0
RUN curl -fsSL \
    "https://github.com/SagerNet/sing-box/releases/download/v${SINGBOX_VERSION}/sing-box-${SINGBOX_VERSION}-linux-amd64.tar.gz" \
    -o /tmp/singbox.tar.gz \
    && tar -xzf /tmp/singbox.tar.gz -C /tmp \
    && mv /tmp/sing-box-${SINGBOX_VERSION}-linux-amd64/sing-box /usr/local/bin/sing-box \
    && chmod +x /usr/local/bin/sing-box \
    && rm -rf /tmp/singbox.tar.gz /tmp/sing-box-*

RUN mkdir -p /opt/xnet/data /etc/sing-box /var/log/nginx /run/nginx

COPY nginx.conf.template /etc/nginx/nginx.conf.template
COPY start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
