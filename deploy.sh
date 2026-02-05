#!/usr/bin/env bash
set -euo pipefail

# Matrix Superbridge — GCE Deployment Helper
# Usage: ./deploy.sh [step]
#   Steps: check | infra | configure | deploy | all

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/terraform"
ANSIBLE_DIR="$SCRIPT_DIR/matrix-docker-ansible-deploy"
ENV_FILE="$SCRIPT_DIR/.env.production"
ENV_LOCAL="$SCRIPT_DIR/.env.local"
VAULT_FILE="$SCRIPT_DIR/production-vault.yml"
VAULT_PASSWORD_FILE="$SCRIPT_DIR/.vault-password"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# --- Step: check prerequisites ---
step_check() {
  info "Checking prerequisites..."
  local missing=0

  for cmd in gcloud terraform ansible-playbook ansible-vault pwgen ssh; do
    if ! command -v "$cmd" &>/dev/null; then
      error "Missing: $cmd"
      missing=1
    fi
  done

  if [ ! -f ~/.ssh/id_ed25519.pub ]; then
    error "Missing SSH key: ~/.ssh/id_ed25519.pub"
    missing=1
  fi

  if [ ! -f "$VAULT_PASSWORD_FILE" ]; then
    error "Missing vault password file: $VAULT_PASSWORD_FILE"
    echo "  Ask a teammate for the vault key, or generate a new one with:"
    echo "  pwgen -s 48 1 > .vault-password && chmod 600 .vault-password"
    missing=1
  fi

  # Check GCP auth
  if ! gcloud auth application-default print-access-token &>/dev/null 2>&1; then
    warn "GCP application-default credentials not set. Run:"
    echo "  gcloud auth application-default login"
    missing=1
  fi

  # Check project access
  if ! gcloud projects describe hashtag-xdeca &>/dev/null 2>&1; then
    warn "Cannot access GCP project hashtag-xdeca. Check permissions."
    missing=1
  fi

  if [ "$missing" -eq 1 ]; then
    error "Prerequisites not met. Fix the above issues and retry."
    return 1
  fi

  info "All prerequisites OK."
}

# --- Step: infra (terraform) ---
step_infra() {
  info "Provisioning GCE infrastructure..."
  cd "$TERRAFORM_DIR"

  if [ ! -d .terraform ]; then
    info "Running terraform init..."
    terraform init
  fi

  terraform plan -out=tfplan
  echo ""
  read -rp "Apply this plan? (y/N) " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    terraform apply tfplan
    rm -f tfplan
  else
    info "Aborted."
    rm -f tfplan
    return 1
  fi

  echo ""
  info "Infrastructure created. Outputs:"
  terraform output
}

# --- Helper: read a YAML value from a decrypted vault temp file ---
read_vault_var() {
  local file="$1" key="$2"
  grep "^${key}:" "$file" | sed "s/^${key}: *'\\{0,1\\}//;s/'$//"
}

