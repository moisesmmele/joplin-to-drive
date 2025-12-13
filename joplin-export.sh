#!/bin/bash

# JOPLIN EXPORT AND SYNC SCRIPT v1.1

set -euo pipefail

# --- Configuration (Defaults provided, overrides via ENV) ---
# Joplin
TARGET_ID="${JOPLIN_SYNC_TARGET_ID:-9}" # 9 is standard for Joplin Server
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
flock -n 200 || { echo "Sync already in progress. Skipping."; exit 0; }
trap 'rm -f "$LOCKFILE"' EXIT

if [ -z "$JOPLIN_URL" ]; then
    echo "ERROR: JOPLIN_SERVER_URL is not set."
    exit 1
fi

# --- 1. Configure Joplin (Idempotent) ---
CURRENT_TARGET="$(joplin config sync.target 2>/dev/null || echo "0")"

if [[ "$CURRENT_TARGET" != "$TARGET_ID" ]]; then
    echo "Configuring Joplin CLI..."
    joplin config sync.target "$TARGET_ID"
    joplin config "sync.$TARGET_ID.path" "$JOPLIN_URL"
    joplin config "sync.$TARGET_ID.username" "$JOPLIN_USER"
    joplin config "sync.$TARGET_ID.password" "$JOPLIN_PASS"
    joplin config encryption.enabled false
fi

# --- 2. Sync & Export ---
echo "[$(date)] 1/3: Syncing Joplin from Server..."
joplin sync

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
    --checksum --delete-excluded --progress

echo "[$(date)] Job Complete."
