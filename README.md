# 🐳 Docker Volume Backup

A simple Dockerized script to back up Docker volumes to a NAS via `rsync`,  
with **cron scheduling**, **retention policy**, and **Apprise notifications**.

---

## 🚀 Features

- Backup multiple Docker volumes (`tar.gz` archives)  
- Transfer to NAS over SSH (`rsync`) using a private key
- Retention policy:
  - `RETENTION_DAYS` → delete backups older than N days  
  - `RETENTION_COUNT` → keep only the last N backups per volume  
- Notifications via [Apprise](https://github.com/caronc/apprise)  
- Built-in **cron scheduler** (`CRON_SCHEDULE`)  

---

## 📦 Usage (Docker Compose)

```yaml
services:
  backup:
    image: ghcr.io/krovs/docker-backup:latest
    environment:
      - VOLUMES=nextcloud_data,postgres_data
      - RSYNC_USER=rsync_user
      - RSYNC_IP=192.168.1.234
      - RSYNC_PATH=/volume/Backups/docker
      - RETENTION_DAYS=7
      - RETENTION_COUNT=5
      - CRON_SCHEDULE=0 2 * * *
      - HEADER=🍓 Nightly volumes backup
      - MESSAGE_OK=✅ Backup successful!
      - MESSAGE_KO=❌ Backup failed!
      - NOTIFICATION_URL=http://apprise.lab/notify/xxxx
      - NOTIFICATION_TAGS=backups
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
| `RETENTION_DAYS`    | Delete backups older than N days (0 = disabled) |
| `RETENTION_COUNT`   | Keep only the last N backups per volume (0 = disabled) |
| `CRON_SCHEDULE`     | Cron expression (default: `0 2 * * *`) |
| `HEADER`            | Notification title |
| `MESSAGE_OK`        | Success message |
| `MESSAGE_KO`        | Failure message |
| `NOTIFICATION_URL`  | Apprise endpoint |
| `NOTIFICATION_TAGS` | Tags for notification |

---
