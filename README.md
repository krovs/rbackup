# 🐳 rbackup — Multi‑Service Docker Backups with Restic

`rbackup` is a Dockerized backup service that uses **restic** to back up
explicitly mounted Docker volumes and optional database dumps to an
**S3‑compatible backend** (Garage, MinIO, AWS S3, etc.).

It supports **multiple services per container**, creates **one restic snapshot
per service**, and provides notifications via **Apprise, ntfy, or Telegram**.

✅ No Docker socket  
✅ No host volume scanning  
✅ Encrypted, deduplicated, push‑based backups  

---

## 🚀 Features

- Backup selected Docker volumes (read‑only mounts)
- Multi‑service support (one snapshot per service)
- Per‑service restic tags
- Optional PostgreSQL and MySQL dumps (per service)
- Encrypted, deduplicated backups via **restic**
- S3‑compatible storage (Garage, MinIO, AWS S3)
- Built‑in cron scheduler
- Notifications:
  - Apprise
  - ntfy
  - Telegram
- Multi‑arch image (`amd64`, `arm64`)

---

## 🧠 How It Works

```terminal
02:00
├─ For each service
│   ├─ Dump database (optional)
│   ├─ Restic snapshot (paths + dumps)
│   └─ Apply service tags
├─ Retention pruning
└─ Send notification
```

Each service gets its **own restic snapshot**, tagged for clean restores and
independent retention policies.

---

## 📦 Usage (Docker Compose)

### ✅ Full multi‑service example

```yaml
services:
  backup:
    container_name: rbackup
    image: ghcr.io/krovs/rbackup:latest
    restart: unless-stopped

    environment:
      CRON_SCHEDULE: "0 2 * * *"

      RESTIC_REPOSITORY: "s3:http://garage:3900/backups/server1"
      RESTIC_PASSWORD: "super-secret-password"

      AWS_ACCESS_KEY_ID: "GKxxxxxxxx"
      AWS_SECRET_ACCESS_KEY: "xxxxxxxxxxxxxxxx"
      AWS_DEFAULT_REGION: "garage"

      KEEP_DAILY: "7"
      KEEP_WEEKLY: "4"
      KEEP_MONTHLY: "6"

      SERVICES: "forgejo,nextcloud"

      SERVICE_forgejo_PATHS: "/data/forgejo"
      SERVICE_forgejo_TAGS: "forgejo,git"
      SERVICE_forgejo_PG_SERVICE: "postgres"
      SERVICE_forgejo_PG_USER: "postgres"
      SERVICE_forgejo_PG_DATABASE: "forgejo"

      SERVICE_nextcloud_PATHS: "/data/nextcloud"
      SERVICE_nextcloud_TAGS: "nextcloud"
      SERVICE_nextcloud_MYSQL_SERVICE: "mysql"
      SERVICE_nextcloud_MYSQL_USER: "root"
      SERVICE_nextcloud_MYSQL_PASSWORD: "example"
      SERVICE_nextcloud_MYSQL_DATABASE: "nextcloud"

      HEADER: "🍓 Nightly backup"
      MESSAGE_OK: "✅ Backup successful!"
      MESSAGE_KO: "❌ Backup failed!"

      NOTIFICATION_TYPE: "apprise,ntfy,telegram"
      NOTIFICATION_URL: "http://apprise.lab/notify/xxxx"
      NOTIFICATION_TAGS: "backups"
      NTFY_TOKEN: "ntfy-token"
      TELEGRAM_CHAT_ID: "123456789"
      TELEGRAM_API_URL: "https://api.telegram.org/bot<TOKEN>/sendMessage"

    volumes:
      - forgejo-data:/data/forgejo:ro
      - nextcloud-data:/data/nextcloud:ro
      - backup-dumps:/dumps

volumes:
  forgejo-data:
  nextcloud-data:
  backup-dumps:
```

## 🔄 Restore Examples

```bash
restic snapshots --tag forgejo
restic restore latest --tag forgejo --target ./restore
```
