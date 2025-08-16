#!/bin/sh

# Write the cron job
echo "[$(date)] Writing cron job: $CRON_SCHEDULE /usr/local/bin/backup.sh"
echo "$CRON_SCHEDULE /usr/local/bin/backup.sh" > /etc/crontabs/root

# Start cron in the foreground
echo "[$(date)] Starting cron daemon..."
crond -f