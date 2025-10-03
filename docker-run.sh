#!/bin/sh

if [[ -z "$GID" ]]; then
    GID="$UID"
fi

function fixperms {
    chown -R $UID:$GID /data
}

cd /opt/mautrix-telegram

mkdir -p /data

# Always regenerate and patch config
if [[ -f /data/config.yaml ]]; then
    rm -f /data/config.yaml
fi

echo "Creating Telegram bridge config..."
cp example-config.yaml /data/config.yaml

echo "Patching config with yq..."

# Use yq to properly modify YAML (like original script does for logging)
yq -i ".homeserver.address = \"${HOMESERVER_ADDRESS}\"" /data/config.yaml
yq -i ".homeserver.domain = \"${HOMESERVER_DOMAIN}\"" /data/config.yaml
yq -i ".appservice.database.type = \"postgres\"" /data/config.yaml
yq -i ".appservice.database.uri = \"${DATABASE_URL}\"" /data/config.yaml
yq -i ".telegram.api_id = ${TELEGRAM_API_ID}" /data/config.yaml
yq -i ".telegram.api_hash = \"${TELEGRAM_API_HASH}\"" /data/config.yaml

echo "Config patched successfully!"

if [[! -f /data/registration.yaml ]]; then
    python3 -m mautrix_telegram -g -c /data/config.yaml -r /data/registration.yaml || exit $?
    echo "Registration generated!"
    exit
fi

fixperms
exec su-exec $UID:$GID python3 -m mautrix_telegram -c /data/config.yaml
