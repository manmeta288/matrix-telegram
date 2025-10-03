#!/bin/sh

if [[ -z "$GID" ]]; then
    GID="$UID"
fi

function fixperms {
    chown -R $UID:$GID /data
}

mkdir -p /data

if [[ ! -f /data/config.yaml ]] && [[ -n "$HOMESERVER_DOMAIN" ]]; then
    echo "Creating Telegram bridge config..."
    
    # Copy example config
    cp /opt/mautrix-telegram/example-config.yaml /data/config.yaml
    
    # Patch config using sed (no Python dependencies needed)
    sed -i "s|address: http://localhost:8008|address: ${HOMESERVER_ADDRESS:-http://localhost:8008}|g" /data/config.yaml
    sed -i "s|domain: example.com|domain: ${HOMESERVER_DOMAIN}|g" /data/config.yaml
    sed -i "s|address: http://localhost:29317|address: ${APPSERVICE_ADDRESS:-http://localhost:29317}|g" /data/config.yaml
    sed -i "s|hostname: 0.0.0.0|hostname: ${APPSERVICE_HOSTNAME:-0.0.0.0}|g" /data/config.yaml
    sed -i "s|port: 29317|port: ${APPSERVICE_PORT:-29317}|g" /data/config.yaml
    sed -i "s|id: telegram|id: telegram|g" /data/config.yaml
    sed -i "s|bot_username: telegrambot|bot_username: telegrambot|g" /data/config.yaml
    sed -i "s|uri: postgres://username:password@hostname/db|uri: ${DATABASE_URL}|g" /data/config.yaml
    sed -i "s|api_id: 12345|api_id: ${TELEGRAM_API_ID}|g" /data/config.yaml
    sed -i "s|api_hash: tjyd5yge35lbodk1xwzw2jstp90k55qz|api_hash: ${TELEGRAM_API_HASH}|g" /data/config.yaml
    
    echo "Config created successfully!"
fi

if [[ ! -f /data/registration.yaml ]]; then
    python3 -m mautrix_telegram -g -c /data/config.yaml -r /data/registration.yaml || exit $?
    echo "Registration generated!"
    exit
fi

cd /data
fixperms
exec su-exec $UID:$GID python3 -m mautrix_telegram
