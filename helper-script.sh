#!/bin/bash

echo "This script must run on a machine with a Graphical User Interface."

# 1. Check/Install Rclone
if ! command -v rclone &> /dev/null; then
    echo "Rclone not found. Installing..."
    # Note: This requires sudo/root on Linux/Mac
    curl https://rclone.org/install.sh | sudo bash
else
    echo "Rclone is already installed."
fi

# 2. Authorize and Capture
echo "Opening browser for Google Drive authentication..."
echo "Please log in."

# 'drive' is the rclone internal name for Google Drive
# This command captures the JSON token string
TOKEN_JSON=$(rclone authorize "drive" | tail -n 1)

# 3. Format output for the user
echo "------------------------------------------------"
echo "SUCCESS! Copy the line below into your .env file:"
echo ""
echo "RCLONE_AUTH_TOKEN='$TOKEN_JSON'"
echo "------------------------------------------------"
