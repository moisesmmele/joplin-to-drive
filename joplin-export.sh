#!/bin/bash

# JOPLIN EXPORT AND SYNC SCRIPT v1.3
echo "[$(date)] Initializing Jopling Export and Sync script..."

set -euo pipefail

# --- Configuration (Defaults provided, overrides via ENV) ---

# Joplin
TARGET_ID="${JOPLIN_SYNC_TARGET_ID:-}"
JOPLIN_URL="${JOPLIN_SERVER_URL:-}"
JOPLIN_USER="${JOPLIN_SERVER_EMAIL:-}"
JOPLIN_PASS="${JOPLIN_SERVER_PASSWORD:-}"

# Rclone
REMOTE_NAME="${RCLONE_REMOTE_NAME:-gdrive}"
DEST_PATH="${RCLONE_DEST_PATH:-JoplinNotes}"

# Local Paths
EXPORT_DIR="${EXPORT_DIR:-/export}"
LOCKFILE="/tmp/joplin-export.lock"

# --- Pre-flight Checks ---
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${HOME:-/home/appuser}/.local/bin"
export HOME="${HOME:-/home/appuser}"

exec 200>"$LOCKFILE"
flock -n 200 || { echo "[$(date)] Sync already in progress. Skipping."; exit 0; }
trap 'rm -f "$LOCKFILE"' EXIT

if [ -z "$JOPLIN_URL" ]; then
    echo "ERROR: JOPLIN_SERVER_URL is not set."
    exit 1
fi

# --- 1. Configure Joplin (Idempotent) ---

# check if sync.target key in config export is already set;
# if not set, config with avalable env vars
JOPLIN_CONFIG="$(joplin config --export)"
if ! echo "$JOPLIN_CONFIG" | grep -q "\"sync.target\": $TARGET_ID"; then
    echo "[$(date)] Configuring Joplin CLI..."

    # Safety check for target id
    if [ -z "$TARGET_ID" ]; then
        echo "ERROR: TARGET_ID is not set."
        exit 1
    fi

    joplin config sync.target "$TARGET_ID"
    joplin config "sync.$TARGET_ID.path" "$JOPLIN_URL"
    joplin config "sync.$TARGET_ID.username" "$JOPLIN_USER"
    joplin config "sync.$TARGET_ID.password" "$JOPLIN_PASS"
    joplin config encryption.enabled false
else
    echo "[$(date)] Joplin is already configured."
fi

# --- 2. Sync & Export ---
echo "[$(date)] 1/3: Syncing Joplin from Server..."
joplin sync > /dev/null

echo "[$(date)] 2/3: Exporting to Markdown..."
# Clean export dir safely
find "$EXPORT_DIR" -mindepth 1 -delete
joplin export "$EXPORT_DIR" --format md

# --- 3. Push to Drive ---
echo "[$(date)] 3/3: Pushing to Google Drive ($REMOTE_NAME:$DEST_PATH)..."

# Check if remote exists in loaded config
if ! rclone listremotes | grep -q "^${REMOTE_NAME}:"; then
    echo "ERROR: Rclone remote '$REMOTE_NAME' not found in config."
    exit 1
fi

rclone sync "$EXPORT_DIR" "$REMOTE_NAME:$DEST_PATH" \
    --checksum --delete-excluded

echo "[$(date)] Job Complete."
