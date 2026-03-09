# Matrix Chat Superbridge

Bridge Discord, Telegram, Signal, and WhatsApp through Matrix so users can communicate across platforms as themselves.

## How It Works

```
Discord  ←→  mautrix-discord  ←→  Portal Room  ←→ ┐
Telegram ←→  mautrix-telegram ←→  Portal Room  ←→ ├─  Relay Bot  ←→  Hub Room (Matrix)
Signal   ←→  mautrix-signal   ←→  Portal Room  ←→ ┤
WhatsApp ←→  mautrix-whatsapp ←→  Portal Room  ←→ ┘
```

Each platform is bridged to Matrix via [mautrix](https://docs.mau.fi/) bridges. A custom **relay bot** (appservice) copies messages between portal rooms and a shared hub room using **puppet users** — so messages appear as the actual sender with their real name and avatar, not as `"**Alice (Discord):** hello"`.

### What each user sees

| You send from | Discord users see | Telegram users see | Signal users see | Matrix users see |
|---------------|-------------------|--------------------|------------------|------------------|
| Discord | Native message | Puppet with your name/avatar | Puppet with your name/avatar | Puppet with your name/avatar |
| Telegram | Webhook with your name | Native message | Puppet with your name/avatar | Puppet with your name/avatar |
| Signal | Puppet with your name/avatar | Puppet with your name/avatar | Native message | Puppet with your name/avatar |
| Element | Double puppet (as you) | Double puppet (as you) | Double puppet (as you) | Native message |

## Production Server

Running on Google Cloud (GCE e2-medium, `australia-southeast1`):

| Service | URL |
|---------|-----|
| Matrix homeserver (Continuwuity) | https://matrix.35-201-14-61.sslip.io |
| Element Web client | https://element.35-201-14-61.sslip.io |

## For Teammates: Getting Started

You don't need to install anything. The server is already running.

### 1. Log into Element

1. Open https://element.35-201-14-61.sslip.io
2. Click "Sign In"
3. The homeserver should be pre-configured. If prompted, set it to `https://matrix.35-201-14-61.sslip.io`
4. Sign in with your credentials (ask Nick)

### 2. Connect your accounts

In Element, start a DM with each bridge bot and follow the login flow:

| Platform | Bot | Login command | How to authenticate |
|----------|-----|---------------|---------------------|
| Discord | `@discordbot:35-201-14-61.sslip.io` | `login-qr` | Scan QR with Discord mobile |
| Telegram | `@telegrambot:35-201-14-61.sslip.io` | `login` | Enter phone number + verification code |
| Signal | `@signalbot:35-201-14-61.sslip.io` | `login` | Link as secondary device from Signal mobile |
| WhatsApp | `@whatsappbot:35-201-14-61.sslip.io` | `login` | Scan QR with WhatsApp mobile |

### 3. Using bridged rooms

Once connected:
- **Bridged rooms** appear in your Element room list
- **Your messages** on Matrix appear as you on all platforms (double puppeting)
- **Other people's messages** from any platform appear with their name and avatar

## Admin Guide

### Deploying

```bash
# First-time setup (provisions VPS, generates tokens, starts services)
./deploy.sh setup

# Update (copy files, rebuild, restart)
./deploy.sh deploy

# Check service health
./deploy.sh verify
```

### Creating a superbridge room

```bash
# Creates hub room, invites bridge bots, sets power levels
./superbridge.sh all

# Then follow per-platform plumbing instructions:
./superbridge.sh plumb-discord
./superbridge.sh plumb-telegram
./superbridge.sh plumb-whatsapp
```

After plumbing, configure the relay bot by setting `PORTAL_ROOMS` and `HUB_ROOM_ID` in `.env` on the VPS, registering the relay bot appservice in the admin room, and restarting.

### Registering appservices (Continuwuity)

In the admin room (`#admins:35-201-14-61.sslip.io`), send:

````
!admin appservices register

```yaml
<paste contents of registration.yaml>
```
````

### Secrets

All secrets live in `.env` on the VPS (not committed to git). See `.env.example` for the structure. SSH access: `ssh nick@35.201.14.61`.

### Infrastructure

- GCE instance managed by Terraform (`terraform/`)
- Stack managed by `docker-compose.yml` (no Ansible)
- Daily backups via `scripts/backup-to-git.sh`

## Architecture

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Homeserver | [Continuwuity](https://github.com/continuwuation/continuwuity) (Rust) | Matrix server with embedded RocksDB |
| Reverse proxy | Traefik v3.6 | SSL termination, Let's Encrypt |
| Client | Element Web | Browser-based Matrix client |
| Bridges | mautrix (Go/Python) | Platform ↔ Matrix protocol translation |
| Relay bot | Custom Python appservice | Cross-platform puppet relay with replies/reactions |
| Database | SQLite (per-service) | No shared database server |

## Files

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Full stack definition (7 services) |
| `.env.example` | Configuration template |
| `deploy.sh` | Deployment automation |
| `superbridge.sh` | Room creation and bridge plumbing |
| `relay/` | Relay bot appservice (Python, 141 tests) |
| `scripts/backup-to-git.sh` | Daily backup of configs + databases |
| `terraform/` | GCE infrastructure (Terraform) |
| `docs/` | Architecture documentation |
| `RESEARCH.md` | Research on Matrix bridges |
| `DEV.md` | Local development notes |
