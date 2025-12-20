#!/bin/sh
set -e

: "${CRON_SCHEDULE:=0 2 * * *}"

echo "$CRON_SCHEDULE /usr/local/bin/backup.sh >> /var/log/backup.log 2>&1" \
  > /etc/crontabs/root

exec crond -f