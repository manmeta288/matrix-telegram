#!/bin/sh

if [[ -z "$GID" ]]; then
    GID="$UID"
fi

function fixperms {
    chown -R $UID:$GID /data
}

cd /opt/mautrix-telegram
mkdir -p /data

# Force fresh start
rm -f /data/config.yaml /data/registration.yaml

echo "Creating Telegram bridge config..."
cp example-config.yaml /data/config.yaml

echo "Patching config with sed..."

# Patch homeserver settings
sed -i "s|address: https://matrix.example.com|address: $HOMESERVER_ADDRESS|g" /data/config.yaml
sed -i "s|domain: example.com|domain: $HOMESERVER_DOMAIN|g" /data/config.yaml

# Patch database settings - THIS IS THE KEY FIX
sed -i "/^  database:/,/^  [a-z]/ s|type: sqlite|type: postgres|" /data/config.yaml
sed -i "/^  database:/,/^  [a-z]/ s|uri: mautrix-telegram.db|uri: $DATABASE_URL|" /data/config.yaml

# Patch Telegram API settings
sed -i "s|api_id: 12345|api_id: $TELEGRAM_API_ID|g" /data/config.yaml
sed -i "s|api_hash: tjyd5yge35lbodk1xwzw2jstp90k55qz|api_hash: $TELEGRAM_API_HASH|g" /data/config.yaml

# Fix log file location
sed -i "s|filename: ./mautrix-telegram.log|filename: /data/mautrix-telegram.log|g" /data/config.yaml

# Verify it worked
echo "Verifying config..."
grep "type: postgres" /data/config.yaml && echo "✓ Database type OK" || echo "✗ Database type FAILED"

echo "Config ready!"

if [[ ! -f /data/registration.yaml ]]; then
    python3 -m mautrix_telegram -g -c /data/config.yaml -r /data/registration.yaml || exit $?
    echo "Registration generated!"
    exit
fi

fixperms
exec su-exec $UID:$GID python3 -m mautrix_telegram -c /data/config.yaml
