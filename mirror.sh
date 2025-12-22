#!/bin/sh
set -eu

. /usr/local/bin/notify.sh

TMP_DUMPS="/dumps"
FAILED_FILE="/tmp/mirror_failed"

S3_ENDPOINT="${S3_ENDPOINT:?S3_ENDPOINT not set}"
S3_BUCKET="${S3_BUCKET:?S3_BUCKET not set}"
S3_REGION="${S3_REGION:?S3_REGION not set}"
SERVICES="${SERVICES:?SERVICES not set}"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

mark_failed() {
  echo 1 > "$FAILED_FILE"
}

is_failed() {
  [ -f "$FAILED_FILE" ]
}

rclone_sync() {
  rclone sync "$1" "$2" \
    --s3-env-auth \
    --s3-provider Other \
    --s3-endpoint "$S3_ENDPOINT" \
    --s3-region "$S3_REGION" \
    --s3-force-path-style \
    --s3-disable-checksum \
    --s3-no-check-bucket
}

rclone_copy() {
  rclone copy "$1" "$2" \
    --s3-env-auth \
    --s3-provider Other \
    --s3-endpoint "$S3_ENDPOINT" \
    --s3-region "$S3_REGION" \
    --s3-force-path-style \
    --s3-disable-checksum \
    --s3-no-check-bucket
}

mkdir -p "$TMP_DUMPS"
rm -f "$FAILED_FILE"

for svc in $(echo "$SERVICES" | tr "," " "); do
  log "Processing service: $svc"

  SPEC_VAR="SERVICE_$svc"
  SPEC="$(eval echo "\$$SPEC_VAR")"

  if [ -z "$SPEC" ]; then
    log "ERROR: $SPEC_VAR is not defined"
    mark_failed
    continue
  fi

  NORMALIZED_SPEC="$(printf '%s\n' "$SPEC" | tr ' ' '\n')"

  PATHS=""
  PG_HOST="" PG_USER="" PG_DB="" PG_PASSWORD=""
  MYSQL_HOST="" MYSQL_USER="" MYSQL_PASSWORD="" MYSQL_DB=""

  while IFS= read -r line; do
    [ -z "$line" ] && continue
    key="${line%%=*}"
    val="${line#*=}"

    case "$key" in
      paths) PATHS="$val" ;;
      pg)
        PG_HOST="${val%%:*}"; REST="${val#*:}"
        PG_USER="${REST%%@*}"; REST="${REST#*@}"
        PG_DB="${REST%%:*}"
        echo "$REST" | grep -q ":" && PG_PASSWORD="${REST#*:}"
        ;;
      mysql)
        MYSQL_HOST="${val%%:*}"; REST="${val#*:}"
        MYSQL_USER="${REST%%:*}"; REST="${REST#*:}"
        MYSQL_PASSWORD="${REST%%@*}"
        MYSQL_DB="${REST#*@}"
        ;;
    esac
  done <<EOF
$NORMALIZED_SPEC
EOF

  case "$PATHS" in *"="*)
    log "ERROR: malformed paths for service $svc: $PATHS"
    mark_failed
    continue
    ;;
  esac

  if [ -z "$PATHS" ] && [ -z "$PG_HOST" ] && [ -z "$MYSQL_HOST" ]; then
    log "WARNING: service $svc has no paths or databases defined"
    continue
  fi

  # Volume mirror
  if [ -n "$PATHS" ]; then
    echo "$PATHS" | while IFS= read -r path; do
      [ -z "$path" ] && continue
      log "Mirroring volume path $path"
      if ! rclone_sync "$path" ":s3:$S3_BUCKET/$svc/data/"; then
        log "ERROR: rclone sync failed for $path"
        mark_failed
      fi
    done
  fi

  # PostgreSQL dump
  if [ -n "$PG_HOST" ]; then
    log "Dumping PostgreSQL for $svc"
    DUMP="$TMP_DUMPS/$svc-postgres.sql.gz"
    if PGPASSWORD="$PG_PASSWORD" pg_dump -h "$PG_HOST" -U "$PG_USER" "$PG_DB" \
       | gzip > "$DUMP"; then
      if ! rclone_copy "$DUMP" ":s3:$S3_BUCKET/$svc/dumps/"; then
        log "ERROR: rclone copy failed for PostgreSQL dump"
        mark_failed
      fi
      rm -f "$DUMP"
    else
      log "ERROR: PostgreSQL dump failed for $svc"
      mark_failed
    fi
  fi

  # MySQL dump
  if [ -n "$MYSQL_HOST" ]; then
    log "Dumping MySQL for $svc"
    DUMP="$TMP_DUMPS/$svc-mysql.sql.gz"
    if mysqldump -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" \
       "$MYSQL_DB" 2>/dev/null | gzip > "$DUMP"; then
      if ! rclone_copy "$DUMP" ":s3:$S3_BUCKET/$svc/dumps/"; then
        log "ERROR: rclone copy failed for MySQL dump"
        mark_failed
      fi
      rm -f "$DUMP"
    else
      log "ERROR: MySQL dump failed for $svc"
      mark_failed
    fi
  fi
done

if is_failed; then
  log "Mirror completed with errors"
  notify "${MESSAGE_KO:-❌ Mirror failed}" error
  exit 1
else
  log "Mirror completed successfully"
  notify "${MESSAGE_OK:-✅ Mirror completed}" info
fi