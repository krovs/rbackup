#!/bin/sh
set -e

# ==============================
# Required Environment Variables
# ==============================
# VOLUMES           - Comma-separated list of Docker volume names
# RSYNC_USER        - SSH user for NAS
# RSYNC_IP          - NAS IP address
# RSYNC_PATH        - Destination path on NAS
# RETENTION_DAYS    - Delete backups older than N days (0 = disabled)
# RETENTION_COUNT   - Keep only the last N backups per volume (0 = disabled)
# CRON_SCHEDULE     - Cron expression (e.g. "0 2 * * *")
# HEADER            - Notification title
# MESSAGE_OK        - Success message
# MESSAGE_KO        - Failure message
# NOTIFICATION_URL  - Apprise endpoint
# NOTIFICATION_TAGS - Tags for notification

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
        cleanup_old_backups
    else
        MESSAGE=$MESSAGE_KO
        echo "[$(date)] ERROR: Failed to transfer backup to NAS."
    fi

    echo "[$(date)] Cleaning up temporary backup directory: $BACKUP_DIR"
    rm -rf $BACKUP_DIR

    echo "[$(date)] Sending notification..."
    curl -s -X POST \
        -F "title=$HEADER" \
        -F "body=$MESSAGE" \
        -F "tags=$NOTIFICATION_TAGS" \
        $NOTIFICATION_URL >/dev/null 2>&1

    echo "[$(date)] Notification sent: $MESSAGE"
}

cleanup_old_backups() {
    echo "[$(date)] Starting retention cleanup on NAS..."

    # Time-based cleanup
    if [ "$RETENTION_DAYS" -gt 0 ]; then
        echo "[$(date)] Removing backups older than $RETENTION_DAYS days..."
        ssh -i $SSH_KEY -o StrictHostKeyChecking=no $RSYNC_USER@$RSYNC_IP \
            "find '$RSYNC_PATH' -type f -name '*.tar.gz' -mtime +$RETENTION_DAYS -delete"
    fi

    # Count-based cleanup
    if [ -n "$RETENTION_COUNT" ] && [ "$RETENTION_COUNT" -gt 0 ] 2>/dev/null; then
        echo "[$(date)] Keeping only the latest $RETENTION_COUNT backups per volume..."
        ssh -i $SSH_KEY -o StrictHostKeyChecking=no $RSYNC_USER@$RSYNC_IP "
            for vol in \$(ls '$RSYNC_PATH' | sed 's/_.*//g' | sort -u); do
                ls -1t '$RSYNC_PATH'/\${vol}_*.tar.gz 2>/dev/null | \
                tail -n +$((RETENTION_COUNT+1)) | xargs -r rm --
            done
        "
    fi

    echo "[$(date)] Retention cleanup completed."
}

# ==============================
# Run Backup
# ==============================
echo "[$(date)] Performing backup..."
perform_backup