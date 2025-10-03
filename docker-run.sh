#!/bin/sh

if [[ -z "$GID" ]]; then
    GID="$UID"
fi

function fixperms {
    chown -R $UID:$GID /data
}

mkdir -p /data

# CRITICAL FIX: Remove old config so we can regenerate with correct logging
if [[ -f /data/config.yaml ]]; then
    echo "Removing old config to regenerate with proper logging..."
    rm -f /data/config.yaml
fi

if [[ ! -f /data/config.yaml ]] && [[ -n "$HOMESERVER_DOMAIN" ]]; then
    echo "Generating Telegram bridge config from environment variables..."
    
    # First generate default config with proper logging
    python3 -m mautrix_telegram -g -c /data/config.yaml -e || exit $?
    
    # Then modify the generated config with our settings
    cat > /tmp/config_patch.py << 'EOPATCH'
import yaml
import os

with open('/data/config.yaml', 'r') as f:
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

# FIX THE LOGGING CONFIG - Add version if missing
if 'logging' in config and 'version' not in config['logging']:
    config['logging']['version'] = 1
    print("Added version=1 to logging config")

with open('/data/config.yaml', 'w') as f:
    yaml.dump(config, f, default_flow_style=False)
    
print("Config patched successfully!")
EOPATCH

    python3 /tmp/config_patch.py
fi

if [[ ! -f /data/registration.yaml ]]; then
    python3 -m mautrix_telegram -g -c /data/config.yaml -r /data/registration.yaml || exit $?
    exit
fi

cd /data
fixperms
exec su-exec $UID:$GID python3 -m mautrix_telegram
