# Changelog

Breaking changes are listed first in each entry.

## 0.14.6 (2026-11-17)

- First release of this template: Sequin `v0.14.6` (`sequin/sequin:v0.14.6@sha256:336759c1c632ebdc87939bcea70b26b46df6593e666088e1bf29058209437d3e`), Railway Postgres 18 (started with `wal_level=logical`) and Railway Redis (append-only file on).
- The start script creates the first admin from `SEQUIN_ADMIN_EMAIL` / `SEQUIN_ADMIN_PASSWORD`, turns off Sequin's built-in default user and open sign-up, and enables the origin check.
