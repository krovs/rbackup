FROM alpine:3.23.2

RUN apk add --no-cache \
  rclone \
  postgresql-client \
  mysql-client \
  curl \
  tzdata \
  cronie

COPY notify.sh /usr/local/bin/notify.sh
COPY mirror.sh /usr/local/bin/mirror.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/*.sh

ENTRYPOINT ["sh", "/usr/local/bin/entrypoint.sh"]