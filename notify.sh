#!/bin/sh

notify() {
  MESSAGE="$1"
  LEVEL="${2:-info}" # info | warn | error
  NOW="$(date '+%Y-%m-%d %H:%M:%S')"

  TITLE="${HEADER:-Backup}"
  TAGS="${NOTIFICATION_TAGS:-backup}"

  echo "[$NOW] Sending notifications (level=$LEVEL)..."

  if echo "${NOTIFICATION_TYPE:-}" | grep -q "apprise"; then
    curl -fsS -X POST \
      -F "title=$TITLE" \
      -F "body=$MESSAGE" \
      -F "tags=$TAGS,$LEVEL" \
      "$NOTIFICATION_URL" >/dev/null 2>&1 || true
    echo "[$NOW] Apprise notification sent."
  fi

  if echo "${NOTIFICATION_TYPE:-}" | grep -q "ntfy"; then
    curl -fsS -X POST \
      -H "Title: $TITLE" \
      -H "Tags: $LEVEL" \
      -u ":$NTFY_TOKEN" \
      -d "$MESSAGE" \
      "$NOTIFICATION_URL/$TAGS" >/dev/null 2>&1 || true
    echo "[$NOW] ntfy notification sent."
  fi

  if echo "${NOTIFICATION_TYPE:-}" | grep -q "telegram"; then
    curl -fsS -X POST \
      -H "Content-Type: application/json" \
      -d "{
        \"chat_id\": \"${TELEGRAM_CHAT_ID}\",
        \"parse_mode\": \"Markdown\",
        \"text\": \"*${TITLE}*\n_${LEVEL}_\n${MESSAGE}\"
      }" \
      "$TELEGRAM_API_URL" >/dev/null 2>&1 || true
    echo "[$NOW] Telegram notification sent."
  fi

  echo "[$NOW] Notifications completed."
}