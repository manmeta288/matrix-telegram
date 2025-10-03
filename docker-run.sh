#!/bin/sh

if [[ -z "$GID" ]]; then
    GID="$UID"
fi

function fixperms {
    chown -R $UID:$GID /data
}

mkdir -p /data

# ALWAYS remove old config to regenerate with current env vars
if [[ -f /data/config.yaml ]]; then
    echo "Removing existing config to regenerate..."
    rm -f /data/config.yaml
fi

echo "Creating Telegram bridge config from example..."

# Copy example config
cp /opt/mautrix-telegram/example-config.yaml /data/config.yaml

# Patch with environment variables using sed
sed -i "s|address: https://example.com|address: ${HOMESERVER_ADDRESS:-http://localhost:8008}|g" /data/config.yaml
sed -i "s|domain: example.com|domain: ${HOMESERVER_DOMAIN}|g" /data/config.yaml  
sed -i "s|uri: postgresql://username:password@hostname/db|uri: ${DATABASE_URL}|g" /data/config.yaml
sed -i "s|api_id: 12345|api_id: ${TELEGRAM_API_ID}|g" /data/config.yaml
sed -i "s|api_hash: tjyd5yge35lbodk1xwzw2jstp90k55qz|api_hash: ${TELEGRAM_API_HASH}|g" /data/config.yaml

echo "Config created successfully!"

if [[ ! -f /data/registration.yaml ]]; then
    python3 -m mautrix_telegram -g -c /data/config.yaml -r /data/registration.yaml || exit $?
    echo "Registration generated!"
    exit
fi

cd /data
fixperms
exec su-exec $UID:$GID python3 -m mautrix_telegram
