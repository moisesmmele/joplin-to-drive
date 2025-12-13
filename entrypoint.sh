#!/bin/bash
set -e

# JOPLIN-TO-DRIVE ENTRYPOINT SCRIPT v1.2

#check if cron file is mounted
if [ -f /scripts/joplin-cron ]; then

	# copy the cron file to the cron daemon directory
	cp /scripts/joplin-cron /etc/cron.d/joplin-cron

	# ensure appropriate permissions
	chmod 0644 /etc/cron.d/joplin-cron
fi

# Ensure permissions for the appuser on config directories
chown -R appuser:appuser /config /export /home/appuser

# dump env vars and append to /etc/env (so it can be accessed by cron)
printenv | grep -v "no_proxy" > /etc/environment

# check for command arguments and start cron
if [ "\$#" -eq 0 ]; then
    echo "Starting cron..."
    exec cron -f
else
    exec "\$@"
fi
