#!/bin/sh

# Allow direct startup bypass
if [ ! -z "$MAUTRIX_DIRECT_STARTUP" ]; then
	if [ $(id -u) == 0 ]; then
		echo "|---------------------------------------------|"
		echo "| Warning: running bridge unsafely as root   |"
		echo "|---------------------------------------------|"
	fi
	exec python3 -m mautrix_telegram -c /data/config.yaml
elif [ $(id -u) != 0 ]; then
	echo "The startup script must run as root."
	exit 1
fi

# Define functions
function fixperms {
	chown -R $UID:$GID /data
	
	# Disable file logging
	if [[ "$(yq e '.logging.handlers.file.filename' /data/config.yaml 2>/dev/null)" == "./mautrix-telegram.log" ]]; then
		yq -I4 e -i 'del(.logging.root.handlers[] | select(. == "file"))' /data/config.yaml
		yq -I4 e -i 'del(.logging.handlers.file)' /data/config.yaml
	fi
}

function apply_config_settings {
	echo "Applying environment variable configuration..."
	
	# Homeserver
	yq -I4 e -i ".homeserver.address = \"${HOMESERVER_ADDRESS}\"" /data/config.yaml
	yq -I4 e -i ".homeserver.domain = \"${HOMESERVER_DOMAIN}\"" /data/config.yaml
	
	# Appservice
	if [[ -n "$APPSERVICE_ADDRESS" ]]; then
		yq -I4 e -i ".appservice.address = \"$APPSERVICE_ADDRESS\"" /data/config.yaml
	fi
	yq -I4 e -i ".appservice.hostname = \"${APPSERVICE_HOSTNAME:-0.0.0.0}\"" /data/config.yaml
	yq -I4 e -i ".appservice.port = ${APPSERVICE_PORT:-29317}" /data/config.yaml
	
	# Database
	yq -I4 e -i ".appservice.database = \"$DATABASE_URL\"" /data/config.yaml
	
	# Telegram API
	yq -I4 e -i ".telegram.api_id = $TELEGRAM_API_ID" /data/config.yaml
	yq -I4 e -i ".telegram.api_hash = \"$TELEGRAM_API_HASH\"" /data/config.yaml
	
	# Provisioning
	yq -I4 e -i ".appservice.provisioning.enabled = true" /data/config.yaml
	yq -I4 e -i ".appservice.provisioning.shared_secret = \"generate\"" /data/config.yaml
	
	# Encryption
	yq -I4 e -i ".bridge.encryption.allow = true" /data/config.yaml
	yq -I4 e -i ".bridge.encryption.default = true" /data/config.yaml
	yq -I4 e -i ".bridge.encryption.require = false" /data/config.yaml
	
	# Backfilling
	yq -I4 e -i ".bridge.backfill.enable = true" /data/config.yaml
	yq -I4 e -i ".bridge.backfill.forward_limits.initial.user = 1000" /data/config.yaml
	yq -I4 e -i ".bridge.backfill.forward_limits.initial.channel = 500" /data/config.yaml
	yq -I4 e -i ".bridge.backfill.forward_limits.initial.supergroup = 100" /data/config.yaml
	yq -I4 e -i ".bridge.backfill.incremental.messages_per_batch = 1000" /data/config.yaml
	
	# Double Puppeting
	yq -I4 e -i ".bridge.double_puppet_server_map = {\"$HOMESERVER_DOMAIN\": \"$HOMESERVER_ADDRESS\"}" /data/config.yaml
	yq -I4 e -i ".bridge.double_puppet_allow_discovery = true" /data/config.yaml
	yq -I4 e -i ".bridge.sync_with_custom_puppets = false" /data/config.yaml
	
	# Features
	yq -I4 e -i ".bridge.sync_direct_chat_list = false" /data/config.yaml
	yq -I4 e -i ".bridge.delivery_receipts = true" /data/config.yaml
	yq -I4 e -i ".bridge.allow_avatar_remove = true" /data/config.yaml
	yq -I4 e -i ".bridge.private_chat_portal_meta = \"default\"" /data/config.yaml
	
	# Relay Mode
	yq -I4 e -i ".bridge.relaybot.authless_portals = true" /data/config.yaml
	yq -I4 e -i ".bridge.relaybot.ignore_unbridged_group_chat = true" /data/config.yaml
	
	# Permissions - FIXED: Use proper dictionary syntax
	yq -I4 e -i ".bridge.permissions = {\"*\": \"relaybot\", \"$HOMESERVER_DOMAIN\": \"full\"}" /data/config.yaml
	if [[ -n "$ADMIN_USER" ]]; then
		yq -I4 e -i ".bridge.permissions.\"$ADMIN_USER\" = \"admin\"" /data/config.yaml
	fi
	
	echo "Configuration applied successfully"
}

cd /opt/mautrix-telegram

# Generate config on first run
if [ ! -f /data/config.yaml ]; then
	echo "=========================================="
	echo "Generating initial config.yaml..."
	cp example-config.yaml /data/config.yaml
	apply_config_settings
	fixperms
	echo "Config generated. Moving to registration generation..."
fi

# Always update config with latest env vars
apply_config_settings

# Generate registration if it doesn't exist
if [ ! -f /data/registration.yaml ]; then
	python3 -m mautrix_telegram -g -c /data/config.yaml -r /data/registration.yaml || exit $?
	echo "=========================================="
	echo "REGISTRATION FILE GENERATED"
	echo "=========================================="
	cat /data/registration.yaml
	echo "=========================================="
	echo ""
	echo "Add this to your Matrix homeserver's appservice config"
	echo "Then restart your homeserver and this bridge"
	echo "=========================================="
	fixperms
	exit
fi

# Start the bridge
fixperms
exec su-exec $UID:$GID python3 -m mautrix_telegram -c /data/config.yaml
