#!/bin/sh

if [[ -z "$GID" ]]; then
    GID="$UID"
fi

function fixperms {
    chown -R $UID:$GID /data
}

# Change to where example-config.yaml lives
cd /opt/mautrix-telegram

mkdir -p /data

# Always regenerate config
if [[ -f /data/config.yaml ]]; then
    echo "Removing existing config..."
    rm -f /data/config.yaml
fi

echo "Creating Telegram bridge config..."

# Copy example config
cp example-config.yaml /data/config.yaml

# Verify copy worked
if [[ ! -f /data/config.yaml ]]; then
    echo "ERROR: Failed to copy example config!"
    exit 1
fi

echo "Patching config with environment variables..."

# Use printf to handle special characters in URLs properly
HOMESERVER_ADDR="${HOMESERVER_ADDRESS:-http://localhost:8008}"
HOMESERVER_DOM="${HOMESERVER_DOMAIN}"
DB_URI="${DATABASE_URL}"
TG_API_ID="${TELEGRAM_API_ID}"
TG_API_HASH="${TELEGRAM_API_HASH}"

# Replace values - use | as delimiter since URLs contain /
sed -i "s|address: https://matrix.example.com|address: ${HOMESERVER_ADDR}|g" /data/config.yaml
sed -i "s|domain: example.com|domain: ${HOMESERVER_DOM}|g" /data/config.yaml  
sed -i "s|type: sqlite|type: postgres|g" /data/config.yaml
sed -i "s|uri: mautrix-telegram.db|uri: ${DB_URI}|g" /data/config.yaml
sed -i "s|api_id: 12345|api_id: ${TG_API_ID}|g" /data/config.yaml
sed -i "s|api_hash: tjyd5yge35lbodk1xwzw2jstp90k55qz|api_hash: ${TG_API_HASH}|g" /data/config.yaml

# Debug: verify critical values were set
echo "DEBUG: Checking config values..."
grep "address:" /data/config.yaml | head -1
grep "domain:" /data/config.yaml | head -1
grep "type: postgres" /data/config.yaml

echo "Config patched successfully!"

if [[ ! -f /data/registration.yaml ]]; then
    python3 -m mautrix_telegram -g -c /data/config.yaml -r /data/registration.yaml || exit $?
    echo "Registration generated!"
    exit
fi

cd /data
fixperms
exec su-exec $UID:$GID python3 -m mautrix_telegram
