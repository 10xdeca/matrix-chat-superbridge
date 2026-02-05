# CLAUDE.md

## Project Overview

Matrix Chat Superbridge -- bridge Discord, Telegram (and potentially more) through a self-hosted Matrix server so users can communicate across platforms. Uses matrix-docker-ansible-deploy with mautrix bridges and double puppeting.

## Architecture

- **Lima VM** (`matrix-vm.yaml`): Ubuntu 24.04 VM running Docker containers via Lima on macOS
- **Synapse**: Matrix homeserver running in Docker
- **Traefik**: Reverse proxy with self-signed SSL certificates
- **mautrix-discord**: Discord bridge with double puppeting
- **mautrix-telegram**: Telegram bridge with double puppeting
- **Element Web**: Matrix client at `https://element.local:8443`
- **Synapse Admin**: Admin UI at `https://synapse-admin.local:8443`

## Local Environment

### Lima VM
- Name: `matrix`
- SSH: `limactl shell matrix` or `ssh -p <port> nick@127.0.0.1`
- SSH key: `/Users/nick/.lima/_config/user`
- Port changes on restart -- check with `limactl list` and update `inventory/hosts`

### Port Forwarding
- Host `8443` -> Guest `443` (HTTPS for Matrix, Element, etc.)
- Host `8080` -> Guest `80`
- Host `8448` -> Guest `8448` (Federation)

### /etc/hosts Required
```
127.0.0.1 local matrix.local element.local synapse-admin.local
```

### Credentials (Local)
Stored in `.env.local` (gitignored). Used for local dev only.

### Credentials (Production)
All production secrets are encrypted with Ansible Vault in `production-vault.yml` (committed).
- Vault password file: `.vault-password` (gitignored, shared between teammates)
- Decrypt: `ansible-vault view production-vault.yml --vault-password-file .vault-password`
- Edit: `ansible-vault edit production-vault.yml --vault-password-file .vault-password`
- Admin users: `nick` and `angie` (both server admins, passwords in vault)

## Key Configuration

### Ansible Vars
`matrix-docker-ansible-deploy/inventory/host_vars/matrix.local/vars.yml`

Critical settings that were painful to debug:
- `matrix_homeserver_url`: MUST include `:8443` port
- `matrix_synapse_public_baseurl`: MUST include `:8443` port (fixes Element "syncing" freeze)
- `matrix_client_element_default_hs_url`: MUST include `:8443` port
- `traefik_*` variables (NOT `devture_traefik_*` -- naming changed in playbook migration)
- `traefik_ssl_test: true` for self-signed certs

### Running Ansible

Local:
```bash
cd matrix-docker-ansible-deploy
ansible-playbook -i inventory/hosts setup.yml --tags=setup-all,ensure-matrix-users-created,start
```

Production (requires vault password):
```bash
cd matrix-docker-ansible-deploy
ansible-playbook -i inventory/hosts-production setup.yml \
  --vault-password-file ../.vault-password \
  --tags=setup-all,ensure-matrix-users-created,start

# Or use the helper script:
./deploy.sh deploy
```

## Bridge Operations

### Accessing bridge databases (via SSH into VM)
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

Local:
```bash
curl -sk -X POST 'https://matrix.local:8443/_synapse/admin/v1/rooms/<room_id>/make_room_admin' \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"user_id": "@nick:local"}'
```

Production:
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

1. **Element can't connect**: Browser needs to accept self-signed cert at `https://matrix.local:8443/_matrix/client/versions` first
2. **Element stuck syncing**: Missing `:8443` port in `matrix_synapse_public_baseurl`
3. **Telegram kicks Discord bot**: Bridge from the Discord portal room side instead; invite `@telegrambot:local` there
4. **"Permission denied" on bridge commands**: Use Synapse admin API `make_room_admin` endpoint
5. **DM popup disappears in Element**: Chrome bug -- use Safari, or clear site data
6. **Discord `login` command not found**: Use `login-qr` instead
7. **Ansible variable errors**: Check for `devture_traefik_*` -> `traefik_*` renames
8. **Container logs not readable**: Use `journalctl -u matrix-<service>.service` instead of `docker logs`

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
