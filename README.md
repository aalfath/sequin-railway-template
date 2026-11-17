[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/sequin?utm_medium=integration&utm_source=button&utm_campaign=sequin)

# Sequin on Railway

A Railway template for [Sequin](https://github.com/sequinstream/sequin), the open-source (MIT) change data capture tool that streams Postgres changes to Kafka, SQS, SNS, Redis, NATS, RabbitMQ, Elasticsearch, Typesense, Meilisearch, HTTP webhooks and more.

## What it deploys

| Service | Source | Notes |
|---|---|---|
| **Sequin** | this repo (`Dockerfile`) | `sequin/sequin:v0.14.6`, pinned by digest. Web console and management API on the public domain. Health check `/health` (checks Postgres and Redis). |
| **Postgres** | Railway Postgres | Sequin's own configuration and state: accounts, sinks, encrypted credentials, message outbox. On a volume. |
| **Redis** | Railway Redis | Sequin's runtime state and locks. On a volume, with append-only persistence. |

The Sequin container itself keeps no local state, so a redeploy or restart loses nothing.

## Variables

| Variable | Default | Why |
|---|---|---|
| `SEQUIN_ADMIN_EMAIL` | *(asked at deploy)* | Email of the first admin user. |
| `SEQUIN_ADMIN_PASSWORD` | `${{secret(24)}}` | First admin's password. Used only when the instance has no account yet. |
| `SECRET_KEY_BASE` | `${{secret(64)}}` | Signs sessions and cookies. |
| `VAULT_KEY` | `${{secret(44)}}` | Encrypts the database credentials and API keys Sequin stores. The start script turns it into the 32-byte key Sequin needs. **Never change it** after the first deploy, or stored credentials become unreadable. |
| `PG_URL` | `${{Postgres.DATABASE_URL}}` | Sequin's own database, over the private network. |
| `REDIS_URL` | `${{Redis.REDIS_URL}}` | Sequin's Redis, over the private network. |
| `SERVER_HOST` | `${{RAILWAY_PUBLIC_DOMAIN}}` | Public host name, used for links and the origin check. |
| `PORT` | `7376` | Port the public domain routes to. |

The start script (`railway-start.sh`) sets the rest:

- the built-in default user (`admin@sequinstream.com` with a published password) is **off**, and so is open sign-up. Invite more users from **Settings → Accounts**;
- `SERVER_CHECK_ORIGIN=true` when `SERVER_HOST` is set;
- IPv6 for a `*.railway.internal` Postgres (Railway's private network);
- `MAX_MEMORY_MB` from the container's memory limit, not the host's;
- `PG_POOL_SIZE=20`.

Each of these can be overridden by setting the variable on the service. Optional settings (telemetry opt-out `SEQUIN_TELEMETRY_DISABLED=true`, `CRASH_REPORTING_DISABLED=true`, GitHub sign-in, `CONFIG_FILE_YAML`) are in [Sequin's configuration reference](https://sequinstream.com/docs/reference/configuration).

## After deploy

1. Open the Sequin service's URL and sign in with `SEQUIN_ADMIN_EMAIL` and the value of `SEQUIN_ADMIN_PASSWORD` (Sequin service → Variables).
2. Connect the Postgres database you want to stream from. It needs `wal_level = logical`. For a Railway Postgres in the same project, set its start command to `/bin/sh -c "exec wrapper.sh postgres --port=${PGPORT} -c wal_level=logical"`, redeploy it, and connect over the private network (`*.railway.internal`, port 5432, SSL off).
3. Add a sink (Kafka, SQS, webhook, ...) and a backfill if you need existing rows.

## Updates

The Sequin service builds from this repo. When we bump the pinned version on `main`, Railway shows an "update available" notice on your project and you choose when to apply it. Sequin runs its database migrations on start. Read [CHANGELOG.md](CHANGELOG.md) before you apply an update.

## Local test

```sh
docker compose -f local-test/compose.yaml -p sequin-test up -d --build
# open http://localhost:42468 and sign in as admin@example.com / local-test-password-1
```

Sequin is licensed under the [MIT License](https://github.com/sequinstream/sequin/blob/main/LICENSE); this wrapper only adds Railway settings.
