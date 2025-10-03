#!/bin/sh

cd /opt/mautrix-telegram
mkdir -p /data

# Use our pre-made config template with envsubst
if [[ ! -f /data/config.yaml ]]; then
    echo "Creating config from template..."
    envsubst < /telegram/config.yaml > /data/config.yaml
fi

if [[ ! -f /data/registration.yaml ]]; then
    python3 -m mautrix_telegram -g -c /data/config.yaml -r /data/registration.yaml || exit $?
    echo "Registration generated!"
    exit
fi

chown -R $UID:$GID /data
exec su-exec $UID:$GID python3 -m mautrix_telegram -c /data/config.yaml
