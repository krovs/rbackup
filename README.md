# 🐳 rbackup — VolSync‑like Mirrors for Docker (rclone mode)

`rbackup` is a Dockerized **data mirror service** inspired by
**VolSync’s rclone mover**, designed for **Docker Compose / homelabs**.

It mirrors explicitly mounted Docker volumes and optional database dumps
to an **S3‑compatible object store** (Garage, MinIO, AWS S3, etc.)
**without encryption**, relying on:

- object versioning (Garage)
- retention policies (Kopia / backend)

for safety and history.

✅ No Docker socket  
✅ No host volume scanning  
✅ Human‑readable data in S3  
✅ Declarative, per‑service configuration  

---

## 🚀 Features

- Mirror selected Docker volumes using **rclone**
- Optional PostgreSQL and MySQL database dumps
- Multi‑service support (one prefix per service)
- Browsable objects in S3 / Garage Web UI
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
│   ├─ Mirror volume paths (rclone sync)
│   ├─ Dump database (optional)
│   └─ Upload dumps (rclone copy)
└─ Send notification
```

### Important

This is a **mirror**, not a snapshot‑based backup.

Safety is provided by:

- **Garage bucket versioning**
- **Kopia retention & offsite replication**

This is **exactly how VolSync’s rclone mover works**.

---

## 📦 Usage (Docker Compose)

### ✅ Full example (mirror mode)

```yaml
services:
  rbackup:
    container_name: rbackup
    image: ghcr.io/krovs/rbackup:latest
    restart: unless-stopped

    environment:
      DEVICE_NAME: server1
      CRON_SCHEDULE: "0 2 * * *"

      # S3 / Garage
      S3_ENDPOINT: "http://garage:3900"
      S3_BUCKET: "server1-mirror"
      AWS_ACCESS_KEY_ID: "GKxxxxxxxx"
      AWS_SECRET_ACCESS_KEY: "xxxxxxxxxxxxxxxx"
      AWS_DEFAULT_REGION: "garage"

      # Services to mirror
      SERVICES: "forgejo,nextcloud"

      SERVICE_forgejo: |
        paths=/data/forgejo
        pg=forgejo-postgres:postgres@forgejo

      SERVICE_nextcloud: |
        paths=/data/nextcloud
        mysql=nextcloud-mysql:root:example@nextcloud

      # Notifications
      HEADER: "📦 Nightly mirror"
      MESSAGE_OK: "✅ Mirror completed"
      MESSAGE_KO: "❌ Mirror failed"
      NOTIFICATION_TYPE: "apprise,ntfy,telegram"
      NOTIFICATION_URL: "http://apprise.lab/notify/xxxx"
      NOTIFICATION_TAGS: "backup"
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

---

## 🗂 Resulting Layout in S3 / Garage

```
server1-mirror/
├── forgejo/
│   ├── data/
│   └── dumps/
│       └── forgejo-postgres.sql.gz
└── nextcloud/
├── data/
└── dumps/
└── nextcloud-mysql.sql.gz
```

✅ Fully browsable  
✅ Downloadable  
✅ Versioned  

---

## ⚙️ Service Specification Format

Each service is defined with **one environment variable**:

```text
SERVICE_<name>
```

Supported keys

Key	Description
paths	Space‑separated volume paths to mirror
pg	PostgreSQL dump (host:user@database)
mysql	MySQL dump (host:user:password@database)

Examples

```bash
	paths=/data/app
	pg=postgres:postgres@appdb
	mysql=mysql:root:secret@mydb
```

---

## 🔔 Notifications

Supported backends:

- Apprise

- ntfy

- Telegram

Multiple backends can be enabled at once:

```bash
NOTIFICATION_TYPE=apprise,ntfy,telegram
```

Notifications are best‑effort and never fail the mirror job.

---

## 🔄 Restore Workflow

Restore files

- Browse or download directly from Garage Web UI

- Or use rclone:

```bash
rclone copy s3:server1-mirror/forgejo ./restore
```

Restore database

```bash
gunzip < forgejo-postgres.sql.gz | psql forgejo
```

---

## 🔐 Security Model

- ❌ No encryption at mirror level
- ✅ Object versioning enabled in Garage
- ✅ Retention & offsite handled by Kopia
- ✅ Least‑privilege S3 credentials recommended
