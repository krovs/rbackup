FROM alpine:3.22

RUN apk add --no-cache \
  restic \
  postgresql-client \
  mysql-client \
  curl \
  bash \
  tzdata

COPY backup.sh /usr/local/bin/backup.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/*.sh

ENTRYPOINT ["sh", "/usr/local/bin/entrypoint.sh"]