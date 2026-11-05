#!/bin/sh

notify() {
  MESSAGE="$1"
  LEVEL="${2:-info}"

  TITLE="${HEADER:-Backup}"
  TAGS="${NOTIFICATION_TAGS:-backup}"

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Sending notifications (level=$LEVEL)..."

  case "${NOTIFICATION_TYPE:-}" in
    *apprise*)
      if curl -fsS --connect-timeout 10 --max-time 30 -X POST \
        -F "title=$TITLE" \
        -F "body=$MESSAGE" \
        -F "tags=$TAGS,$LEVEL" \
        "$NOTIFICATION_URL" >/dev/null 2>&1; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Apprise accepted the notification."
      else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Apprise notification failed." >&2
      fi
      ;;
  esac

  case "${NOTIFICATION_TYPE:-}" in
    *ntfy*)
      if curl -fsS --connect-timeout 10 --max-time 30 -X POST \
        -H "Title: $TITLE" \
        -H "Tags: $LEVEL" \
        -u ":$NTFY_TOKEN" \
        -d "$MESSAGE" \
        "$NOTIFICATION_URL/$TAGS" >/dev/null 2>&1; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ntfy accepted the notification."
      else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: ntfy notification failed." >&2
      fi
      ;;
  esac

  case "${NOTIFICATION_TYPE:-}" in
    *telegram*)
      if curl -fsS --connect-timeout 10 --max-time 30 -X POST \
        -H "Content-Type: application/json" \
        -d "{\"chat_id\":\"${TELEGRAM_CHAT_ID}\",\"parse_mode\":\"Markdown\",\"text\":\"*${TITLE}*\n_${LEVEL}_\n${MESSAGE}\"}" \
        "$TELEGRAM_API_URL" >/dev/null 2>&1; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Telegram accepted the notification."
      else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Telegram notification failed." >&2
      fi
      ;;
  esac

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Notifications completed."
}
