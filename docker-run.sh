#!/bin/sh

if [[ -z "$GID" ]]; then
    GID="$UID"
fi

function fixperms {
    chown -R $UID:$GID /data
}

mkdir -p /data

if [[ ! -f /data/config.yaml ]] && [[ -n "$HOMESERVER_DOMAIN" ]]; then
    echo "Generating Telegram bridge config..."
    
    # Generate config to a temp location first
    python3 -m mautrix_telegram -g -c /tmp/config.yaml
    
    if [[ ! -f /tmp/config.yaml ]]; then
        echo "ERROR: Failed to generate config!"
        exit 1
    fi
    
    # Now patch and move to /data
    cat > /tmp/config_patch.py << 'EOPATCH'
import yaml
import os
import shutil

with open('/tmp/config.yaml', 'r') as f:
    config = yaml.safe_load(f)

# Update with our environment variables
config['homeserver']['address'] = os.environ.get('HOMESERVER_ADDRESS', 'http://localhost:8008')
config['homeserver']['domain'] = os.environ['HOMESERVER_DOMAIN']

config['appservice']['address'] = os.environ.get('APPSERVICE_ADDRESS', 'http://localhost:29317')  
config['appservice']['hostname'] = os.environ.get('APPSERVICE_HOSTNAME', '0.0.0.0')
config['appservice']['port'] = int(os.environ.get('APPSERVICE_PORT', '29317'))
config['appservice']['id'] = 'telegram'
config['appservice']['bot_username'] = 'telegrambot'

config['appservice']['database']['uri'] = os.environ['DATABASE_URL']

config['telegram']['api_id'] = int(os.environ['TELEGRAM_API_ID'])
config['telegram']['api_hash'] = os.environ['TELEGRAM_API_HASH']

config['bridge']['username_template'] = 'telegram_{userid}'
config['bridge']['displayname_template'] = '{displayname} (TG)'
config['bridge']['permissions'][os.environ['HOMESERVER_DOMAIN']] = 'user'
config['bridge']['permissions']['*'] = 'relay'

# Fix logging
if 'logging' in config and 'version' not in config['logging']:
    config['logging']['version'] = 1

with open('/data/config.yaml', 'w') as f:
    yaml.dump(config, f, default_flow_style=False)
    
print("Config generated and saved to /data/config.yaml")
EOPATCH

    python3 /tmp/config_patch.py
    
    if [[ ! -f /data/config.yaml ]]; then
        echo "ERROR: Failed to create /data/config.yaml!"
        exit 1
    fi
    
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