# --- Step: configure (fill in Ansible vars from Terraform outputs) ---
step_configure() {
  info "Configuring Ansible for production..."
  cd "$TERRAFORM_DIR"

  local external_ip sslip_domain
  external_ip=$(terraform output -raw external_ip)
  sslip_domain=$(terraform output -raw sslip_domain)

  if [ -z "$external_ip" ]; then
    error "Could not read terraform outputs. Run 'step_infra' first."
    return 1
  fi

  info "External IP: $external_ip"
  info "sslip.io domain: $sslip_domain"

  # Read Telegram API credentials from .env.local
  local telegram_api_id telegram_api_hash
  if [ -f "$ENV_LOCAL" ]; then
    telegram_api_id=$(grep '^TELEGRAM_API_ID=' "$ENV_LOCAL" | cut -d= -f2)
    telegram_api_hash=$(grep '^TELEGRAM_API_HASH=' "$ENV_LOCAL" | cut -d= -f2)
  fi
  if [ -z "${telegram_api_id:-}" ] || [ -z "${telegram_api_hash:-}" ]; then
    error "Could not read TELEGRAM_API_ID/TELEGRAM_API_HASH from $ENV_LOCAL"
    return 1
  fi

  # Read existing secrets from vault if it exists, otherwise generate new ones
  local homeserver_secret postgres_password nick_password angie_password
  if [ -f "$VAULT_FILE" ]; then
    info "Reading existing secrets from encrypted vault..."
    local tmpvault
    tmpvault=$(mktemp)
    ansible-vault decrypt "$VAULT_FILE" --vault-password-file "$VAULT_PASSWORD_FILE" --output "$tmpvault"
    homeserver_secret=$(read_vault_var "$tmpvault" vault_homeserver_secret)
    postgres_password=$(read_vault_var "$tmpvault" vault_postgres_password)
    nick_password=$(read_vault_var "$tmpvault" vault_nick_password)
    angie_password=$(read_vault_var "$tmpvault" vault_angie_password)
    rm -f "$tmpvault"
    warn "Reusing existing secrets from vault. Delete production-vault.yml to regenerate."
  else
    homeserver_secret=$(pwgen -s 64 1)
    postgres_password=$(pwgen -s 32 1)
    nick_password=$(pwgen -s 16 1)
    angie_password=$(pwgen -s 16 1)
    info "Generated fresh secrets."
  fi

  # Create/update the encrypted vault file
  local tmpvault
  tmpvault=$(mktemp)
  cat > "$tmpvault" <<EOF
---
# Matrix Production Secrets — encrypted with Ansible Vault
# Decrypt: ansible-vault decrypt production-vault.yml --vault-password-file .vault-password
# Edit:    ansible-vault edit production-vault.yml --vault-password-file .vault-password

vault_homeserver_secret: '$homeserver_secret'
vault_postgres_password: '$postgres_password'
vault_nick_password: '$nick_password'
vault_angie_password: '$angie_password'
vault_telegram_api_id: '$telegram_api_id'
vault_telegram_api_hash: '$telegram_api_hash'
EOF
  ansible-vault encrypt "$tmpvault" --vault-password-file "$VAULT_PASSWORD_FILE" --output "$VAULT_FILE"
  rm -f "$tmpvault"
  info "Updated encrypted vault: $VAULT_FILE"

  # Update .env.production (non-secret reference file)
  cat > "$ENV_FILE" <<EOF
# Matrix Production Configuration (GCE) — auto-populated by deploy.sh
# Secrets are stored in production-vault.yml (encrypted with Ansible Vault)
EXTERNAL_IP=$external_ip
SSLIP_DOMAIN=$sslip_domain

# URLs
MATRIX_URL=https://matrix.$sslip_domain
ELEMENT_URL=https://element.$sslip_domain
SYNAPSE_ADMIN_URL=https://synapse-admin.$sslip_domain

# Users
MATRIX_NICK_USER=nick
MATRIX_ANGIE_USER=angie
EOF
  info "Updated $ENV_FILE"

  # Update Ansible inventory
  local ip_dashes="${external_ip//./-}"
  local hosts_file="$ANSIBLE_DIR/inventory/hosts-production"

  cat > "$hosts_file" <<EOF
# Production GCE instance — auto-populated by deploy.sh
[matrix_servers]
matrix.${ip_dashes}.sslip.io ansible_host=$external_ip ansible_port=22 ansible_ssh_user=nick ansible_become=true ansible_become_user=root ansible_python_interpreter=/usr/bin/python3 ansible_ssh_private_key_file=~/.ssh/id_ed25519
EOF
  info "Updated $hosts_file"

  # Update Ansible vars (directory must match inventory hostname)
  local vars_dir="$ANSIBLE_DIR/inventory/host_vars/matrix.${ip_dashes}.sslip.io"
  mkdir -p "$vars_dir"
  local vars_file="$vars_dir/vars.yml"

  cat > "$vars_file" <<VARS
---
# Matrix Production Configuration (GCE) — auto-populated by deploy.sh
# Secrets are in vault.yml (encrypted with Ansible Vault)

matrix_domain: "$sslip_domain"
matrix_homeserver_implementation: synapse

# Secrets (from vault)
matrix_homeserver_generic_secret_key: "{{ vault_homeserver_secret }}"
postgres_connection_password: "{{ vault_postgres_password }}"

# Reverse proxy — Traefik with self-signed SSL
matrix_playbook_reverse_proxy_type: playbook-managed-traefik
traefik_config_certificatesResolvers_acme_enabled: false
traefik_config_entrypoint_web_secure_tls_enabled: true
matrix_playbook_ssl_enabled: true
traefik_ssl_test: true

devture_systemd_docker_base_ipv6_enabled: false

# COTURN
matrix_coturn_turn_external_ip_address: '$external_ip'

# Clients
matrix_client_element_enabled: true
matrix_synapse_admin_enabled: true

# Admin users (created on deploy via ensure-matrix-users-created tag)
# Add users here; passwords are initial-only (won't update existing users)
matrix_user_creator_users_additional:
  - username: nick
    initial_password: "{{ vault_nick_password }}"
    initial_type: admin
  - username: angie
    initial_password: "{{ vault_angie_password }}"
    initial_type: admin

# Security
matrix_synapse_enable_registration: false
matrix_synapse_federation_enabled: true
matrix_static_files_container_labels_base_domain_enabled: true

# Bridges
matrix_appservice_double_puppet_enabled: true
matrix_mautrix_discord_enabled: true
matrix_mautrix_telegram_enabled: true
matrix_mautrix_telegram_api_id: "{{ vault_telegram_api_id }}"
matrix_mautrix_telegram_api_hash: "{{ vault_telegram_api_hash }}"
VARS
  info "Updated $vars_file"

  # Copy encrypted vault to host_vars directory
  cp "$VAULT_FILE" "$vars_dir/vault.yml"
  info "Copied encrypted vault to $vars_dir/vault.yml"

  echo ""
  info "Configuration complete. Review the files, then run: ./deploy.sh deploy"
}

