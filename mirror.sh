#!/bin/sh
set -eu

. /usr/local/bin/notify.sh

NOW="$(date '+%Y-%m-%d %H:%M:%S')"
TMP_DUMPS="/dumps"

S3_ENDPOINT="${S3_ENDPOINT:?S3_ENDPOINT not set}"
S3_BUCKET="${S3_BUCKET:?S3_BUCKET not set}"
S3_REGION="${S3_REGION:?S3_REGION not set}"
SERVICES="${SERVICES:?SERVICES not set}"

log() {
  echo "[$NOW] $*"
}

# rclone flags for Garage + proxy (path-style, stable)
rclone_args() {
  echo "
    --s3-env-auth
    --s3-provider Other
    --s3-endpoint $S3_ENDPOINT
    --s3-region $S3_REGION
    --s3-force-path-style
    --s3-disable-checksum
    --s3-upload-cutoff 0
    --s3-no-check-bucket
  "
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

  if [ -z "$SPEC" ]; then
    log "ERROR: $SPEC_VAR is not defined"
    FAILED=1
    continue
  fi

  # Normalize spec (handles flattened envs)
  NORMALIZED_SPEC="$(printf '%s\n' "$SPEC" | tr ' ' '\n')"

  PATHS=""
  PG_HOST=""
  PG_USER=""
  PG_DB=""
  PG_PASSWORD=""
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
        # pg=host:user@db:password
        PG_HOST="${val%%:*}"
        REST="${val#*:}"

        PG_USER="${REST%%@*}"
        REST="${REST#*@}"

        PG_DB="${REST%%:*}"

        if echo "$REST" | grep -q ":"; then
          PG_PASSWORD="${REST#*:}"
        fi
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
$NORMALIZED_SPEC
EOF

  # Guard against malformed paths
  case "$PATHS" in
    *"="*)
      log "ERROR: malformed paths for service $svc: $PATHS"
      FAILED=1
      continue
      ;;
  esac

  if [ -z "$PATHS" ] && [ -z "$PG_HOST" ] && [ -z "$MYSQL_HOST" ]; then
    log "WARNING: service $svc has no paths or databases defined"
    continue
  fi

  # =====================
  # Volume mirror
  # =====================
  if [ -n "$PATHS" ]; then
    printf '%s\n' "$PATHS" | while IFS= read -r path; do
      [ -z "$path" ] && continue
      log "Mirroring volume path $path"

      rclone sync \
        "$path" \
        ":s3:$S3_BUCKET/$svc/data/" \
        $(rclone_args) || FAILED=1
    done
  fi

  # =====================
  # PostgreSQL dump
  # =====================
  if [ -n "$PG_HOST" ]; then
    log "Dumping PostgreSQL for $svc"
    DUMP="$TMP_DUMPS/$svc-postgres.sql.gz"

    if PGPASSWORD="$PG_PASSWORD" \
       pg_dump -h "$PG_HOST" -U "$PG_USER" "$PG_DB" | gzip > "$DUMP"; then
      rclone copy \
        "$DUMP" \
        ":s3:$S3_BUCKET/$svc/dumps/" \
        $(rclone_args) || FAILED=1
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
      "$MYSQL_DB" | gzip > "$DUMP"; then
      rclone copy \
        "$DUMP" \
        ":s3:$S3_BUCKET/$svc/dumps/" \
        $(rclone_args) || FAILED=1
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