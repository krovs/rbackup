# Use a lightweight base image
FROM alpine:3.22

# Set environment variables
ENV BACKUP_SCRIPT=/usr/local/bin/backup.sh
ENV SSH_DIR=/root/.ssh

# Install required packages
RUN apk add --no-cache rsync openssh-client curl bash

# Create necessary directories
RUN mkdir -p $SSH_DIR /tmp/docker_volumes_backup

# Copy the backup script and entrypoint script into the container
COPY backup.sh $BACKUP_SCRIPT
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

# Set permissions for the scripts
RUN chmod +x $BACKUP_SCRIPT /usr/local/bin/entrypoint.sh

# Set the entrypoint to the entrypoint script
ENTRYPOINT ["sh", "/usr/local/bin/entrypoint.sh"]