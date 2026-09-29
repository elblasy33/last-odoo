# 🚀 Odoo Multi-Instance Installer (v16–v20) — AI-Ready
### Powered by [elblasy.app](https://elblasy.app) — Modern Cloud & DevOps Solutions

[![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04%20|%2022.04%20|%2024.04-E95420.svg?style=for-the-badge&logo=ubuntu&logoColor=white)](https://ubuntu.com)
[![Docker](https://img.shields.io/badge/Docker-Compose%20V2-2496ED.svg?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-17%20%2B%20pgvector-336791.svg?style=for-the-badge&logo=postgresql&logoColor=white)](https://github.com/pgvector/pgvector)
[![Odoo](https://img.shields.io/badge/Odoo-v16%20|%20v17%20|%20v18%20|%20v19%20|%20v20-714B67.svg?style=for-the-badge&logo=odoo&logoColor=white)](https://www.odoo.com)
[![License](https://img.shields.io/badge/License-MIT-22C55E.svg?style=for-the-badge)](LICENSE)

---

## Overview

A **production-grade, one-command installer** that deploys fully isolated Odoo instances on any Ubuntu / Debian server. Each instance gets its own PostgreSQL 17 database with **pgvector** pre-installed (for AI Agents, RAG, and semantic search), its own ports, directory structure, credentials, and Docker Compose stack — all automatically detected and conflict-free.

Run the script multiple times to create as many isolated instances as you need on the same server, with zero port or data conflicts.

---

## Quick Install (One-Line)

```bash
curl -fsSL https://raw.githubusercontent.com/elblasy33/last-odoo/main/install.sh | sudo bash
```

Or clone and run locally:
```bash
git clone https://github.com/elblasy33/last-odoo.git
cd last-odoo
sudo bash install.sh
```

---

## What It Does

1. **Detects your OS** — validates Ubuntu / Debian compatibility
2. **Installs Docker Engine + Compose V2** — if not already present
3. **Interactive Version Selector** — choose Odoo 16, 17, 18, 19, or 20
4. **Smart Port Hunter** — automatically finds free ports for HTTP (8069+), longpolling (8072+), and PostgreSQL (5432+)
5. **Creates the instance directory structure** — standard Odoo Enterprise layout under `/opt/elblasy-odoo/instances/`
6. **Generates all configuration files** — `odoo.conf`, `.env`, `docker-compose.yml`, and the pgvector SQL init script
7. **Pulls Docker images** and starts the isolated stack
8. **Health checks** — waits for PostgreSQL readiness and pgvector extension activation, then probes Odoo HTTP
9. **Installs the `elblasy` CLI** — system-wide management tool for all instances

---

## Supported Odoo Versions

| Version | Docker Hub Image | Status |
|---------|-----------------|--------|
| Odoo 18 | `odoo:18` | ✅ Official — Recommended |
| Odoo 17 | `odoo:17` | ✅ Official — LTS |
| Odoo 16 | `odoo:16` | ✅ Official — LTS |
| Odoo 19 | *(no official image yet)* | ⚠️ Fallback to `odoo:17` |
| Odoo 20 | *(no official image yet)* | ⚠️ Uses local build if found |

> **Odoo 19 & 20**: No official Docker Hub images exist yet. The installer will use a locally built image if found (e.g. `odoo:20`, `odoo20-odoo20:latest`), otherwise falls back to `odoo:17`. Update `ODOO_IMAGE` in `.env` once official images are released.

---

## Directory Structure

Each instance is fully isolated under `/opt/elblasy-odoo/instances/<name>/`:

```text
/opt/elblasy-odoo/
└── instances/
    └── odoo18-1/                          ← instance root
        ├── etc/
        │   ├── odoo.conf                  ← Odoo config → /etc/odoo/odoo.conf (read-only)
        │   └── addons/
        │       └── 18.0/                  ← your custom modules go here
        │           └── my_module/         ← → /mnt/extra-addons/18.0/ inside container
        ├── data/                          ← /var/lib/odoo (filestore, sessions, addons cache)
        ├── db_data/                       ← PostgreSQL 17 pgdata
        ├── backups/                       ← automated & manual backups
        ├── init-db/
        │   └── 01-pgvector-init.sql       ← runs once on first DB start
        ├── docker-compose.yml
        └── .env                           ← credentials & port config (chmod 600)
```

### Why `etc/addons/<version>/`?

This mirrors the **Odoo Enterprise standard** where custom addons are organized by version number. The version subfolder (e.g., `18.0/`) is mounted directly into the container at `/mnt/extra-addons/18.0/` and added to `addons_path` in `odoo.conf`. This means:

- Clean separation between core Odoo addons and your custom modules
- Easy version management when upgrading
- Compatible with Odoo's internal module scanning logic

---

## Volume Mapping

| Host path | Container path | Purpose |
|-----------|---------------|---------|
| `./etc/odoo.conf` | `/etc/odoo/odoo.conf` (ro) | Main config |
| `./etc/addons/18.0/` | `/mnt/extra-addons/18.0/` | Custom modules |
| `./data/` | `/var/lib/odoo` | Filestore, sessions, addons cache |
| `./db_data/` | `/var/lib/postgresql/data` | PostgreSQL data files |
| `./init-db/` | `/docker-entrypoint-initdb.d/` (ro) | First-run SQL scripts |

---

## AI-Ready: PostgreSQL 17 + pgvector

Every instance uses `pgvector/pgvector:pg17` instead of the standard Postgres image. On first startup, the init script automatically enables:

```sql
CREATE EXTENSION IF NOT EXISTS vector;    -- AI vector embeddings & similarity search
CREATE EXTENSION IF NOT EXISTS unaccent;  -- text normalization
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pg_trgm;   -- trigram similarity
```

These extensions are installed on **both** `postgres` and `template1`, so every new database Odoo creates automatically inherits them — enabling Odoo 17/18/20 AI Agents, RAG (Retrieval-Augmented Generation), and semantic search out of the box.

---

## Hardware Auto-Tuning

The installer detects your server's RAM and CPU count and automatically tunes:

| RAM | `shared_buffers` | `effective_cache_size` | Workers |
|-----|-----------------|----------------------|---------|
| < 2 GB | 256 MB | 768 MB | 2 |
| 2–4 GB | 512 MB | 1.5 GB | 3 |
| 4–8 GB | 1 GB | 3 GB | 5 |
| > 8 GB | 2 GB | 6 GB | `(nproc × 2) + 1` |

---

## elblasy CLI — Instance Management

The installer installs a system-wide CLI at `/usr/local/bin/elblasy`:

```bash
# List all instances (status, ports, version, image)
elblasy list

# Show running containers
elblasy ps

# Start / stop / restart
elblasy start  odoo18-1
elblasy stop   odoo18-1
elblasy restart odoo18-1

# Follow live logs
elblasy logs odoo18-1

# Show credentials & access URLs
elblasy info odoo18-1

# Create a full backup (DB dump + filestore tarball)
elblasy backup odoo18-1

# Permanently delete instance and all its data
elblasy delete odoo18-1
```

---

## Adding Custom Modules

1. Drop your module folder into the instance's addons directory:
   ```bash
   cp -r my_module /opt/elblasy-odoo/instances/odoo18-1/etc/addons/18.0/
   ```

2. Update the apps list in Odoo, or restart and update via CLI:
   ```bash
   docker exec odoo_odoo18-1 odoo -u my_module -d mydb --stop-after-init
   ```

---

## Security

- PostgreSQL password: generated with `openssl rand -hex 20` (40 hex chars)
- Odoo master password: generated with `openssl rand -base64 18` (20 alphanumeric chars)
- `.env` file: `chmod 600` (owner read-only)
- `odoo.conf`: `chmod 644`
- Database port: bound to `127.0.0.1` only — not publicly accessible
- Backups directory: `chmod 700`

---

## Support & Contributing

Developed with ❤️ by the [elblasy.app](https://elblasy.app) team.

- **Website**: [https://elblasy.app](https://elblasy.app)
- **Issues & PRs**: [GitHub](https://github.com/elblasy33/last-odoo/issues)
- **License**: [MIT](LICENSE)