# --- Step: deploy (Ansible) ---
step_deploy() {
  info "Deploying Matrix server via Ansible..."

  if [ ! -f "$VAULT_PASSWORD_FILE" ]; then
    error "Missing vault password file: $VAULT_PASSWORD_FILE"
    return 1
  fi

  # Quick SSH connectivity check
  cd "$TERRAFORM_DIR"
  local external_ip
  external_ip=$(terraform output -raw external_ip)

  info "Testing SSH connectivity to $external_ip..."
  if ! ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "nick@$external_ip" "echo 'SSH OK'" 2>/dev/null; then
    error "Cannot SSH to $external_ip. The instance may still be booting — wait a minute and retry."
    return 1
  fi

  # Ensure vault is copied to host_vars
  local ip_dashes="${external_ip//./-}"
  local vars_dir="$ANSIBLE_DIR/inventory/host_vars/matrix.${ip_dashes}.sslip.io"
  if [ -f "$VAULT_FILE" ] && [ -d "$vars_dir" ]; then
    cp "$VAULT_FILE" "$vars_dir/vault.yml"
  fi

  cd "$ANSIBLE_DIR"
  ansible-playbook -i inventory/hosts-production setup.yml \
    --vault-password-file "$VAULT_PASSWORD_FILE" \
    --tags=setup-all,ensure-matrix-users-created,start

  echo ""
  info "Deployment complete!"
  info "Next steps:"
  info "  1. Accept self-signed cert at: https://matrix.$(terraform -chdir="$TERRAFORM_DIR" output -raw sslip_domain)/_matrix/client/versions"
  info "  2. Open Element at: https://element.$(terraform -chdir="$TERRAFORM_DIR" output -raw sslip_domain)"
}

# --- Main ---
case "${1:-}" in
  check)     step_check ;;
  infra)     step_check && step_infra ;;
  configure) step_configure ;;
  deploy)    step_deploy ;;
  all)       step_check && step_infra && step_configure && step_deploy ;;
  *)
    echo "Usage: $0 {check|infra|configure|deploy|all}"
    echo ""
    echo "Steps:"
    echo "  check      — Verify prerequisites (gcloud, terraform, ansible, ssh key)"
    echo "  infra      — Provision GCE instance via Terraform"
    echo "  configure  — Auto-populate Ansible vars from Terraform outputs"
    echo "  deploy     — Run Ansible playbook against production"
    echo "  all        — Run all steps in sequence"
    exit 1
    ;;
esac
