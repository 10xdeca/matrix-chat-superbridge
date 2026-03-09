# CLAUDE.md

## Project Overview

Matrix Chat Superbridge — bridge Discord, Telegram, Signal, and WhatsApp through a self-hosted Matrix server so users can communicate across platforms. Uses Continuwuity (Rust homeserver) with mautrix bridges and a custom appservice relay bot for puppet-based message attribution.

## Architecture

```
Discord ←→ mautrix-discord ←→ Portal Room ←→ RELAY BOT ←→ Hub Room (Matrix)
Telegram ←→ mautrix-telegram ←→ Portal Room ←→ RELAY BOT ↕
Signal ←→ mautrix-signal ←→ Portal Room ←→ RELAY BOT ↕
WhatsApp ←→ mautrix-whatsapp ←→ Portal Room ←→ RELAY BOT ↕
```

### Services (docker-compose)
- **Traefik v3.6**: Reverse proxy with Let's Encrypt SSL
- **Continuwuity 0.5.6**: Rust-based Matrix homeserver (embedded RocksDB, no PostgreSQL)
- **Element Web**: Matrix client at `https://element.35-201-14-61.sslip.io`
- **mautrix-discord**: Discord bridge (Go)
- **mautrix-telegram**: Telegram bridge (Python, requires API credentials)
- **mautrix-signal**: Signal bridge (Go)
- **mautrix-whatsapp**: WhatsApp bridge (Go)
- **relay-bot**: Custom Python appservice for cross-platform puppet relay

### Relay Bot (`relay/`)
The relay bot is the core innovation — instead of text-attributed messages like `"**Alice (Discord):** hello"`, it creates puppet Matrix users (`@_relay_discord_a1b2c3d4:domain`) that send messages with the real sender's name and avatar. Key modules:
- `handler.py` — Message routing: portal→hub, hub→portals, portal→portal (cross-relay)
- `puppet.py` — Puppet user creation with profile sync
- `event_map.py` — SQLite event ID mapping for cross-platform replies and reactions
- `loop_prevention.py` — 3-layer message filtering to prevent echoes
- `config.py` — Environment-based config with double puppet mapping

## Production Environment

- Host: `35.201.14.61` (GCE e2-medium, Ubuntu)
- Domain: `35-201-14-61.sslip.io`
- SSH: `ssh nick@35.201.14.61`
- VPS directory: `~/matrix-chat-superbridge`
- Admin user: `@nick:35-201-14-61.sslip.io`

### Secrets
All secrets are in `.env` on the VPS (not committed). `.env.example` in the repo shows the structure.
- `REGISTRATION_TOKEN` — Continuwuity user registration token
- `RELAY_AS_TOKEN` / `RELAY_HS_TOKEN` — Relay bot appservice tokens
- Telegram API credentials (api_id, api_hash)

### Deployment

```bash
# First-time setup
./deploy.sh setup

# Update (copy files, rebuild, restart)
./deploy.sh deploy

# Verify services
./deploy.sh verify

# Create superbridge room
./superbridge.sh all
```

## Bridge Operations

### Appservice registration (Continuwuity)
Bridges register via the admin room (`#admins:35-201-14-61.sslip.io`):
```
!admin appservices register

```yaml
<paste registration.yaml contents>
```
```

### Accessing bridge databases (SQLite, via SSH)
```bash
# Get volume path
vol=$(sg docker -c 'docker volume inspect matrix-chat-superbridge_discord_data --format "{{.Mountpoint}}"')

# Read SQLite database
sudo sqlite3 $vol/discord.db "SELECT mxid, plain_name FROM portal WHERE mxid IS NOT NULL;"
```

### Bridge login commands (in Element, DM the bot)
- Discord: `login-qr` (scan QR with mobile app)
- Telegram: `login` (enter phone number)
- Signal: `login` (link as secondary device)
- WhatsApp: `login` (scan QR with WhatsApp mobile)

### Bridge commands (in room)
- `!tg bridge -<chat_id>` — Bridge Telegram group to current room
- `!discord bridge <channel-id>` — Bridge Discord channel to current room
- `!discord set-relay` — Enable relay mode for non-Discord users
- `!wa open <group-jid>` — Bridge WhatsApp group (experimental)

## Superbridge Setup Flow

1. `./superbridge.sh create-room` — Create unencrypted hub room
2. `./superbridge.sh invite-bots` — Invite bridge bots, set power levels
3. Bridge each platform into the hub room (see `./superbridge.sh plumb-discord`, etc.)
4. Configure relay bot: set `PORTAL_ROOMS` and `HUB_ROOM_ID` in `.env`
5. Register relay bot appservice in admin room
6. Start relay bot: `docker compose up -d relay-bot`

## Common Problems and Fixes

1. **Bridge says "as_token not accepted"**: Register the bridge's `registration.yaml` in the admin room
2. **Bridge can't open database**: Go bridges use `file:///data/<name>.db` URIs, not `sqlite://`
3. **Signal/WhatsApp unreachable from homeserver**: Set `appservice.hostname: 0.0.0.0` (default is 127.0.0.1)
4. **Discord `login` not found**: Use `login-qr` instead
5. **Traefik can't connect to Docker**: Need Traefik v3.6+ for Docker Engine 29+
6. **Telegram bridge crash-loops**: Needs `telegram.api_id` and `telegram.api_hash` from https://my.telegram.org
7. **Continuwuity admin commands fail**: YAML must be in a markdown code block (triple backticks)

## File Structure

```
├── docker-compose.yml          # Full stack definition
├── .env.example                # Configuration template
├── deploy.sh                   # Deployment automation
├── superbridge.sh              # Room creation and bridge plumbing
├── element-config.json.template # Element Web config template
├── scripts/backup-to-git.sh    # Daily backup script
├── relay/                      # Relay bot appservice
│   ├── appservice/             # Python source (6 modules)
│   ├── tests/                  # Test suite (141 tests)
│   ├── Dockerfile
│   ├── registration.yaml       # Appservice registration template
│   └── requirements.txt
├── terraform/                  # GCE infrastructure (still valid)
├── docs/                       # Architecture documentation
└── matrix-docker-ansible-deploy/ # Old Ansible playbook (unused)
```
