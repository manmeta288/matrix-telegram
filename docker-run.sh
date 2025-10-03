#!/bin/sh

if [[ -z "$GID" ]]; then
    GID="$UID"
fi

function fixperms {
    chown -R $UID:$GID /data
}

cd /opt/mautrix-telegram
mkdir -p /data

# Force delete ANY old config
rm -f /data/config.yaml /data/registration.yaml

echo "Creating fresh Telegram bridge config..."
cp example-config.yaml /data/config.yaml

echo "Patching config..."

# Patch with yq - verify each command works
yq eval -i ".homeserver.address = \"${HOMESERVER_ADDRESS}\"" /data/config.yaml
yq eval -i ".homeserver.domain = \"${HOMESERVER_DOMAIN}\"" /data/config.yaml
yq eval -i ".appservice.database.type = \"postgres\"" /data/config.yaml
yq eval -i ".appservice.database.uri = \"${DATABASE_URL}\"" /data/config.yaml
yq eval -i ".telegram.api_id = ${TELEGRAM_API_ID}" /data/config.yaml
yq eval -i ".telegram.api_hash = \"${TELEGRAM_API_HASH}\"" /data/config.yaml
yq eval -i ".logging.handlers.file.filename = \"/data/mautrix-telegram.log\"" /data/config.yaml

# Verify database was actually set
DB_TYPE=$(yq eval '.appservice.database.type' /data/config.yaml)
echo "Database type set to: $DB_TYPE"

if [[ "$DB_TYPE" != "postgres" ]]; then
    echo "ERROR: Database config failed!"
    exit 1
fi

echo "Config patched successfully!"

if [[ ! -f /data/registration.yaml ]]; then
    python3 -m mautrix_telegram -g -c /data/config.yaml -r /data/registration.yaml || exit $?
    echo "Registration generated!"
    exit
fi

fixperms
exec su-exec $UID:$GID python3 -m mautrix_telegram -c /data/config.yaml
