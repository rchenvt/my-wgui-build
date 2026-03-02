FROM alpine:3.23

ARG TARGETARCH
# 1. Install dependencies, create user, and clean up
RUN apk add --no-cache \
    wireguard-tools \
    jq \
    libcap \
    catatonit \
    iptables \
    iproute2 \
    curl \
    tar

 # Create the wgui user
RUN addgroup -g 1000 wgui && adduser -u 1000 -G wgui -D wgui

 # Install WireGuard-UI
RUN curl -L https://github.com/ngoduykhanh/wireguard-ui/releases/download/v0.6.2/wireguard-ui-v0.6.2-linux-${TARGETARCH}.tar.gz \
 	| tar -xz -C /usr/local/bin/ \
 && chmod +x /usr/local/bin/wireguard-ui \
 # Cleanup
 && apk del curl tar \
 && rm -rf /var/cache/apk/*

COPY init.sh /init.sh
RUN chmod +x /init.sh
# make wg show work
#RUN setcap cap_net_admin+ep /usr/bin/wg \
RUN setcap cap_net_admin+ep /usr/local/bin/wireguard-ui

ENV WGUI_MANAGE_START=true \
    WGUI_MANAGE_RESTART=true \
    WGUI_CONFIG_FILE_PATH=/etc/wireguard/wg0.conf

#VOLUME ["/etc/wireguard"]
#EXPOSE 51823/udp 5000/tcp

RUN mkdir -p /app/db && \
	chown -R wgui:wgui /app

# Container starts as root to manage kernel/iptables, then drops privs for UI
ENTRYPOINT ["/usr/bin/catatonit", "--", "/init.sh"]
