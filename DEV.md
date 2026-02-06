# Local Development Setup

For running the Matrix Superbridge locally on macOS using Lima.

## Prerequisites

- macOS with [Lima](https://lima-vm.io/) (`brew install lima`)
- [Ansible](https://docs.ansible.com/) (`brew install ansible`)
- Telegram API credentials from https://my.telegram.org/apps

## 1. Start the Lima VM

```bash
limactl start matrix-vm.yaml --name matrix
```

This creates an Ubuntu VM with Docker, forwarding:
- Host `8080` -> Guest `80`
- Host `8443` -> Guest `443` (HTTPS)
- Host `8448` -> Guest `8448` (Federation)

## 2. Add /etc/hosts entries

```
127.0.0.1 local matrix.local element.local synapse-admin.local
```

## 3. Clone the Ansible playbook

```bash
git clone https://github.com/spantaleev/matrix-docker-ansible-deploy.git
```

The inventory and vars are already configured in this repo.

## 4. Update the SSH port

The Lima VM SSH port changes on each restart. Check it with:

```bash
limactl list
```

Update `inventory/hosts` with the current port:

```
matrix.local ansible_host=127.0.0.1 ansible_port=<PORT> ...
```

## 5. Run the Ansible playbook

```bash
cd matrix-docker-ansible-deploy

# Install roles
ansible-galaxy install -r requirements.yml

# Configure and deploy
ansible-playbook -i inventory/hosts setup.yml --tags=setup-all,ensure-matrix-users-created,start
```

## 6. Accept self-signed certificates

Visit these URLs in your browser and accept the certificate warnings:
- `https://matrix.local:8443`
- `https://element.local:8443`

## 7. Log into Element

Open `https://element.local:8443` and sign in.

## 8. Set up bridges

### Discord Bridge

1. Start a DM with `@discordbot:local` in Element
2. Send `login-qr`
3. Scan the QR code with Discord mobile (Settings -> Scan QR Code)
4. Bridge servers using `servers` then `bridge <server>`

### Telegram Bridge

1. Start a DM with `@telegrambot:local` in Element
2. Send `login-qr`
3. Scan the QR code with Telegram mobile
4. Sync chats with `sync`

## 9. Create a Superbridge room

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

