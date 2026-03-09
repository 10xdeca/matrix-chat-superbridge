#!/usr/bin/env bash
# deploy.sh — Deploy Continuwuity + Traefik + Element + 4 mautrix bridges to GCE VPS
#
# Usage:
#   ./deploy.sh setup      # First-time setup: copy files, generate tokens, start services, register admin
#   ./deploy.sh deploy     # Update: copy changed files, rebuild/restart services
#   ./deploy.sh configure  # Only configure bridges (after initial start)
#   ./deploy.sh backup     # Run backup script on the VPS
#   ./deploy.sh verify     # Check services are running
#   ./deploy.sh superbridge [cmd]  # Run superbridge.sh commands
#
# Prerequisites:
#   - SSH access to GCE VPS as 'nick@35.201.14.61'
#   - Docker + Compose on the VPS
set -euo pipefail

VPS_HOST="nick@35.201.14.61"
VPS_DIR="~/matrix-chat-superbridge"
SERVER_NAME="35-201-14-61.sslip.io"
ADMIN_USER="nick"
ADMIN_PASSWORD=""  # Set interactively during setup
HOMESERVER_URL="http://continuwuity:6167"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Helpers ---

info()  { printf '\033[1;34m==> %s\033[0m\n' "$*"; }
ok()    { printf '\033[1;32m  ✓ %s\033[0m\n' "$*"; }
warn()  { printf '\033[1;33m  ! %s\033[0m\n' "$*"; }
error() { printf '\033[1;31m  ✗ %s\033[0m\n' "$*"; exit 1; }

ssh_vps() { ssh "$VPS_HOST" "$@"; }
vps_compose() { ssh_vps "cd $VPS_DIR && docker compose $*"; }

# --- Prerequisites check ---

check_prereqs() {
  info "Checking prerequisites..."
  local missing=0

  for cmd in docker ssh scp; do
    if ! command -v "$cmd" &>/dev/null; then
      error "Missing: $cmd"
      missing=1
    fi
  done

  if [ ! -f ~/.ssh/id_ed25519.pub ] && [ ! -f ~/.ssh/id_rsa.pub ]; then
    warn "No SSH key found — ensure you can SSH to $VPS_HOST"
  fi

  # Test SSH connectivity
  if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$VPS_HOST" "echo ok" &>/dev/null; then
    error "Cannot SSH to $VPS_HOST. Check your SSH config."
    missing=1
  fi

  if [ "$missing" -eq 1 ]; then
    error "Prerequisites not met."
  fi

  ok "Prerequisites OK"
}

# --- Copy files to VPS ---

copy_files() {
  info "Copying files to VPS ($VPS_HOST:$VPS_DIR)"

  ssh_vps "mkdir -p $VPS_DIR/relay $VPS_DIR/scripts"

  # Copy docker-compose and config files
  scp "$SCRIPT_DIR/docker-compose.yml" "$VPS_HOST:$VPS_DIR/docker-compose.yml"
  scp "$SCRIPT_DIR/.env.example" "$VPS_HOST:$VPS_DIR/.env.example"
  scp "$SCRIPT_DIR/superbridge.sh" "$VPS_HOST:$VPS_DIR/superbridge.sh"
  scp "$SCRIPT_DIR/scripts/backup-to-git.sh" "$VPS_HOST:$VPS_DIR/scripts/backup-to-git.sh"
  ssh_vps "chmod +x $VPS_DIR/superbridge.sh $VPS_DIR/scripts/backup-to-git.sh"

  # Copy relay bot source
  scp -r "$SCRIPT_DIR/relay/" "$VPS_HOST:$VPS_DIR/relay/"

  ok "Files copied"
}

# --- Generate .env on VPS ---

generate_env() {
  if ssh_vps "test -f $VPS_DIR/.env"; then
    warn ".env already exists on VPS — skipping generation"
    return
  fi

  info "Generating .env on VPS"
  REGISTRATION_TOKEN=$(openssl rand -hex 24)
  RELAY_AS_TOKEN=$(python3 -c "import secrets; print(secrets.token_hex(32))")
  RELAY_HS_TOKEN=$(python3 -c "import secrets; print(secrets.token_hex(32))")

  ssh_vps "cat > $VPS_DIR/.env" <<EOF
MATRIX_SERVER_NAME=$SERVER_NAME
REGISTRATION_TOKEN=$REGISTRATION_TOKEN
ACME_EMAIL=admin@example.com
RELAY_AS_TOKEN=$RELAY_AS_TOKEN
RELAY_HS_TOKEN=$RELAY_HS_TOKEN
PORTAL_ROOMS=
HUB_ROOM_ID=
# RELAY_DOUBLE_PUPPETS=
# RELAY_LOG_LEVEL=INFO
EOF

  ok ".env created"
  echo
  warn "Save these tokens — you'll need them:"
  echo "  Registration token: $REGISTRATION_TOKEN"
  echo "  Relay AS token:     $RELAY_AS_TOKEN"
  echo "  Relay HS token:     $RELAY_HS_TOKEN"
  echo
  warn "Edit .env on VPS to add TELEGRAM_API_ID/TELEGRAM_API_HASH and room IDs"
}

