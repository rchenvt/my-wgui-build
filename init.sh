#!/bin/sh

# 1. Path Discovery
CONF="/etc/wireguard/wg0.conf"
DB_DIR="/app"

# Ensure the wgui user owns the config directory so it can write the DB and wg0.conf
# mkdir -p "$DB_DIR/db"
# chown -R wgui:wgui "$DB_DIR"

if [ -f "$DB_DIR/db/server/global_settings.json" ]; then
    JSON_CONF=$(jq -r .config_file_path "$DB_DIR/db/server/global_settings.json" 2>/dev/null)
    [ -n "$JSON_CONF" ] && [ "$JSON_CONF" != "null" ] && CONF="$JSON_CONF"
fi

INTERFACE=$(basename "${CONF%.*}")

# 2. Start VPN (as root)
if [ "$WGUI_MANAGE_START" = "true" ]; then
    echo "[init] Starting WireGuard interface $INTERFACE as root..."
    wg-quick up "$CONF"
    chown wgui:wgui "$CONF"
    trap 'echo "[init] Shutting down $INTERFACE..."; wg-quick down "$CONF"; exit 0' TERM
fi

# 3. Monitor for Changes (as root)
if [ "$WGUI_MANAGE_RESTART" = "true" ]; then
    [ -f "$CONF" ] || touch "$CONF"
    echo "[init] Monitoring $CONF for changes..."
    inotifyd - "$CONF":w | while read -r event file; do
        echo "[init] Config change detected. Restarting $INTERFACE..."
        wg-quick down "$CONF"
        wg-quick up "$CONF"
        chown wgui:wgui "$CONF"
    done &
fi

# 4. Start UI as wgui (User 1000)
echo "[init] Starting WireGuard-UI as wgui user..."
cd "$DB_DIR" || exit 1
#exec su-exec wgui /usr/local/bin/wireguard-ui
exec capsh --user=wgui --keep=1 -- -c "/usr/local/bin/wireguard-ui"
