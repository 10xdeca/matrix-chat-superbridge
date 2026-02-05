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

## Production Server

The superbridge is running on Google Cloud:

| Service | URL |
|---------|-----|
| Matrix homeserver | https://matrix.35-201-14-61.sslip.io |
| Element Web | https://element.35-201-14-61.sslip.io |
| Synapse Admin | https://synapse-admin.35-201-14-61.sslip.io |

**Self-signed SSL**: You must accept the certificate warning in your browser before anything will work. Visit the Matrix URL first and click through the warning.

### For teammates: Using the Superbridge

You don't need to install anything. The server is already running. Here's how to get set up:

#### 1. Accept the self-signed certificate

Open https://matrix.35-201-14-61.sslip.io/_matrix/client/versions in your browser and accept the security warning. You'll see a JSON response -- that means it worked.

#### 2. Get a Matrix account

Ask Nick to create an account for you, or if registration is enabled, create one at Element.

#### 3. Log into Element

1. Open https://element.35-201-14-61.sslip.io
2. Click "Sign In"
3. The homeserver should be pre-configured. If prompted, set it to `https://matrix.35-201-14-61.sslip.io`
4. Sign in with your username and password

#### 4. Connect your Discord account

1. In Element, click the **+** next to "People" to start a new DM
2. Search for `@discordbot:35-201-14-61.sslip.io` and start a chat
3. The bot will greet you. Send: `login-qr`
4. A QR code appears. Open **Discord mobile** > Settings > **Scan QR Code** and scan it
5. Confirm on your phone. The bot will say "Successfully logged in as @yourusername"

#### 5. Connect your Telegram account

1. Start a new DM with `@telegrambot:35-201-14-61.sslip.io`
2. The bot will greet you. Send: `login`
3. Send your phone number with country code (e.g. `+61412345678`)
4. Telegram will send you a code. Send it back to the bot
5. The bot will say "Successfully logged in as @yourusername"

#### 6. Using bridged rooms

Once Discord and Telegram are connected:

- **Bridged rooms** appear in your Element room list. Messages sent in Discord show up in the Matrix room and vice versa for Telegram.
- **Your messages** on Matrix will appear as you on both Discord and Telegram (double puppeting).
- **Other people's messages** from Discord/Telegram appear in the Matrix room with their name and avatar.
- You can send messages from Element and they'll appear on both platforms.

#### What each user sees

| You send from | Discord users see | Telegram users see | Matrix users see |
|---------------|-------------------|--------------------|------------------|
| Discord | Your message (native) | Your name + message (ghost puppet) | Your name + message |
| Telegram | Your name + message (webhook) | Your message (native) | Your name + message |
| Element | Your message (double puppet) | Your message (double puppet) | Your message (native) |

**Ghost puppet**: A bot account that displays your name and avatar, so the message looks like it came from you even though you don't have an account on that platform.

**Double puppet**: If you've logged into both bridges, your messages appear as your actual account on both platforms -- indistinguishable from sending natively.

### Creating a new Superbridge room (admin only)

To bridge a new Discord channel with a Telegram group:

1. **Bridge the Discord server** (if not already done):
   - In your `@discordbot` DM, send: `guilds bridge <server_id>`
   - This creates Matrix portal rooms for each Discord channel

2. **Find the Telegram chat ID**:
   - In your `@telegrambot` DM, send: `sync chats`
   - Or SSH into the server and query: `sudo docker exec matrix-postgres psql -U matrix_mautrix_telegram -d matrix_mautrix_telegram -c "SELECT tgid, peer_type, title FROM portal;"`

3. **Bridge them together** -- in the Discord portal room, send:
   ```
   !tg bridge -<telegram_chat_id>
   ```
   Use `-` prefix for groups, `-100` prefix for supergroups/channels.

4. **Enable relay** for non-Discord users:
   ```
   !discord set-relay --create
   ```

5. If you get "Permission denied", SSH into the server and run:
   ```bash
   curl -sk -X POST 'https://matrix.35-201-14-61.sslip.io/_synapse/admin/v1/rooms/<room_id>/make_room_admin' \
     -H "Authorization: Bearer $TOKEN" \
     -H 'Content-Type: application/json' \
     -d '{"user_id": "@admin:35-201-14-61.sslip.io"}'
   ```

### Infrastructure (admin only)

The server runs on a GCE e2-medium instance in `australia-southeast1`. Managed via Terraform + Ansible.

```bash
# Provision/update infrastructure
cd terraform && terraform apply -var='ssh_allowed_cidrs=["YOUR_IP/32"]'

# Deploy/update Matrix server
cd matrix-docker-ansible-deploy
ansible-playbook -i inventory/hosts-production setup.yml --tags=setup-all,ensure-matrix-users-created,start

# Or use the helper script
./deploy.sh all
```

See `terraform/` for infrastructure config and `.env.production` for credentials (gitignored).

---

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
| `matrix-vm.yaml` | Lima VM configuration (local dev) |
| `terraform/` | GCE infrastructure (Terraform) |
| `deploy.sh` | Production deployment helper script |
| `matrix-docker-ansible-deploy/` | Ansible playbook (gitignored, clone separately) |
| `matrix-docker-ansible-deploy/inventory/hosts` | Ansible inventory for Lima VM (local) |
| `matrix-docker-ansible-deploy/inventory/hosts-production` | Ansible inventory for GCE (production) |
| `.env.local` | Local credentials (gitignored) |
| `.env.production` | Production credentials (gitignored) |
| `RESEARCH.md` | Detailed research on Matrix, bridges, and cross-platform puppeting |
