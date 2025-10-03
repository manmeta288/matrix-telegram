#!/bin/sh

if [[ -z "$GID" ]]; then
    GID="$UID"
fi

function fixperms {
    chown -R $UID:$GID /data
}

# CRITICAL: Change to /opt/mautrix-telegram directory where example-config.yaml lives
cd /opt/mautrix-telegram

mkdir -p /data

# Always regenerate config
if [[ -f /data/config.yaml ]]; then
    echo "Removing existing config..."
    rm -f /data/config.yaml
fi

echo "Creating Telegram bridge config..."

# Copy example config (we're in /opt/mautrix-telegram now, so relative path works)
cp example-config.yaml /data/config.yaml

# Now patch with sed using correct patterns from actual example config
sed -i 's|address: https://matrix.example.com|address: '"${HOMESERVER_ADDRESS:-http://localhost:8008}"'|g' /data/config.yaml
sed -i 's|domain: example.com|domain: '"${HOMESERVER_DOMAIN}"'|g' /data/config.yaml  
sed -i 's|type: sqlite|type: postgres|g' /data/config.yaml
sed -i 's|uri: mautrix-telegram.db|uri: '"${DATABASE_URL}"'|g' /data/config.yaml
sed -i 's|api_id: 12345|api_id: '"${TELEGRAM_API_ID}"'|g' /data/config.yaml
sed -i 's|api_hash: tjyd5yge35lbodk1xwzw2jstp90k55qz|api_hash: '"${TELEGRAM_API_HASH}"'|g' /data/config.yaml

echo "Config created successfully!"

if [[ ! -f /data/registration.yaml ]]; then
    python3 -m mautrix_telegram -g -c /data/config.yaml -r /data/registration.yaml || exit $?
    echo "Registration generated!"
    exit
fi

cd /data
fixperms
exec su-exec $UID:$GID python3 -m mautrix_telegram
