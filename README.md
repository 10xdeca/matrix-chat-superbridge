# Matrix Chat Superbridge

Bridge multiple chat platforms (Discord, Telegram, etc.) through Matrix so users can communicate across platforms as themselves.

## Quick Start

```bash
# 1. Start Lima VM
limactl start matrix-vm.yaml --name matrix

# 2. Add to /etc/hosts
# 127.0.0.1 local matrix.local element.local synapse-admin.local

# 3. Clone playbook and deploy
git clone https://github.com/spantaleev/matrix-docker-ansible-deploy.git
cd matrix-docker-ansible-deploy
ansible-galaxy install -r requirements.yml
ansible-playbook -i inventory/hosts setup.yml --tags=setup-all,ensure-matrix-users-created,start

# 4. Accept self-signed certs in browser
# Visit https://matrix.local:8443 and https://element.local:8443

# 5. Log into Element, set up bridges, bridge a room to both platforms
# See detailed instructions below
```

## How It Works

```
Discord Channel <--> Matrix Room <--> Telegram Group
```

- **Fully puppeted users** (logged into both bridges): Messages appear as their real account on both platforms
- **Single-platform users**: Messages relay via ghost puppets with their name and avatar -- no account needed on the other platform
- **Matrix users**: Messages appear as them on all bridged platforms via double puppeting

## Architecture

- **Matrix homeserver**: Synapse (via [matrix-docker-ansible-deploy](https://github.com/spantaleev/matrix-docker-ansible-deploy))
- **Discord bridge**: mautrix-discord with double puppeting
- **Telegram bridge**: mautrix-telegram with double puppeting
- **Double puppet appservice**: Maps Matrix users to their platform accounts
- **Discord webhooks**: Relay non-Discord users' messages with proper name/avatar attribution
- **Element Web**: Matrix client for direct access

## Local Development Setup

### Prerequisites

- macOS with [Lima](https://lima-vm.io/) (`brew install lima`)
- [Ansible](https://docs.ansible.com/) (`brew install ansible`)
- Telegram API credentials from https://my.telegram.org/apps

### 1. Start the Lima VM

```bash
limactl start matrix-vm.yaml --name matrix
```

This creates an Ubuntu VM with Docker, forwarding:
- Host `8080` -> Guest `80`
- Host `8443` -> Guest `443` (HTTPS)
- Host `8448` -> Guest `8448` (Federation)

### 2. Add /etc/hosts entries

```
127.0.0.1 local matrix.local element.local synapse-admin.local
```

### 3. Clone the Ansible playbook

```bash
git clone https://github.com/spantaleev/matrix-docker-ansible-deploy.git
```

The inventory and vars are already configured in this repo.

### 4. Update the SSH port

The Lima VM SSH port changes on each restart. Check it with:

```bash
limactl list
```

Update `inventory/hosts` with the current port:

```
matrix.local ansible_host=127.0.0.1 ansible_port=<PORT> ...
```

### 5. Run the Ansible playbook

```bash
cd matrix-docker-ansible-deploy

# Install roles
ansible-galaxy install -r requirements.yml

# Configure and deploy
ansible-playbook -i inventory/hosts setup.yml --tags=setup-all,ensure-matrix-users-created,start
```

### 6. Accept self-signed certificates

Visit these URLs in your browser and accept the certificate warnings:
- `https://matrix.local:8443`
- `https://element.local:8443`

### 7. Log into Element

Open `https://element.local:8443` and sign in.

### 8. Set up bridges

#### Discord Bridge

1. Start a DM with `@discordbot:local` in Element
2. Send `login-qr`
3. Scan the QR code with Discord mobile (Settings -> Scan QR Code)
4. Bridge servers using `servers` then `bridge <server>`

#### Telegram Bridge

1. Start a DM with `@telegrambot:local` in Element
2. Send `login-qr`
3. Scan the QR code with Telegram mobile
4. Sync chats with `sync`

### 9. Create a Superbridge room

To bridge a Discord channel and Telegram group together:

1. Bridge a Discord server -- this creates portal rooms for each channel
2. Find the Telegram chat ID:
   - DM `@telegrambot:local` and `sync chats`
   - Or query the database: `SELECT tgid, title FROM portal;` in the `matrix_mautrix_telegram` database
3. In the Discord portal room, bridge Telegram:
   ```
   !tg bridge -<telegram_chat_id>
   ```
   (prefix with `-` for groups, `-100` for supergroups/channels)
4. Enable Discord relay webhook for non-Discord users:
   ```
   !discord set-relay --create
   ```
5. Ensure your Matrix user has admin power level in the room (use Synapse admin API if needed)

## Troubleshooting

### Element can't connect to homeserver

The browser needs to trust the self-signed certificate. Visit `https://matrix.local:8443/_matrix/client/versions` in a new tab and accept the warning. Also accept the cert at `https://element.local:8443`.

### Element stuck on "Syncing..."

Usually caused by URL mismatches. Ensure these are all set with port 8443:
- `matrix_homeserver_url`
- `matrix_synapse_public_baseurl`
- `matrix_client_element_default_hs_url`

### Telegram bridge kicks Discord bot from room

The Telegram bridge removes non-Telegram users from portal rooms if there's no relay bot configured. Solutions:
- Bridge from the Discord portal room instead (invite `@telegrambot:local` there)
- Or configure a Telegram relay bot with a BotFather token

### Bridge commands don't work in a room

You may need admin power level. Use the Synapse admin API:
```
POST /_synapse/admin/v1/rooms/<room_id>/make_room_admin
{"user_id": "@youruser:local"}
```

### Non-puppeted users' messages don't appear on Discord

Run `!discord set-relay --create` in the room to create a Discord webhook for relaying messages from non-Discord users.

### Variable naming errors in Ansible

The playbook migrated from `devture_traefik_*` to `traefik_*`. Check the playbook changelog if you get unknown variable errors.

## Key Limitations

- **True cross-platform puppeting** requires users to log into both bridges with double puppeting. This works for the bridge operator but not for casual users.
- **Ghost puppets** provide the next-best experience: messages show with the sender's name and avatar but come from a bridge bot/webhook, not their real account.
- **Beeper** (the most well-funded Matrix bridge project) also has this limitation -- they opted for a unified inbox approach rather than solving cross-bridge identity.

## Files

| File | Purpose |
|------|---------|
| `matrix-vm.yaml` | Lima VM configuration |
| `matrix-docker-ansible-deploy/` | Ansible playbook (gitignored, clone separately) |
| `matrix-docker-ansible-deploy/inventory/hosts` | Ansible inventory for Lima VM |
| `matrix-docker-ansible-deploy/inventory/host_vars/matrix.local/vars.yml` | Matrix server configuration |
| `.env.local` | Local credentials (gitignored) |
| `RESEARCH.md` | Detailed research on Matrix, bridges, and cross-platform puppeting |
