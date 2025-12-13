#!/usr/bin/env bash
# JOPLIN EXPORT AND SYNC HELPER TOOL v1.3
set -euo pipefail
IFS=$'\n\t'

CONFIG_DIR="./config"
CONFIG_FILE="$CONFIG_DIR/rclone.conf"
ENV_FILE=".env"

# Make directory and restrict permissions (config will be 600)
mkdir -p "$CONFIG_DIR"

# Utility
die() { echo "Error: $*" >&2; exit 1; }

# Safely compact JSON (remove newlines and leading/trailing whitespace)
compact_json() {
  local s
  s="$(printf '%s' "$1" | tr -d '\r' | awk 'BEGIN{ORS="";} {gsub(/^[ \t]+|[ \t]+$/, ""); print $0}')"
  # remove internal newlines
  s="$(printf '%s' "$s" | tr -d '\n')"
  printf '%s' "$s"
}

# Write rclone.conf with secure permissions
write_config() {
  local token_json="$1"
  if ! printf '%s' "$token_json" | grep -q '"access_token"'; then
    echo "Error: Provided token does not look like valid rclone/Google Drive JSON." >&2
    exit 1
  fi

  # compact into single-line JSON (rclone expects token = {...} on one line)
  local token_compact
  token_compact="$(compact_json "$token_json")"

  echo ">>> Writing config to $CONFIG_FILE ..."
  cat > "$CONFIG_FILE" <<EOF
[gdrive]
type = drive
scope = drive
token = $token_compact
EOF

  chmod 600 "$CONFIG_FILE"
  echo ">>> Success: configuration saved with permissions 600."
  echo ">>> You can now run 'docker-compose up -d' (or your container start command)."
}

# Prompt for selection
echo "=========================================="
echo "   Joplin-to-Drive Configuration Tool     "
echo "=========================================="
echo "This tool helps generate the rclone.conf file required for the container."
echo ""
echo "Where are you running this script?"
echo "1) Local Machine (I have a browser available)"
echo "2) Remote Server (Headless / SSH)"
read -r -p "Select option [1]: " CHOICE_INPUT || true
CHOICE="${CHOICE_INPUT:-1}"

# Option 1: local machine (interactive browser)
if [ "$CHOICE" -eq 1 ]; then
  echo ">>> Checking for rclone..."
  command -v rclone >/dev/null 2>&1 || die "rclone is not installed. Please install it first."

  echo ">>> Initiating Google Drive auth with rclone..."
  echo "A browser window should open for authorization (if rclone supports it here)."

  # Capture full output (rclone authorize emits JSON). Do NOT tail the output.
  TOKEN_JSON="$(rclone authorize "drive" 2>/dev/null || true)"

  if [ -z "$TOKEN_JSON" ]; then
    die "rclone authorize produced no output. Run 'rclone authorize \"drive\"' manually and paste JSON (remote mode)."
  fi

  write_config "$TOKEN_JSON"
  exit 0
fi

# Option 2: remote/headless
if [ "$CHOICE" -eq 2 ]; then
  echo ">>> Remote/headless mode selected."

  TOKEN_JSON=""
  FOUND_IN_ENV=false

  # Try extracting from .env safely (do not 'source' the file)
  if [ -f "$ENV_FILE" ]; then
    # Grab the first matching line; allow quoted or unquoted value
    # This will not execute code (safe)
    # Works for lines like: RCLONE_TOKEN_JSON='{"access_token": ... }'
    env_line="$(grep -m1 '^RCLONE_TOKEN_JSON=' "$ENV_FILE" || true)"
    if [ -n "$env_line" ]; then
      # Remove KEY= prefix
      # preserve any quotes inside value
      TOKEN_JSON="${env_line#RCLONE_TOKEN_JSON=}"
      # Remove surrounding single or double quotes if present
      if [[ "$TOKEN_JSON" =~ ^\'(.*)\'$ ]]; then
        TOKEN_JSON="${BASH_REMATCH[1]}"
      elif [[ "$TOKEN_JSON" =~ ^\"(.*)\"$ ]]; then
        TOKEN_JSON="${BASH_REMATCH[1]}"
      fi

      # If TOKEN_JSON looks non-empty after stripping, accept it
      if [ -n "$TOKEN_JSON" ]; then
        FOUND_IN_ENV=true
      fi
    fi
  fi

  if [ "$FOUND_IN_ENV" = true ]; then
    echo ">>> Using token from $ENV_FILE (RCLONE_TOKEN_JSON)."
    write_config "$TOKEN_JSON"
    exit 0
  fi

  # If not found in .env, instruct local user and accept multi-line paste
  cat <<'INSTR'
>>> Token not found in .env variable 'RCLONE_TOKEN_JSON'.
INSTRUCTIONS FOR REMOTE AUTHENTICATION:
1) On your local machine, run:
     rclone authorize "drive"
   This will print a JSON object to stdout (starts with {"access_token": ... }).
2) Copy the entire JSON output.
3) In this terminal, paste the JSON and then press Ctrl-D (EOF) to submit.
INSTR

  echo
  echo ">>> Paste the JSON now, then press Ctrl-D when finished:"
  # read until EOF (supports multi-line)
  MANUAL_TOKEN="$(cat)"

  if [ -z "$MANUAL_TOKEN" ]; then
    die "No token provided. Aborting."
  fi

  write_config "$MANUAL_TOKEN"
  exit 0
fi

echo "Invalid option." >&2
exit 1

