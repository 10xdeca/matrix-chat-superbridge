# CLAUDE.md

## Project Overview

Matrix Chat Superbridge -- bridge Discord, Telegram (and potentially more) through a self-hosted Matrix server so users can communicate across platforms. Uses matrix-docker-ansible-deploy with mautrix bridges and double puppeting.

## Architecture

- **GCE VPS** (`35.201.14.61`): Ubuntu VM running Docker containers on Google Cloud
- **Synapse**: Matrix homeserver running in Docker
- **Traefik**: Reverse proxy with SSL
- **mautrix-discord**: Discord bridge with double puppeting
- **mautrix-telegram**: Telegram bridge with double puppeting
- **Element Web**: Matrix client at `https://element.35-201-14-61.sslip.io`
- **Synapse Admin**: Admin UI at `https://synapse-admin.35-201-14-61.sslip.io`

## Production Environment

- Host: `35.201.14.61` (GCE)
- Domain: `35-201-14-61.sslip.io`
- SSH: `ssh nick@35.201.14.61`

### Credentials (Production)
All production secrets are encrypted with Ansible Vault in `production-vault.yml` (committed).
- Vault password file: `.vault-password` (gitignored, shared between teammates)
- Decrypt: `ansible-vault view production-vault.yml --vault-password-file .vault-password`
- Edit: `ansible-vault edit production-vault.yml --vault-password-file .vault-password`
- Admin users: `nick` and `angie` (both server admins, passwords in vault)

### Running Ansible

```bash
cd matrix-docker-ansible-deploy
ansible-playbook -i inventory/hosts-production setup.yml \
  --vault-password-file ../.vault-password \
  --tags=setup-all,ensure-matrix-users-created,start

# Or use the helper script:
./deploy.sh deploy
```

## Bridge Operations

### Accessing bridge databases (via SSH into VPS)
```bash
# Telegram bridge
sudo docker exec matrix-postgres psql -U matrix_mautrix_telegram -d matrix_mautrix_telegram

# Discord bridge
sudo docker exec matrix-postgres psql -U matrix_mautrix_discord -d matrix_mautrix_discord

# Synapse
sudo docker exec matrix-postgres psql -U synapse -d synapse
```

### Useful database queries
```sql
-- Find Telegram chat ID for bridging
SELECT tgid, peer_type, mxid, title FROM portal;

-- Find Discord portal rooms
SELECT mxid, plain_name, name FROM portal WHERE mxid IS NOT NULL;
```

### Bridge commands (in Element)
- `!tg bridge -<chat_id>` -- Bridge a Telegram group to current room
- `!tg unbridge-and-continue` -- Unbridge existing portal and rebridge here
- `!discord set-relay --create` -- Create webhook for relaying non-Discord messages
- `!tg id` -- Get Telegram chat ID for current room
- `!tg sync chats` -- Sync Telegram chats to Matrix

### Synapse Admin API

```bash
curl -sk -X POST 'https://matrix.35-201-14-61.sslip.io/_synapse/admin/v1/rooms/<room_id>/make_room_admin' \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"user_id": "@nick:35-201-14-61.sslip.io"}'
```

Get access token:
```bash
curl -sk -X POST https://matrix.35-201-14-61.sslip.io/_matrix/client/v3/login \
  -H 'Content-Type: application/json' \
  -d '{"type":"m.login.password","user":"nick","password":"<see vault>"}'
```

## Common Problems and Fixes

1. **Telegram kicks Discord bot**: Bridge from the Discord portal room side instead; invite `@telegrambot` there
2. **"Permission denied" on bridge commands**: Use Synapse admin API `make_room_admin` endpoint
3. **Discord `login` command not found**: Use `login-qr` instead
4. **Ansible variable errors**: Check for `devture_traefik_*` -> `traefik_*` renames
5. **Container logs not readable**: Use `journalctl -u matrix-<service>.service` instead of `docker logs`
6. **Discord QR login "websocket: close sent"**: QR expired or transient error. Generate a new one with `login-qr`. If persistent, restart the bridge service.

## Superbridge Setup (Bridging Discord <-> Telegram)

The proven flow for creating a cross-platform bridged room:

1. Bridge a Discord server to Matrix (via `@discordbot` DM -> `servers` -> `bridge`)
2. Get Telegram chat ID from the `matrix_mautrix_telegram` portal table
3. In the Discord portal room: `!tg bridge -<chat_id>`
4. If permission error: use `make_room_admin` API
5. If Telegram already bridged elsewhere: `!tg unbridge-and-continue`
6. Enable Discord relay: `!discord set-relay --create`
7. Test both directions and verify ghost puppet relay for non-puppeted users

## Secret Management

All production secrets are encrypted with Ansible Vault (AES256).

- **Encrypted file**: `production-vault.yml` (committed to repo)
- **Vault password**: `.vault-password` (gitignored, shared out-of-band between teammates)
- **deploy.sh** handles vault automatically during `configure` and `deploy` steps

To view secrets: `ansible-vault view production-vault.yml --vault-password-file .vault-password`
To edit secrets: `ansible-vault edit production-vault.yml --vault-password-file .vault-password`

Vault contains: homeserver secret, postgres password, user passwords (nick, angie), Telegram API credentials.
