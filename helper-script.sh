#!/bin/bash

#JOPLIN EXPORT AND SYNC HELPER TOOL v1.1

# Define where you want the config file
CONFIG_DIR="./config"
CONFIG_FILE="$CONFIG_DIR/rclone.conf"
mkdir -p "$CONFIG_DIR"

echo ">>> This script requires Rclone installed on your local machine."
echo ">>> Initiating Google Drive Auth..."

# Get the JSON token
TOKEN_JSON=$(rclone authorize "drive" | tail -n 1)

# Check if we got a valid JSON (basic check)
if [[ "$TOKEN_JSON" != *"access_token"* ]]; then
    echo "Error: Failed to retrieve token. Output: $TOKEN_JSON"
    exit 1
fi

echo ">>> Authentication successful."
echo ">>> Writing config to $CONFIG_FILE"

# Write a clean rclone.conf file
cat > "$CONFIG_FILE" <<EOF
[gdrive]
type = drive
scope = drive
token = $TOKEN_JSON
EOF

echo ">>> Done! You can now run 'docker-compose up -d'"
