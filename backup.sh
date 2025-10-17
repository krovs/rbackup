#!/bin/sh
set -e

# ==============================
# Required Environment Variables
# ==============================
# VOLUMES           - Comma-separated list of Docker volume names
# RSYNC_USER        - SSH user for NAS
# RSYNC_IP          - NAS IP address
# RSYNC_PATH        - Destination path on NAS
# CRON_SCHEDULE     - Cron expression (e.g. "0 2 * * *")
# HEADER            - Notification title
# MESSAGE_OK        - Success message
# MESSAGE_KO        - Failure message
# NOTIFICATION_URL  - Apprise endpoint or ntfy URL
# NOTIFICATION_TAGS - Tags for notification
# NOTIFICATION_TYPE  - Notification methods (comma-separated: "apprise", "ntfy", "telegram")
# TELEGRAM_CHAT_ID   - Chat ID for Telegram notifications
# TELEGRAM_API_URL   - Telegram Bot API URL
# NTFY_TOKEN         - Token for ntfy notifications

# ==============================
# Internal Paths
# ==============================
BACKUP_DIR="/tmp/docker_volumes_backup"
DOCKER_VOLUMES_PATH="/var/lib/docker/volumes"
SSH_KEY="/tmp/id_rsa"

# ==============================
# Setup SSH Key
# ==============================
echo "[$(date)] Copying private key to writable location..."
cp /root/.ssh/id_rsa $SSH_KEY
chmod 600 $SSH_KEY

# ==============================
# Functions
# ==============================

perform_backup() {
    echo "[$(date)] Creating temporary backup directory: $BACKUP_DIR"
    mkdir -p $BACKUP_DIR

    # Iterate over specified volume names
    for VOLUME_NAME in $(echo $VOLUMES | tr "," "\n"); do
        VOLUME_PATH="$DOCKER_VOLUMES_PATH/$VOLUME_NAME/_data"

        echo "[$(date)] Processing volume: $VOLUME_NAME"
        if [ -d "$VOLUME_PATH" ]; then
            ARCHIVE_NAME="${VOLUME_NAME}_$(date +%Y%m%d_%H%M%S).tar.gz"
            echo "[$(date)] Creating archive: $ARCHIVE_NAME"

            tar -czf "$BACKUP_DIR/$ARCHIVE_NAME" -C "$VOLUME_PATH" . \
                --exclude="**/metadata.db"

            if [ $? -ne 0 ]; then
                echo "[$(date)] ERROR: Failed to create archive for $VOLUME_NAME. Skipping."
                continue
            fi

            echo "[$(date)] Archive created successfully: $ARCHIVE_NAME"
        else
            echo "[$(date)] WARNING: Volume $VOLUME_NAME does not exist at $VOLUME_PATH. Skipping."
        fi
    done

    echo "[$(date)] Transferring archives to NAS: $RSYNC_USER@$RSYNC_IP:$RSYNC_PATH"
    /usr/bin/rsync -ratlzv \
        --rsh="/usr/bin/ssh -i $SSH_KEY -o StrictHostKeyChecking=no -l $RSYNC_USER" \
        $BACKUP_DIR/ \
        $RSYNC_USER@$RSYNC_IP:$RSYNC_PATH

    if [ $? -eq 0 ]; then
        MESSAGE=$MESSAGE_OK
        echo "[$(date)] Backup successfully transferred to NAS."
    else
        MESSAGE=$MESSAGE_KO
        echo "[$(date)] ERROR: Failed to transfer backup to NAS."
    fi

    echo "[$(date)] Cleaning up temporary backup directory: $BACKUP_DIR"
    rm -rf $BACKUP_DIR

    echo "[$(date)] Sending notifications..."
    if echo "$NOTIFICATION_TYPE" | grep -q "apprise"; then
        curl -s -X POST \
            -F "title=$HEADER" \
            -F "body=$MESSAGE" \
            -F "tags=$NOTIFICATION_TAGS" \
            "$NOTIFICATION_URL" >/dev/null 2>&1
        echo "[$(date)] Apprise notification sent."
    fi

    if echo "$NOTIFICATION_TYPE" | grep -q "ntfy"; then
        curl -s -X POST \
            -H "Title: $HEADER" \
            -u ":$NTFY_TOKEN" \
            -d "$MESSAGE" \
            "$NOTIFICATION_URL/$NOTIFICATION_TAGS" >/dev/null 2>&1
        echo "[$(date)] ntfy notification sent."
    fi

    if echo "$NOTIFICATION_TYPE" | grep -q "telegram"; then
        curl -s -X POST \
            -H "Content-Type: application/json" \
            -d "{
                \"chat_id\": \"${TELEGRAM_CHAT_ID}\",
                \"parse_mode\": \"Markdown\",
                \"text\": \"*${HEADER}*\n${MESSAGE}\"
            }" \
            "$TELEGRAM_API_URL" >/dev/null 2>&1
        echo "[$(date)] Telegram notification sent."
    fi

    echo "[$(date)] Notifications completed."
}

# ==============================
# Run Backup
# ==============================
echo "[$(date)] Performing backup..."
perform_backup