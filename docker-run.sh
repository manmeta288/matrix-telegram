#!/bin/sh

if [[ -z "$GID" ]]; then
    GID="$UID"
fi

function fixperms {
    chown -R $UID:$GID /data
}

mkdir -p /data

if [[ ! -f /data/config.yaml ]] && [[ -n "$HOMESERVER_DOMAIN" ]]; then
    echo "Generating Telegram bridge config from environment variables..."
    cat > /data/config.yaml << EOF
homeserver:
    address: ${HOMESERVER_ADDRESS:-http://localhost:8008}
    domain: ${HOMESERVER_DOMAIN}

appservice:
    address: ${APPSERVICE_ADDRESS:-http://localhost:29317}
    hostname: ${APPSERVICE_HOSTNAME:-0.0.0.0}
    port: ${APPSERVICE_PORT:-29317}
    id: telegram
    bot_username: telegrambot

database:
    type: postgres
    uri: ${DATABASE_URL}

hacky_network_config_migrator: true

telegram:
    api_id: ${TELEGRAM_API_ID}
    api_hash: ${TELEGRAM_API_HASH}

bridge:
    username_template: "telegram_{userid}"
    displayname_template: "{displayname} (TG)"
    permissions:
        "*": relay
        "${HOMESERVER_DOMAIN}": user

logging:
    version: 1
    formatters:
        precise:
            format: "[%(levelname)-7s@%(name)s] %(message)s"
    handlers:
        console:
            class: logging.StreamHandler
            formatter: precise
    loggers:
        mau:
            level: DEBUG
        telethon:
            level: INFO
    root:
        level: INFO
        handlers: [console]
EOF
fi

if [[ ! -f /data/config.yaml ]]; then
    python3 -m mautrix_telegram -c /data/config.yaml -e
    exit
fi

if [[ ! -f /data/registration.yaml ]]; then
    python3 -m mautrix_telegram -g -c /data/config.yaml -r /data/registration.yaml || exit $?
    exit
fi

cd /data
fixperms
exec su-exec $UID:$GID python3 -m mautrix_telegram