# --- Generate Element Web config with actual domain ---

generate_element_config() {
  info "Generating Element Web config"
  ssh_vps "cat > $VPS_DIR/element-config.json" <<EOF
{
    "default_server_config": {
        "m.homeserver": {
            "base_url": "https://matrix.$SERVER_NAME",
            "server_name": "$SERVER_NAME"
        }
    },
    "disable_guests": true,
    "disable_3pid_login": true
}
EOF
  ok "Element config generated"
}

# --- Start Continuwuity ---

start_continuwuity() {
  info "Pulling images"
  vps_compose "pull"
  ok "Images pulled"

  info "Starting Traefik + Continuwuity"
  vps_compose "up -d traefik continuwuity"

  info "Waiting for Continuwuity to become healthy..."
  for i in $(seq 1 30); do
    if ssh_vps "curl -sf http://localhost:6167/_matrix/client/versions" >/dev/null 2>&1; then
      ok "Continuwuity is healthy"
      return
    fi
    sleep 2
  done
  error "Continuwuity failed to start within 60 seconds"
}

# --- Register admin user ---

register_admin() {
  info "Registering admin user: @$ADMIN_USER:$SERVER_NAME"

  if [[ -z "$ADMIN_PASSWORD" ]]; then
    printf "  Enter password for @%s:%s: " "$ADMIN_USER" "$SERVER_NAME"
    read -rs ADMIN_PASSWORD
    echo
  fi

  REG_TOKEN=$(ssh_vps "grep REGISTRATION_TOKEN $VPS_DIR/.env | cut -d= -f2")

  # First call gets the session
  SESSION=$(ssh_vps "curl -s -X POST 'http://localhost:6167/_matrix/client/v3/register' \
    -H 'Content-Type: application/json' \
    -d '{\"username\": \"$ADMIN_USER\", \"password\": \"dummy\"}'" \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('session',''))")

  # Second call with auth
  RESULT=$(ssh_vps "curl -s -X POST 'http://localhost:6167/_matrix/client/v3/register' \
    -H 'Content-Type: application/json' \
    -d '{
      \"username\": \"$ADMIN_USER\",
      \"password\": \"$ADMIN_PASSWORD\",
      \"auth\": {
        \"type\": \"m.login.registration_token\",
        \"token\": \"$REG_TOKEN\",
        \"session\": \"$SESSION\"
      }
    }'")

  if echo "$RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'user_id' in d" 2>/dev/null; then
    ok "Registered @$ADMIN_USER:$SERVER_NAME"
  else
    warn "Registration response: $RESULT"
    warn "User may already exist — continuing"
  fi
}

# --- Configure bridges ---

configure_bridges() {
  local bridges=("whatsapp" "discord" "signal" "telegram")

  for bridge in "${bridges[@]}"; do
    info "Configuring mautrix-$bridge"
    local volume="${bridge}_data"
    local service="mautrix-$bridge"

    # Generate default config by running the bridge once
    info "  Generating default config for $bridge..."
    vps_compose "run --rm $service" 2>/dev/null || true
    sleep 2

    # Get the volume mount path
    local volume_path
    volume_path=$(ssh_vps "docker volume inspect matrix_${volume} --format '{{.Mountpoint}}'" 2>/dev/null || echo "")
    if [[ -z "$volume_path" ]]; then
      volume_path=$(ssh_vps "docker volume inspect ${volume} --format '{{.Mountpoint}}'" 2>/dev/null || echo "")
    fi

    if [[ -z "$volume_path" ]]; then
      warn "  Could not find volume for $bridge — skipping config"
      continue
    fi

    # Patch config.yaml: homeserver address and server name
    info "  Patching config.yaml..."
    ssh_vps "sudo python3 -c \"
import yaml, sys
config_path = '$volume_path/config.yaml'
with open(config_path) as f:
    config = yaml.safe_load(f)

# Set homeserver
config.setdefault('homeserver', {})
config['homeserver']['address'] = '$HOMESERVER_URL'
config['homeserver']['domain'] = '$SERVER_NAME'

# Set bridge permissions — allow admin user full control
if 'bridge' in config:
    config['bridge']['permissions'] = {
        '@$ADMIN_USER:$SERVER_NAME': 'admin',
        '$SERVER_NAME': 'user'
    }

with open(config_path, 'w') as f:
    yaml.dump(config, f, default_flow_style=False)

print('Config patched')
\"" || {
      warn "  python3+yaml not available — patching with sed"
      ssh_vps "sudo sed -i \
        -e 's|address:.*|address: $HOMESERVER_URL|' \
        -e 's|domain:.*|domain: $SERVER_NAME|' \
        '$volume_path/config.yaml'"
    }

    # Handle Telegram-specific config
    if [[ "$bridge" == "telegram" ]]; then
      warn "  Telegram requires API credentials from https://my.telegram.org"
      warn "  Edit $volume_path/config.yaml on the VPS to set:"
      warn "    telegram.api_id and telegram.api_hash"
    fi

    ok "  $bridge configured"
  done
}

