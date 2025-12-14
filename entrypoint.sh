#!/bin/bash
set -e

# JOPLIN-TO-DRIVE ENTRYPOINT SCRIPT v1.2

echo "[$(date)] Starting entrypoint..."

#check if cron file is mounted
if [ -f /scripts/joplin-cron ]; then

	# copy the cron file to the cron daemon directory
	cp /scripts/joplin-cron /etc/cron.d/joplin-cron

	# ensure appropriate permissions
	chmod 0644 /etc/cron.d/joplin-cron
fi

# Ensure permissions for the appuser on config directories
chown -R appuser:appuser /config /export /home/appuser

# Create a new file for log output redirect
touch /var/log/joplin-sync.log

# change log file ownership to appuser
chown appuser:appuser /var/log/joplin-sync.log

# sends log tail output to file
tail -f /var/log/joplin-sync.log &

# dump env vars and append to /etc/env (so it can be accessed by cron)
printenv | grep -v "no_proxy" > /etc/environment

# change script exec permissions
chmod +x /scripts/joplin-export.sh


# Run export once on container start
if [ -x /scripts/joplin-export.sh ]; then
    echo "[$(date)] Running initial Joplin export..."
    runuser -u appuser -- /scripts/joplin-export.sh
fi

# Start cron
echo "[$(date)] Starting cron..."
exec cron -f
