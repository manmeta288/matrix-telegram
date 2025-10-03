#!/bin/sh

if [[ -z "$GID" ]]; then
    GID="$UID"
fi

function fixperms {
    chown -R $UID:$GID /data
}

mkdir -p /data

# Always regenerate config
if [[ -f /data/config.yaml ]]; then
    echo "Removing existing config..."
    rm -f /data/config.yaml
fi

echo "Creating Telegram bridge config..."

# Copy example config
cp /opt/mautrix-telegram/example-config.yaml /data/config.yaml

# Debug: Show what database section looks like before sed
echo "DEBUG: Database section before sed:"
grep -A 3 "^appservice:" /data/config.yaml | grep -A 2 "database:"

# Patch with correct patterns for mautrix-telegram
sed -i 's|address: https://matrix.example.com|address: '"${HOMESERVER_ADDRESS:-http://localhost:8008}"'|g' /data/config.yaml
sed -i 's|domain: example.com|domain: '"${HOMESERVER_DOMAIN}"'|g' /data/config.yaml  

# Fix database config - mautrix-telegram uses different structure
sed -i '/^appservice:/,/^[^ ]/ s|type: sqlite|type: postgres|' /data/config.yaml
sed -i '/^appservice:/,/^[^ ]/ s|uri: .*\.db|uri: '"${DATABASE_URL}"'|' /data/config.yaml

sed -i 's|api_id: 12345|api_id: '"${TELEGRAM_API_ID}"'|g' /data/config.yaml
sed -i 's|api_hash: .*|api_hash: '"${TELEGRAM_API_HASH}"'|g' /data/config.yaml

echo "DEBUG: Database section after sed:"
grep -A 3 "^appservice:" /data/config.yaml | grep -A 2 "database:"

echo "Config created successfully!"

if [[ ! -f /data/registration.yaml ]]; then
    python3 -m mautrix_telegram -g -c /data/config.yaml -r /data/registration.yaml || exit $?
    echo "Registration generated!"
    exit
fi

cd /data
fixperms
exec su-exec $UID:$GID python3 -m mautrix_telegram
