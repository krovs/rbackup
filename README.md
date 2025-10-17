# 🐳 Docker Volume Backup

A simple Dockerized script to back up Docker volumes to a NAS via `rsync`,  
with **cron scheduling** and **Apprise, Telegram or NTFY notifications**.

I use it with my Synology NAS using a rsync user with private key.
For retention policy, I use a Synology job to keep only the latest 3 backups.

---

## 🚀 Features

- Backup multiple Docker volumes (`tar.gz` archives)  
- Transfer to NAS over SSH (`rsync`) using a private key
- Notifications via [Apprise](https://github.com/caronc/apprise), [ntfy](https://ntfy.sh/), or Telegram  
- Built-in **cron scheduler** (`CRON_SCHEDULE`)  

---

## 📦 Usage (Docker Compose)

```yaml
services:
  backup:
    container_name: rbackup
    image: ghcr.io/krovs/rbackup:latest
    environment:
      - VOLUMES=nextcloud_data,postgres_data
      - RSYNC_USER=rsync_user
      - RSYNC_IP=192.168.1.234
      - RSYNC_PATH=/volume/Backups/docker
      - CRON_SCHEDULE=0 2 * * *
      - HEADER=🍓 Nightly volumes backup
      - MESSAGE_OK=✅ Backup successful!
      - MESSAGE_KO=❌ Backup failed!
      - NOTIFICATION_TYPE=apprise,ntfy,telegram
      - NOTIFICATION_URL=http://apprise.lab/notify/xxxx
      - NOTIFICATION_TAGS=backups
      - TELEGRAM_CHAT_ID=123456789
      - TELEGRAM_API_URL=https://api.telegram.org/bot<token>/sendMessage
      - NTFY_TOKEN=9asd6f69
    volumes:
      - /var/lib/docker/volumes:/var/lib/docker/volumes:ro
      - ./id_rsa:/root/.ssh/id_rsa:ro
```

---

## ⚙️ Environment Variables

| Variable            | Description |
|---------------------|-------------|
| `VOLUMES`           | Comma-separated list of volumes |
| `RSYNC_USER`        | SSH user for NAS |
| `RSYNC_IP`          | NAS IP address |
| `RSYNC_PATH`        | Destination path on NAS |
| `CRON_SCHEDULE`     | Cron expression (default: `0 2 * * *`) |
| `HEADER`            | Notification title |
| `MESSAGE_OK`        | Success message |
| `MESSAGE_KO`        | Failure message |
| `NOTIFICATION_TYPE` | Notification methods (comma-separated: `apprise`, `ntfy`, `telegram`) |
| `NOTIFICATION_URL`  | Apprise or ntfy endpoint |
| `NOTIFICATION_TAGS` | Tags for notification (ntfy or Apprise) |
| `TELEGRAM_CHAT_ID`  | Chat ID for Telegram notifications |
| `TELEGRAM_API_URL`  | Telegram Bot API URL |
| `NTFY_TOKEN`        | NTFY token for auth |

---

## 🚧 WIP

- [ ] Add support for retention policy
