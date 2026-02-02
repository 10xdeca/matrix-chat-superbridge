# Matrix Self-Hosted Server Research

**Date:** 2026-02-01 (Updated: 2026-02-02)

## Executive Summary

Matrix is a decentralized, open-standard communication protocol for real-time communication with full federation support. This document covers server options, bridges for popular chat apps, federation configuration, and self-hosting best practices.

### Quick Start Recommendations

| Use Case | Server | Database | Why |
|----------|--------|----------|-----|
| Personal/Small (1-10 users) | Synapse | PostgreSQL | Most reliable, best bridge support |
| Small-Medium (10-100 users) | Synapse | PostgreSQL | Mature, full features, good bridge support |
| Large/Enterprise (100+ users) | Synapse (workers) | PostgreSQL | Scalable, battle-tested |
| Lightweight/Experimental | Continuwuity | RocksDB | Active Rust community fork, low resources |

> **Note (2026-02):** Dendrite is now in maintenance mode at Matrix.org (moved to Element). Conduit's main fork (conduwuit) was archived in April 2025. For lightweight options, consider Continuwuity (community continuation) or stick with Synapse for stability.

### Top Bridge Recommendations

| Platform | Recommended Bridge | Notes |
|----------|-------------------|-------|
| Discord | mautrix-discord | Best feature support, active development |
| Telegram | mautrix-telegram | Excellent, most mature mautrix bridge |
| WhatsApp | mautrix-whatsapp | Works well, uses WhatsApp Web protocol |
| Signal | mautrix-signal | Good but requires signald daemon |
| Slack | mautrix-slack | Better than appservice-slack for most cases |
| iMessage | mautrix-imessage | Requires macOS or jailbroken iOS |
| IRC | Heisenbridge | Modern replacement for older bridges |

---

## 1. Matrix Server Options

### Synapse (Python - Reference Implementation)

The original and most widely deployed Matrix homeserver.

**Pros:**
- Most mature and battle-tested
- Full Matrix spec compliance
- Excellent documentation
- Best bridge compatibility
- Supports workers for horizontal scaling
- Largest community and support

**Cons:**
- Highest resource usage
- Requires PostgreSQL for production
- Can be slow on large rooms

**Resource Requirements:**
- RAM: 1-4GB+ depending on usage
- CPU: 1-2+ cores
- Storage: Grows with media/history

**Repository:** https://github.com/matrix-org/synapse

### Dendrite (Go - Second Generation)

Second-generation homeserver written in Go.

