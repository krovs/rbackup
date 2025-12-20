#!/bin/sh
set -eu

NOW="$(date '+%Y-%m-%d %H:%M:%S')"
HOST="$(hostname)"
DUMPS_ROOT="/dumps"

log() {
  echo "[$NOW] $1"
}

notify() {
  MESSAGE="$1"

  if echo "${NOTIFICATION_TYPE:-}" | grep -q "apprise"; then
    curl -fsS -X POST \
      -F "title=$HEADER" \
      -F "body=$MESSAGE" \
      -F "tags=$NOTIFICATION_TAGS" \
      "$NOTIFICATION_URL" || true
  fi

  if echo "${NOTIFICATION_TYPE:-}" | grep -q "ntfy"; then
    curl -fsS -X POST \
      -H "Title: $HEADER" \
      -u ":$NTFY_TOKEN" \
      -d "$MESSAGE" \
      "$NOTIFICATION_URL/$NOTIFICATION_TAGS" || true
  fi

  if echo "${NOTIFICATION_TYPE:-}" | grep -q "telegram"; then
    curl -fsS -X POST \
      -H "Content-Type: application/json" \
      -d "{
        \"chat_id\": \"${TELEGRAM_CHAT_ID}\",
        \"parse_mode\": \"Markdown\",
        \"text\": \"*${HEADER}*\n${MESSAGE}\"
      }" \
      "$TELEGRAM_API_URL" || true
  fi
}

# =====================
# Restic init
# =====================
if ! restic cat config >/dev/null 2>&1; then
  log "Initializing restic repository"
  restic init
fi

BACKUP_FAILED=0
DUMP_FAILED=0

# =====================
# Per-service backup
# =====================
for svc in $(echo "$SERVICES" | tr "," " "); do
  log "Processing service: $svc"

  PATHS_VAR="SERVICE_${svc}_PATHS"
  TAGS_VAR="SERVICE_${svc}_TAGS"

  PATHS="$(eval echo "\$$PATHS_VAR")"
  TAGS="$(eval echo "\$$TAGS_VAR")"

  [ -n "$PATHS" ] || {
    log "ERROR: $PATHS_VAR not set"
    BACKUP_FAILED=1
    continue
  }

  DUMPS_DIR="$DUMPS_ROOT/$svc"
  mkdir -p "$DUMPS_DIR"

  # ---------------------
  # PostgreSQL dump
  # ---------------------
  PG_SERVICE_VAR="SERVICE_${svc}_PG_SERVICE"
  PG_SERVICE="$(eval echo "\$$PG_SERVICE_VAR")"

  if [ -n "$PG_SERVICE" ]; then
    log "Dumping PostgreSQL for $svc"
    if ! pg_dump \
      -h "$PG_SERVICE" \
      -U "$(eval echo \$SERVICE_${svc}_PG_USER)" \
      "$(eval echo \$SERVICE_${svc}_PG_DATABASE)" \
      | gzip > "$DUMPS_DIR/postgres.sql.gz"; then
      log "WARNING: PostgreSQL dump failed for $svc"
      DUMP_FAILED=1
    fi
  fi

  # ---------------------
  # MySQL dump
  # ---------------------
  MYSQL_SERVICE_VAR="SERVICE_${svc}_MYSQL_SERVICE"
  MYSQL_SERVICE="$(eval echo "\$$MYSQL_SERVICE_VAR")"

  if [ -n "$MYSQL_SERVICE" ]; then
    log "Dumping MySQL for $svc"
    if ! mysqldump \
      -h "$MYSQL_SERVICE" \
      -u "$(eval echo \$SERVICE_${svc}_MYSQL_USER)" \
      -p"$(eval echo \$SERVICE_${svc}_MYSQL_PASSWORD)" \
      "$(eval echo \$SERVICE_${svc}_MYSQL_DATABASE)" \
      | gzip > "$DUMPS_DIR/mysql.sql.gz"; then
      log "WARNING: MySQL dump failed for $svc"
      DUMP_FAILED=1
    fi
  fi

  # ---------------------
  # Tags
  # ---------------------
  TAG_ARGS=""
  for tag in $(echo "$TAGS" | tr "," " "); do
    TAG_ARGS="$TAG_ARGS --tag $tag"
  done

  # ---------------------
  # Restic backup
  # ---------------------
  log "Running restic backup for $svc"
  if ! restic backup $PATHS "$DUMPS_DIR" \
    --host "$HOST" \
    $TAG_ARGS; then
    BACKUP_FAILED=1
  fi

  rm -rf "$DUMPS_DIR"
done

# =====================
# Retention
# =====================
if [ "$BACKUP_FAILED" -eq 0 ]; then
  restic forget \
    --keep-daily "${KEEP_DAILY:-7}" \
    --keep-weekly "${KEEP_WEEKLY:-4}" \
    --keep-monthly "${KEEP_MONTHLY:-6}" \
    --prune || true
fi

# =====================
# Notifications
# =====================
if [ "$BACKUP_FAILED" -eq 0 ] && [ "$DUMP_FAILED" -eq 0 ]; then
  notify "$MESSAGE_OK"
elif [ "$BACKUP_FAILED" -eq 0 ]; then
  notify "⚠️ Backup OK, but database dump failed"
else
  notify "$MESSAGE_KO"
  exit 1
fi