# --- Start all services ---

start_all() {
  info "Starting all services"
  vps_compose "up -d --build"

  info "Waiting for services..."
  sleep 10

  vps_compose "ps"
  ok "All services started"
  echo
  warn "Next steps to complete bridge setup:"
  echo "  1. Open Element at https://element.$SERVER_NAME"
  echo "  2. Log in as @$ADMIN_USER:$SERVER_NAME"
  echo "  3. Join #admins:$SERVER_NAME"
  echo "  4. For each bridge, register its appservice:"
  echo "     !admin appservices register"
  echo "     <paste contents of registration.yaml from each bridge's data volume>"
  echo
  echo "  Bridge registration files:"
  for bridge in whatsapp discord signal telegram; do
    echo "     ssh $VPS_HOST \"sudo cat \$(docker volume inspect matrix_${bridge}_data --format '{{.Mountpoint}}')/registration.yaml\""
  done
  echo
  echo "  5. Telegram: Set API ID/hash in the config, then restart the bridge"
}

# --- Verify ---

verify() {
  info "Verifying deployment"

  # Check Matrix versions endpoint via Traefik
  if ssh_vps "curl -sf http://localhost:6167/_matrix/client/versions" | python3 -c "import sys,json; v=json.load(sys.stdin); print(f'  Matrix versions: {v[\"versions\"]}')" 2>/dev/null; then
    ok "Matrix API responding"
  else
    error "Matrix API not responding"
  fi

  echo
  ssh_vps "cd $VPS_DIR && docker compose ps --format 'table {{.Name}}\t{{.Status}}'"
  echo
  ok "Deployment verification complete"
  echo
  echo "  Matrix:  https://matrix.$SERVER_NAME"
  echo "  Element: https://element.$SERVER_NAME"
}

# --- Backup ---

run_backup() {
  info "Running backup on VPS"
  ssh_vps "cd $VPS_DIR && bash scripts/backup-to-git.sh"
  ok "Backup complete"
}

# --- Main ---

main() {
  local cmd="${1:-help}"

  case "$cmd" in
    setup)
      check_prereqs
      copy_files
      generate_env
      generate_element_config
      start_continuwuity
      register_admin
      configure_bridges
      start_all
      verify
      ;;
    deploy)
      check_prereqs
      copy_files
      generate_element_config
      info "Rebuilding and restarting services"
      vps_compose "up -d --build --pull always"
      verify
      ;;
    configure)
      configure_bridges
      start_all
      ;;
    backup)
      run_backup
      ;;
    verify)
      verify
      ;;
    superbridge)
      info "Running superbridge setup"
      "${SCRIPT_DIR}/superbridge.sh" "${@:2}"
      ;;
    help|--help|-h|*)
      echo "Usage: $0 {setup|deploy|configure|backup|verify|superbridge}"
      echo
      echo "Commands:"
      echo "  setup       — First-time setup: copy files, generate tokens, start services, register admin"
      echo "  deploy      — Update: copy changed files, rebuild and restart services"
      echo "  configure   — Only configure bridges (patch homeserver URL and permissions)"
      echo "  backup      — Run backup script on the VPS"
      echo "  verify      — Check services are running"
      echo "  superbridge — Run superbridge.sh commands (create-room, invite-bots, etc.)"
      exit 1
      ;;
  esac
}

main "$@"
