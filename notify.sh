#!/bin/sh

notify() {
  MESSAGE="$1"
  LEVEL="${2:-info}"

  TITLE="${HEADER:-Backup}"
  TAGS="${NOTIFICATION_TAGS:-backup}"

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Sending notifications (level=$LEVEL)..."

  case "${NOTIFICATION_TYPE:-}" in
    *apprise*)
      curl -fsS -X POST \
        -F "title=$TITLE" \
        -F "body=$MESSAGE" \
        -F "tags=$TAGS,$LEVEL" \
        "$NOTIFICATION_URL" >/dev/null 2>&1 || true
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] Apprise notification sent."
      ;;
  esac

  case "${NOTIFICATION_TYPE:-}" in
    *ntfy*)
      curl -fsS -X POST \
        -H "Title: $TITLE" \
        -H "Tags: $LEVEL" \
        -u ":$NTFY_TOKEN" \
        -d "$MESSAGE" \
        "$NOTIFICATION_URL/$TAGS" >/dev/null 2>&1 || true
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] ntfy notification sent."
      ;;
  esac

  case "${NOTIFICATION_TYPE:-}" in
    *telegram*)
      curl -fsS -X POST \
        -H "Content-Type: application/json" \
        -d "{\"chat_id\":\"${TELEGRAM_CHAT_ID}\",\"parse_mode\":\"Markdown\",\"text\":\"*${TITLE}*\n_${LEVEL}_\n${MESSAGE}\"}" \
        "$TELEGRAM_API_URL" >/dev/null 2>&1 || true
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] Telegram notification sent."
      ;;
  esac

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Notifications completed."
}