> **Status (2026-02):** The Matrix.org Foundation archived Dendrite in November 2024. Development continues under Element at [element-hq/dendrite](https://github.com/element-hq/dendrite), but the project is now in maintenance mode with limited active development.

**Pros:**
- Lower resource usage than Synapse
- Better performance characteristics
- Can run as monolith or microservices

**Cons:**
- In maintenance mode (limited new development)
- Not fully feature-complete
- Smaller community
- Some bridges may have compatibility issues
- Future tied to Element's priorities

**Resource Requirements:**
- RAM: 200-500MB for active use
- CPU: 1 core typically sufficient
- Storage: Similar to Synapse

**Repository:** https://github.com/element-hq/dendrite (active)
**Archived:** https://github.com/matrix-org/dendrite (read-only)

### Conduit / Continuwuity (Rust - Lightweight)

Lightweight Rust-based homeservers.

> **Status (2026-02):** The original Conduit is in maintenance/beta mode. Its popular fork **conduwuit** was archived in April 2025. The community has continued development as **Continuwuity**.

**Pros:**
- Extremely lightweight (50-200MB RAM)
- Single binary deployment
- Very easy setup
- Fast startup time
- Uses RocksDB (no separate database needed)

**Cons:**
- Fragmented ecosystem (multiple forks)
- Fewer features than Synapse
- Limited admin tooling
- Some bridges may have compatibility issues
- Smaller community for troubleshooting

**Resource Requirements:**
- RAM: 50-200MB
- CPU: 1 core typically sufficient
- Storage: Grows with usage

**Repositories:**
- **Continuwuity** (recommended): https://forgejo.ellis.link/continuwuation/continuwuity
- Conduit (original, maintenance mode): https://gitlab.com/famedly/conduit
- conduwuit (archived April 2025): https://codeberg.org/arf/conduwuit

---

## 2. Bridge Options for Chat Apps

### Overview

The mautrix bridge suite is the most actively maintained and feature-rich set of bridges. All mautrix bridges generally support:
- Text messages
- Media (images, files, video, audio)
- Reactions
- Replies
- Message edits
- Message deletions
- Typing indicators
- Read receipts

**Note:** Voice/video bridging is generally not supported by any bridges.

### Discord

#### mautrix-discord (Recommended)
- **Setup:** Moderate - requires Discord bot token
- **Features:** Messages, reactions, replies, threads, embeds, stickers, media
- **Limitations:** No voice/video, some embed formatting differences
- **Status:** Actively maintained
- **Repo:** https://github.com/mautrix/discord

#### matrix-appservice-discord
- **Setup:** Moderate
- **Features:** Basic messaging, webhooks
- **Status:** Less actively maintained
- **Repo:** https://github.com/matrix-org/matrix-appservice-discord

### Telegram

#### mautrix-telegram (Recommended)
- **Setup:** Requires Telegram API credentials
- **Features:** Excellent - messages, media, stickers, reactions, replies, forwards, location
- **Status:** Most mature mautrix bridge
- **Notes:** Supports both bot and user puppeting
- **Repo:** https://github.com/mautrix/telegram

### WhatsApp

#### mautrix-whatsapp (Recommended)
- **Setup:** QR code linking (like WhatsApp Web)
- **Features:** Messages, media, reactions, replies, location, contacts
- **Limitations:** Uses WhatsApp Web protocol, may break if WhatsApp changes API
- **Status:** Actively maintained
- **Repo:** https://github.com/mautrix/whatsapp

### Signal

#### mautrix-signal (Recommended)
- **Setup:** Complex - requires signald daemon
- **Features:** Messages, media, reactions, replies
- **Limitations:** Requires separate signald process, phone number needed
- **Status:** Actively maintained
- **Repo:** https://github.com/mautrix/signal

**signald:** https://gitlab.com/signald/signald

### Slack

#### mautrix-slack (Recommended)
- **Setup:** Requires Slack app configuration with OAuth
- **Features:** Messages, threads, reactions, files
- **Status:** Actively maintained
- **Repo:** https://github.com/mautrix/slack

#### matrix-appservice-slack
- **Setup:** Webhook-based or RTM
- **Features:** Basic messaging
- **Status:** Less feature-rich than mautrix
- **Repo:** https://github.com/matrix-org/matrix-appservice-slack

### iMessage

#### mautrix-imessage
- **Setup:** Complex - requires macOS host or jailbroken iOS device
- **Features:** Messages, media, reactions, replies, tapbacks
- **Limitations:** Platform requirements make this challenging
- **Notes:** Beeper (company) has commercial solutions
- **Repo:** https://github.com/mautrix/imessage

### IRC

#### Heisenbridge (Recommended)
- **Setup:** Relatively simple
- **Features:** Modern bouncer-style IRC bridge
- **Status:** Actively maintained, modern replacement for older bridges
- **Repo:** https://github.com/hifi/heisenbridge

#### matrix-appservice-irc
- **Setup:** More complex
- **Features:** Full-featured but older architecture
- **Repo:** https://github.com/matrix-org/matrix-appservice-irc

### Other Notable Bridges

| Platform | Bridge | Notes |
|----------|--------|-------|
| Facebook Messenger | mautrix-facebook | Uses Facebook's unofficial API |
| Instagram | mautrix-instagram | Direct messages |
| Twitter/X | mautrix-twitter | DMs only |
| Google Chat | mautrix-googlechat | Requires Google account |
| LinkedIn | mautrix-linkedin | Community maintained |
| XMPP | mautrix-xmpp | Jabber/XMPP federation |

---

## 3. Matrix Federation

### How Federation Works

Matrix federation allows users on different homeservers to communicate seamlessly. Key concepts:

1. **Server-to-Server (S2S) API:** Homeservers communicate via HTTPS
2. **Room State:** Rooms are replicated across all participating servers
3. **Event DAG:** Messages form a directed acyclic graph for consistency
4. **Signing Keys:** Servers sign events cryptographically

### Federation Requirements

#### Ports and Protocols
- **Port 443:** Preferred (via .well-known delegation)
- **Port 8448:** Default Matrix federation port
- **Protocol:** HTTPS with valid TLS certificate

#### DNS Configuration

**Option 1: .well-known (Recommended)**

Create `/.well-known/matrix/server` at your domain root:
```json
{
  "m.server": "matrix.yourdomain.com:443"
}
```

**Option 2: SRV Record**
```
_matrix._tcp.yourdomain.com. 3600 IN SRV 10 5 443 matrix.yourdomain.com.
```

#### Client Discovery

Create `/.well-known/matrix/client`:
```json
{
  "m.homeserver": {
    "base_url": "https://matrix.yourdomain.com"
  }
}
```

### Testing Federation

Use the official federation tester:
- https://federationtester.matrix.org

Enter your domain to verify:
- DNS resolution
- TLS certificate validity
- Server reachability
- Signing key availability

### Private Federation

You can run Matrix without federation for internal use:
- Don't expose federation port
- Set `allow_public_rooms_over_federation: false`
- Disable room directory federation

---

## 4. Best Practices for Self-Hosting

### Deployment Methods

#### Docker Compose (Recommended for most users)
```yaml
version: '3'
services:
  synapse:
    image: matrixdotorg/synapse:latest
    restart: unless-stopped
    volumes:
      - ./data:/data
    environment:
      - SYNAPSE_CONFIG_PATH=/data/homeserver.yaml
    ports:
      - "8008:8008"
    depends_on:
      - db

  db:
    image: postgres:15
    restart: unless-stopped
    volumes:
      - ./postgres:/var/lib/postgresql/data
    environment:
      - POSTGRES_USER=synapse
      - POSTGRES_PASSWORD=changeme
      - POSTGRES_DB=synapse
      - POSTGRES_INITDB_ARGS=--encoding=UTF-8 --lc-collate=C --lc-ctype=C
```

#### Ansible Playbook (Comprehensive)
For a complete setup including bridges, use the community playbook:
https://github.com/spantaleev/matrix-docker-ansible-deploy

This handles:
- Synapse (recommended) or Dendrite
- All popular bridges
- Reverse proxy
- SSL certificates
- PostgreSQL
- Admin tools

> **Note:** Synapse is the most reliable choice for this playbook due to best documentation, bridge compatibility, and long-term Matrix.org support.

### Database Configuration

**SQLite:** Only for testing/development
**PostgreSQL:** Required for production Synapse

PostgreSQL optimizations:
```sql
-- Recommended settings
shared_buffers = 256MB
effective_cache_size = 1GB
maintenance_work_mem = 128MB
work_mem = 16MB
```

### Reverse Proxy Configuration

#### Nginx
```nginx
server {
    listen 443 ssl http2;
    server_name matrix.yourdomain.com;

    ssl_certificate /path/to/fullchain.pem;
    ssl_certificate_key /path/to/privkey.pem;

    location ~ ^(/_matrix|/_synapse/client) {
        proxy_pass http://localhost:8008;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Host $host;
        client_max_body_size 50M;
    }
}

# Federation (if using port 8448)
server {
    listen 8448 ssl http2;
    server_name matrix.yourdomain.com;

    ssl_certificate /path/to/fullchain.pem;
    ssl_certificate_key /path/to/privkey.pem;

    location / {
        proxy_pass http://localhost:8008;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Host $host;
    }
}
```

#### Caddy (Simpler)
```caddy
matrix.yourdomain.com {
    reverse_proxy /_matrix/* localhost:8008
    reverse_proxy /_synapse/* localhost:8008
}
```

### SSL/TLS Setup

Use Let's Encrypt with auto-renewal:
```bash
certbot certonly --nginx -d matrix.yourdomain.com
```

Or with Caddy (automatic).

### Backup Strategy

**Critical to back up:**
1. PostgreSQL database (daily dumps)
2. Media store (`/data/media_store`)
3. Signing keys (`/data/*.signing.key`) - **CRITICAL: Cannot be regenerated!**
4. Configuration files

```bash
# PostgreSQL backup
pg_dump -U synapse synapse > synapse_backup_$(date +%Y%m%d).sql

# Full data backup
tar -czf matrix_backup_$(date +%Y%m%d).tar.gz /path/to/data
```

### Monitoring

Enable Prometheus metrics in Synapse:
```yaml
enable_metrics: true
metrics_port: 9000
```

Grafana dashboard: ID 10046

Key metrics to monitor:
- `synapse_federation_send_queue_length`
- `synapse_storage_events`
- `synapse_http_server_requests_total`
- Database connection pool usage

### Security Hardening

1. **Disable open registration** (or use CAPTCHA/email verification)
```yaml
enable_registration: false
# Or with restrictions:
enable_registration: true
enable_registration_captcha: true
```

2. **Enable rate limiting**
```yaml
rc_message:
  per_second: 0.2
  burst_count: 10
rc_registration:
  per_second: 0.17
  burst_count: 3
```

3. **Restrict URL previews** (SSRF prevention)
```yaml
url_preview_enabled: true
url_preview_ip_range_blacklist:
  - '127.0.0.0/8'
  - '10.0.0.0/8'
  - '172.16.0.0/12'
  - '192.168.0.0/16'
```

4. **Use strong secrets** - Generate with:
```bash
pwgen -s 64 1
```

---

## 5. Ecosystem Tools

### Admin Tools

#### Synapse Admin
Web UI for Synapse administration.
- User management
- Room management
- Server statistics
- Media management

**Repo:** https://github.com/Awesome-Technologies/synapse-admin

### Client Options

| Client | Platform | Notes |
|--------|----------|-------|
| Element | Web, Desktop, iOS, Android | Official client, most features |
| FluffyChat | All platforms | Beautiful UI, Flutter-based |
| Cinny | Web | Discord-like interface |
| Nheko | Desktop | Native Qt client |
| SchildiChat | All | Element fork with extra features |
| Hydrogen | Web | Lightweight, fast |

### Media Repository

- **Built-in:** Works for most cases
- **matrix-media-repo:** For S3/object storage support
  - https://github.com/turt2live/matrix-media-repo

### Identity Server

Usually not needed for self-hosting. If required:
- **ma1sd:** https://github.com/ma1uta/ma1sd

---

## Key Resources

### Official Documentation
- Matrix Spec: https://spec.matrix.org/
- Synapse Docs: https://matrix-org.github.io/synapse/latest/
- Dendrite Docs: https://matrix-org.github.io/dendrite/ (may be outdated)
- Conduit Docs: https://docs.conduit.rs/
- Continuwuity Docs: https://forgejo.ellis.link/continuwuation/continuwuity

### Community Resources
- Ansible Playbook: https://github.com/spantaleev/matrix-docker-ansible-deploy
- Matrix.org Blog: https://matrix.org/blog/
- Reddit: r/selfhosted, r/Matrix

### Support Rooms
- `#synapse:matrix.org` - Synapse support
- `#matrix:matrix.org` - General Matrix discussion
- `#matrix-bridges:matrix.org` - Bridge support

---

## Getting Started Checklist

1. [ ] Choose a server (Synapse recommended for beginners)
2. [ ] Set up PostgreSQL database
3. [ ] Configure reverse proxy with SSL
4. [ ] Set up DNS and .well-known files
5. [ ] Test federation at federationtester.matrix.org
6. [ ] Install Element or preferred client
7. [ ] Set up bridges as needed
8. [ ] Configure backups
9. [ ] Set up monitoring
10. [ ] Harden security settings
