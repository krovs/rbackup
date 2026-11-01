FROM rclone/rclone:1.75.2

RUN apk upgrade --no-cache && \
  apk add --no-cache \
  postgresql-client \
  mysql-client \
  curl \
  tzdata

COPY notify.sh /usr/local/bin/notify.sh
COPY mirror.sh /usr/local/bin/mirror.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/*.sh

ENTRYPOINT ["sh", "/usr/local/bin/entrypoint.sh"]
