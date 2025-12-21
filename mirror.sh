#!/bin/sh
set -eu

. /usr/local/bin/notify.sh

NOW="$(date '+%Y-%m-%d %H:%M:%S')"
TMP_DUMPS="/dumps"
BUCKET="${S3_BUCKET:?S3_BUCKET not set}"
ENDPOINT="${S3_ENDPOINT:?S3_ENDPOINT not set}"

log() {
  echo "[$NOW] $*"
}

rclone_base() {
  echo "--s3-endpoint $ENDPOINT --s3-no-check-bucket --checksum"
}

mkdir -p "$TMP_DUMPS"

FAILED=0

# =========================
# Iterate services
# =========================
for svc in $(echo "$SERVICES" | tr "," " "); do
  log "Processing service: $svc"

  SPEC_VAR="SERVICE_$svc"
  SPEC="$(eval echo "\$$SPEC_VAR")"

  [ -n "$SPEC" ] || {
    log "ERROR: $SPEC_VAR is empty or not defined"
    FAILED=1
    continue
  }

  PATHS=""
  PG_HOST=""
  PG_USER=""
  PG_DB=""
  MYSQL_HOST=""
  MYSQL_USER=""
  MYSQL_PASSWORD=""
  MYSQL_DB=""

while IFS= read -r line; do
  [ -z "$line" ] && continue
  key="${line%%=*}"
  val="${line#*=}"

  case "$key" in
    paths)
      PATHS="$val"
      ;;
    pg)
      PG_HOST="${val%%:*}"
      REST="${val#*:}"
      PG_USER="${REST%%@*}"
      PG_DB="${REST#*@}"
      ;;
    mysql)
      MYSQL_HOST="${val%%:*}"
      REST="${val#*:}"
      MYSQL_USER="${REST%%:*}"
      MYSQL_PASSWORD="${REST#*:}"
      MYSQL_DB="${MYSQL_PASSWORD#*@}"
      MYSQL_PASSWORD="${MYSQL_PASSWORD%@*}"
      ;;
  esac
done <<EOF
$SPEC
EOF

  SERVICE_PREFIX="$BUCKET/$svc"

  # =====================
  # Volume mirror
  # =====================
  if [ -n "$PATHS" ]; then
    for path in $PATHS; do
      log "Mirroring volume path $path"
      rclone sync \
        "$path" \
        "s3:$SERVICE_PREFIX/data" \
        $(rclone_base) || FAILED=1
    done
  fi

  # =====================
  # PostgreSQL dump
  # =====================
  if [ -n "$PG_HOST" ]; then
    log "Dumping PostgreSQL for $svc"
    DUMP="$TMP_DUMPS/$svc-postgres.sql.gz"

    if pg_dump -h "$PG_HOST" -U "$PG_USER" "$PG_DB" \
      | gzip > "$DUMP"; then
      rclone copy \
        "$DUMP" \
        "s3:$SERVICE_PREFIX/dumps" \
        $(rclone_base) || FAILED=1
      rm -f "$DUMP"
    else
      log "WARNING: PostgreSQL dump failed for $svc"
      FAILED=1
    fi
  fi

  # =====================
  # MySQL dump
  # =====================
  if [ -n "$MYSQL_HOST" ]; then
    log "Dumping MySQL for $svc"
    DUMP="$TMP_DUMPS/$svc-mysql.sql.gz"

    if mysqldump \
      -h "$MYSQL_HOST" \
      -u "$MYSQL_USER" \
      -p"$MYSQL_PASSWORD" \
      "$MYSQL_DB" \
      | gzip > "$DUMP"; then
      rclone copy \
        "$DUMP" \
        "s3:$SERVICE_PREFIX/dumps" \
        $(rclone_base) || FAILED=1
      rm -f "$DUMP"
    else
      log "WARNING: MySQL dump failed for $svc"
      FAILED=1
    fi
  fi
done

# =========================
# Final status
# =========================
if [ "$FAILED" -eq 0 ]; then
  log "Mirror completed successfully"
  notify "${MESSAGE_OK:-✅ Mirror completed}" info
else
  log "Mirror completed with errors"
  notify "${MESSAGE_KO:-❌ Mirror failed}" error
  exit 1
fi