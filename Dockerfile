FROM alpine:3.19

RUN apk add --no-cache \
    curl \
    bash \
    ca-certificates \
    tzdata \
    nginx \
    gettext \
    sqlite \
    && ln -sf /usr/share/zoneinfo/Asia/Tehran /etc/localtime

ARG XNET_VERSION=v1.3.0
RUN mkdir -p /opt/xnet \
    && curl -fsSL \
       "https://github.com/xpanel-cp/x-net/releases/download/${XNET_VERSION}/xnet-panel-${XNET_VERSION}-linux-amd64.tar.gz" \
       -o /tmp/xnet.tar.gz \
    && tar -xzf /tmp/xnet.tar.gz -C /opt/xnet --strip-components=1 \
    && chmod +x /opt/xnet/xnet-server \
    && rm /tmp/xnet.tar.gz

RUN mkdir -p /opt/xnet/data /var/log/nginx /run/nginx /etc/sing-box

COPY nginx.conf.template /etc/nginx/nginx.conf.template
COPY start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
