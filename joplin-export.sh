#!/bin/bash

set -euo pipefail

# Force standard path to find node, programs
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${HOME:-/home/appuser}/.local/bin"

# enforce user home path
export HOME="${HOME:-/home/appuser}"

# prevents TUI libraries from crashing (?)
export TERM=xterm

# check for essential commands
for cmd in joplin rclone date flock; do
	if ! command -v "$cmd" >/dev/null 2>&1; then
		echo "ERROR: required command $cmd not found"
		exit 2
	fi
done

# simple file locking to prevent overlap
LOCKFILE="/tmp/joplin-export.lock"

exec 200>"$LOCKFILE"
if ! flock -n 200; then
	echo "Another instance is already running. Exiting..."
	exit 0;
fi

# release lock on exit
trap 'rm -f $LOCKFILE" EXIT

# declare staging directory and validate to avoid catastrophical data loss
EXPORT_DIR="$HOME/export"

if [ -z "$EXPORT_DIR:-}" ] || [ "${EXPORT_DIR}" = "/" ]; then
	echo "ERROR: EXPORT_DIR is not set or points to filesystem root. Aborting to avoid destructive delete."
	exit 3;


# declare joplin sync target id (9 for Joplin Server)
TARGET_ID=9

#check if joplin-cli sync target is already set. If not, configure it.
CURRENT_TARGET="$(joplin config sync.target 2>/dev/null || echo "0")"

if [[ "$CURRENT_TARGET" != "$TARGET_ID" ]]; then

	echo "[$(date)] configuring Joplin Sync Target..."

	# Check for required ENV vars
	if [ -z "${JOPLIN_SERVER_URL:-}" ] || [ -z "${JOPLIN_SERVER_EMAIL:-}" ] || [ -z "${JOPLIN_SERVER_PASSWORD:-}" ]; then
		echo "ERROR: Missing Joplin sync target authentication environment variables"
		exit 1
	fi

	# Set Joplin Sync Target id
	joplin config sync.target $TARGET_ID

	# Set Joplin Sync Target url
	joplin config sync.$TARGET_ID.path "$JOPLIN_SERVER_URL"

	# Set Joplin Sync Target credentials
	joplin config sync.$TARGET_ID.username "$JOPLIN_SERVER_EMAIL"
	joplin config sync.$TARGET_ID.password "$JOPLIN_SERVER_PASSWORD"

	# Set Joplin Encryption
	joplin config encryption.enabled false

	echo "Configuration complete."

else
	echo "[$(date)] Joplin is already configured."
fi

echo "-------------------------------------------------------"
echo "[$(date)] Starting Sync and Export Job"

# Pull changes from sync target to local container database
echo "[$(date)] 1/3: Syncing with target..."
joplin sync

# Export notes to readable, markdown format
echo "[$(date)] 2/3: Exporting notes to Markdown..."

# Safely clean staging area
if [ -d "$EXPORT_DIR" ]; then
    # remove contents only
    rm -rf "${EXPORT_DIR:?}/"*
else
    mkdir -p "$EXPORT_DIR"
fi

# run the export command
joplin export "$EXPORT_DIR" --format md

# Push notes to previously configured rclone target
echo "[$(date)] 3/3: Pushing to Google Drive..."

#check for configured remotes
if ! rclone listremotes 2>/dev/null | grep -qE "^${RCLONE_REMOTE}(:|$)"; then
	echo "Error: rclone remote $RCLONE_REMOTE not configured."
	echo "Notes were exported, but NOT synced to gdrive."
	exit 1
fi

# declare target remote
RCLONE_REMOTE="gdrive"
RCLONE_DEST="JoplinNotes"

#run the sync
rclone sync "$EXPORT_DIR" "gdrive:joplinNotes" --checksum --delete-excluded

echo "[$(date)] Sync Job Done."
