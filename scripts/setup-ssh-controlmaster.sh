#!/bin/bash
# Ensure SSH ControlMaster defaults are managed in chezmoi (single source of truth).
# Idempotent - safe to run multiple times.

set -euo pipefail

TARGET_USER="${1:-$(whoami)}"

ok()  { echo "[ssh-controlmaster] OK: $*"; }
err() { echo "[ssh-controlmaster] ERROR: $*" >&2; }

if [[ "$(whoami)" != "$TARGET_USER" ]]; then
    err "Run as user $TARGET_USER"
    exit 1
fi

if ! command -v chezmoi >/dev/null 2>&1; then
    err "chezmoi is not installed"
    exit 1
fi

SOURCE_DIR="$(chezmoi source-path)"
SSH_SOURCE_DIR="$SOURCE_DIR/dot_ssh"
SSH_CONFIG_SOURCE="$SSH_SOURCE_DIR/private_config"
START_MARK="# cachy-infra: ssh-controlmaster begin"
END_MARK="# cachy-infra: ssh-controlmaster end"

for legacy_source in "$SOURCE_DIR/dot_ssh/config" "$SOURCE_DIR/private_dot_ssh/config"; do
    if [[ -f "$legacy_source" ]]; then
        mkdir -p "$SSH_SOURCE_DIR"
        if [[ ! -f "$SSH_CONFIG_SOURCE" ]]; then
            mv "$legacy_source" "$SSH_CONFIG_SOURCE"
            ok "Migrated legacy chezmoi source path: $legacy_source -> $SSH_CONFIG_SOURCE"
        else
            rm -f "$legacy_source"
            ok "Removed duplicate legacy chezmoi source path: $legacy_source"
        fi
    fi
done
rmdir "$SOURCE_DIR/private_dot_ssh" >/dev/null 2>&1 || true

mkdir -p "$SSH_SOURCE_DIR"
touch "$SSH_CONFIG_SOURCE"

tmp="$(mktemp)"
awk -v s="$START_MARK" -v e="$END_MARK" '
    $0 == s { skip=1; next }
    $0 == e { skip=0; next }
    !skip { print }
' "$SSH_CONFIG_SOURCE" > "$tmp"

if [[ -s "$tmp" ]]; then
    printf "\n" >> "$tmp"
fi

cat >> "$tmp" << 'EOF'
# cachy-infra: ssh-controlmaster begin
Host *
    ControlMaster auto
    ControlPath ~/.ssh/cm-%C
    ControlPersist 8h
# cachy-infra: ssh-controlmaster end
EOF

mv "$tmp" "$SSH_CONFIG_SOURCE"
ok "Updated chezmoi source: $SSH_CONFIG_SOURCE"

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

chezmoi apply --force ~/.ssh/config
ok "Applied chezmoi for ~/.ssh/config"
