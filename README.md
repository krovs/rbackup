# rbackup

Dockerized data mirror service inspired by VolSync's rclone mover, designed for
Docker Compose and homelabs.

Mirrors explicitly mounted Docker volumes and optional database dumps to an
S3-compatible object store (Garage, MinIO, AWS S3, etc.) without encryption,
relying on object versioning and retention policies for safety.

## Features

- Mirror selected Docker volumes using rclone
- Optional PostgreSQL and MySQL database dumps
- Multi-service support (one prefix per service)
- Browsable objects in S3/Garage Web UI
- Built-in cron scheduler
- Notifications: Apprise, ntfy, Telegram
- Multi-arch image (`amd64`, `arm64`)

## How It Works

```text
02:00
├─ For each service
│   ├─ Mirror volume paths (rclone sync)
│   ├─ Dump database (optional)
│   └─ Upload dumps (rclone copy)
└─ Send notification
```

This is a **mirror**, not a snapshot-based backup. Safety is provided by bucket
versioning and external retention policies (e.g., Kopia).

## Usage

```yaml
services:
  rbackup:
    container_name: rbackup
    image: ghcr.io/krovs/rbackup:latest
    restart: unless-stopped
    environment:
      CRON_SCHEDULE: "0 2 * * *"

      S3_ENDPOINT: "http://garage:3900"
      S3_BUCKET: "server1-mirror"
      S3_REGION: "garage"
      AWS_ACCESS_KEY_ID: "GKxxxxxxxx"
      AWS_SECRET_ACCESS_KEY: "xxxxxxxxxxxxxxxx"

      SERVICES: "forgejo,nextcloud"

      SERVICE_forgejo: |
        paths=/data/forgejo
        pg=forgejo-postgres:postgres@forgejo:secret

      SERVICE_nextcloud: |
        paths=/data/nextcloud
        mysql=nextcloud-mysql:root:secret@nextcloud

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

## Resulting S3 Layout

```text
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

## Environment Variables

### Required

| Variable              | Description                          |
| --------------------- | ------------------------------------ |
| `S3_ENDPOINT`         | S3-compatible endpoint URL           |
| `S3_BUCKET`           | Target bucket name                   |
| `S3_REGION`           | S3 region (use `garage` for Garage)  |
| `AWS_ACCESS_KEY_ID`   | S3 access key                        |
| `AWS_SECRET_ACCESS_KEY` | S3 secret key                      |
| `SERVICES`            | Comma-separated list of service names |

### Optional

| Variable            | Default         | Description                      |
| ------------------- | --------------- | -------------------------------- |
| `CRON_SCHEDULE`     | `0 2 * * *`     | Cron expression for scheduling   |
| `HEADER`            | `Backup`        | Notification title               |
| `MESSAGE_OK`        | ✅ Mirror completed | Success message              |
| `MESSAGE_KO`        | ❌ Mirror failed | Failure message                 |
| `NOTIFICATION_TYPE` | —               | `apprise`, `ntfy`, `telegram`    |

## Service Specification Format

Each service is defined via `SERVICE_<name>`:

| Key     | Format                         | Description                |
| ------- | ------------------------------ | -------------------------- |
| `paths` | `/path/to/volume`              | Volume path(s) to mirror   |
| `pg`    | `host:user@database:password`  | PostgreSQL connection      |
| `mysql` | `host:user:password@database`  | MySQL connection           |

Example:

```text
SERVICE_myapp: |
  paths=/data/myapp
  pg=postgres:admin@mydb:secret
```

## Notifications

Enable multiple backends:

```bash
NOTIFICATION_TYPE=apprise,ntfy,telegram
```

Notifications are best-effort and never fail the mirror job.

## Restore

### Files

```bash
rclone copy :s3:server1-mirror/forgejo/data ./restore \
  --s3-endpoint https://s3.example.com \
  --s3-provider Other \
  --s3-force-path-style
```

### Database

```bash
gunzip < forgejo-postgres.sql.gz | psql -U postgres forgejo
```

## S3 Path-Style Access

This project uses **path-style S3 access** (`https://s3.example.com/<bucket>`)
rather than virtual-hosted style (`https://bucket.s3.example.com`).

This is required when accessing Garage (or similar) through a reverse proxy, as
virtual-hosted style causes multipart upload failures with HTTP 308 redirects.

Do not change `--s3-force-path-style` unless accessing Garage directly without a
proxy.
