FROM alpine:3.23.2

RUN apk add --no-cache \
  restic \
  postgresql-client \
  mysql-client \
  curl \
  bash \
  tzdata \
  cronie

COPY backup.sh /usr/local/bin/backup.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/*.sh

ENTRYPOINT ["sh", "/usr/local/bin/entrypoint.sh"]