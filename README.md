# Matrix Chat Superbridge

Bridge multiple chat platforms (Discord, Telegram, etc.) through Matrix so users can communicate across platforms as themselves.

## How It Works

```
Discord Channel <--> Matrix Room <--> Telegram Group
```

- **Fully puppeted users** (logged into both bridges): Messages appear as their real account on both platforms
- **Single-platform users**: Messages relay via ghost puppets with their name and avatar -- no account needed on the other platform
- **Matrix users**: Messages appear as them on all bridged platforms via double puppeting

## Production Server

The superbridge is running on Google Cloud:

| Service | URL |
|---------|-----|
| Matrix homeserver | https://matrix.35-201-14-61.sslip.io |
| Element Web | https://element.35-201-14-61.sslip.io |
| Synapse Admin | https://synapse-admin.35-201-14-61.sslip.io |

**Self-signed SSL**: You must accept the certificate warning in your browser before anything will work. Visit the Matrix URL first and click through the warning.

## For Teammates: Getting Started

You don't need to install anything. The server is already running.

### 1. Accept the self-signed certificate

Open https://matrix.35-201-14-61.sslip.io/_matrix/client/versions in your browser and accept the security warning. You'll see a JSON response -- that means it worked.

### 2. Get your Matrix account

Your account is created automatically during deployment. Ask Nick for your username and password.

### 3. Log into Element

1. Open https://element.35-201-14-61.sslip.io
2. Click "Sign In"
3. The homeserver should be pre-configured. If prompted, set it to `https://matrix.35-201-14-61.sslip.io`
4. Sign in with your username and password

### 4. Connect your Discord account

1. In Element, click the **+** next to "People" to start a new DM
2. Search for `@discordbot:35-201-14-61.sslip.io` and start a chat
3. Send: `login-qr`
4. A QR code appears. Open **Discord mobile** > Settings > **Scan QR Code** and scan it
5. Confirm on your phone. The bot will say "Successfully logged in as @yourusername"

### 5. Connect your Telegram account

1. Start a new DM with `@telegrambot:35-201-14-61.sslip.io`
2. Send: `login`
3. Send your phone number with country code (e.g. `+61412345678`)
4. Telegram will send you a code. Send it back to the bot
5. The bot will say "Successfully logged in as @yourusername"

### 6. Using bridged rooms

Once Discord and Telegram are connected:

- **Bridged rooms** appear in your Element room list
- **Your messages** on Matrix appear as you on both Discord and Telegram (double puppeting)
- **Other people's messages** from Discord/Telegram appear with their name and avatar

### What each user sees

| You send from | Discord users see | Telegram users see | Matrix users see |
|---------------|-------------------|--------------------|------------------|
| Discord | Your message (native) | Your name + message (ghost puppet) | Your name + message |
| Telegram | Your name + message (webhook) | Your message (native) | Your name + message |
| Element | Your message (double puppet) | Your message (double puppet) | Your message (native) |

## Admin Guide

### Creating a new Superbridge room

To bridge a Discord channel with a Telegram group:

1. **Bridge the Discord server** (if not already done):
   - In your `@discordbot` DM, send: `guilds bridge <server_id>`

2. **Find the Telegram chat ID**:
   - In your `@telegrambot` DM, send: `sync chats`
   - Or query the database: `SELECT tgid, peer_type, title FROM portal;`

3. **Bridge them together** -- in the Discord portal room, send:
   ```
   !tg bridge -<telegram_chat_id>
   ```

4. **Enable relay** for non-Discord users:
   ```
   !discord set-relay --create
   ```

### Infrastructure

GCE e2-medium in `australia-southeast1`. Managed via Terraform + Ansible.

```bash
# Deploy/update
./deploy.sh deploy

# Or manually
cd matrix-docker-ansible-deploy
ansible-playbook -i inventory/hosts-production setup.yml \
  --vault-password-file ../.vault-password \
  --tags=setup-all,ensure-matrix-users-created,start
```

### Secrets

All secrets are encrypted with Ansible Vault in `production-vault.yml`. The vault password is in `.vault-password` (gitignored) -- ask a teammate for the key.

```bash
ansible-vault view production-vault.yml --vault-password-file .vault-password
```

## Local Development

See [DEV.md](DEV.md) for running the superbridge locally on macOS with Lima.

## Key Limitations

- **True cross-platform puppeting** requires users to log into both bridges. This works for the bridge operator but not for casual users.
- **Ghost puppets** provide the next-best experience: messages show with the sender's name and avatar but come from a bridge bot/webhook.

## Files

| File | Purpose |
|------|---------|
| `terraform/` | GCE infrastructure (Terraform) |
| `deploy.sh` | Production deployment helper |
| `production-vault.yml` | Encrypted secrets (Ansible Vault) |
| `.vault-password` | Vault key (gitignored) |
| `DEV.md` | Local development setup |
| `RESEARCH.md` | Research on Matrix bridges |
