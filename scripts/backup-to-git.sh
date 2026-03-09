#!/usr/bin/env bash
# Backup Matrix superbridge services to a git repo.
# Dumps configs and databases as plain text for meaningful diffs.
# Designed to run as a daily cron job on the GCE instance.
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-$HOME/matrix-backups}"
TMPDIR=$(mktemp -d)
TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M UTC")

cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

cd "$BACKUP_DIR"

# ── Bridge configs (YAML) ──────────────────────────────────────────
echo "Backing up bridge configs..."
mkdir -p matrix/bridge-configs
for bridge in discord signal whatsapp telegram; do
  volume="matrix_${bridge}_data"
  docker run --rm -v "$volume":/data alpine cat /data/config.yaml \
    > "matrix/bridge-configs/${bridge}.yaml" 2>/dev/null || true
  docker run --rm -v "$volume":/data alpine cat /data/registration.yaml \
    > "matrix/bridge-configs/${bridge}-registration.yaml" 2>/dev/null || true
done

# ── Bridge databases (SQLite → SQL text) ───────────────────────────
echo "Backing up bridge databases..."
mkdir -p matrix/bridge-dbs
# Each bridge has a different db filename
declare -A BRIDGE_DBS=(
  [discord]="discord.db"
  [signal]="signal.db"
  [whatsapp]="whatsapp.db"
  [telegram]="mautrix-telegram.db"
)
for bridge in "${!BRIDGE_DBS[@]}"; do
  db="${BRIDGE_DBS[$bridge]}"
  volume="matrix_${bridge}_data"
  docker run --rm --user "$(id -u):$(id -g)" -v "$volume":/data -v "$TMPDIR":/out alpine \
    cp "/data/$db" "/out/${bridge}.db" 2>/dev/null || continue
  sqlite3 "$TMPDIR/${bridge}.db" .dump \
    > "matrix/bridge-dbs/${bridge}.sql" 2>/dev/null || true
done

# Telegram has a second db (telegram.db = Telegram native cache)
docker run --rm --user "$(id -u):$(id -g)" -v matrix_telegram_data:/data -v "$TMPDIR":/out alpine \
  cp /data/telegram.db /out/telegram-cache.db 2>/dev/null || true
if [ -f "$TMPDIR/telegram-cache.db" ]; then
  sqlite3 "$TMPDIR/telegram-cache.db" .dump \
    > matrix/bridge-dbs/telegram-cache.sql 2>/dev/null || true
fi

# ── Relay bot database (SQLite → SQL text) ─────────────────────────
echo "Backing up relay bot database..."
mkdir -p matrix
docker run --rm --user "$(id -u):$(id -g)" -v matrix_relay_data:/data -v "$TMPDIR":/out alpine \
  cp /data/relay.db /out/relay.db 2>/dev/null || true
if [ -f "$TMPDIR/relay.db" ]; then
  sqlite3 "$TMPDIR/relay.db" .dump > matrix/relay.sql 2>/dev/null || true
fi

# ── Commit and push ────────────────────────────────────────────────
echo "Committing..."
git add -A

if git diff --cached --quiet; then
  echo "No changes to back up."
  exit 0
fi

git commit -m "backup: $TIMESTAMP"
git push

echo "Backup complete: $TIMESTAMP"
