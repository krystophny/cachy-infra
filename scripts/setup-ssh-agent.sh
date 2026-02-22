#!/bin/bash
# Enable ssh-agent via systemd user socket and configure SSH to use it.
# Adds AddKeysToAgent and ForwardAgent to SSH config via chezmoi.
# Idempotent - safe to run multiple times.

set -euo pipefail

TARGET_USER="${1:-$(whoami)}"

ok()  { echo "[ssh-agent] OK: $*"; }
err() { echo "[ssh-agent] ERROR: $*" >&2; }

if [[ "$(whoami)" != "$TARGET_USER" ]]; then
    err "Run as user $TARGET_USER"
    exit 1
fi

if ! command -v chezmoi >/dev/null 2>&1; then
    err "chezmoi is not installed"
    exit 1
fi

# 1. Enable and start ssh-agent via systemd user socket
systemctl --user enable ssh-agent.socket
systemctl --user start ssh-agent.socket
ok "ssh-agent.socket enabled and started"

# 2. Ensure SSH_AUTH_SOCK is set in shell profile for non-systemd contexts
SOURCE_DIR="$(chezmoi source-path)"
BASHRC_SOURCE="$SOURCE_DIR/dot_bashrc"
START_MARK="# cachy-infra: ssh-agent begin"
END_MARK="# cachy-infra: ssh-agent end"

touch "$BASHRC_SOURCE"

tmp="$(mktemp)"
awk -v s="$START_MARK" -v e="$END_MARK" '
    $0 == s { skip=1; next }
    $0 == e { skip=0; next }
    !skip { print }
' "$BASHRC_SOURCE" > "$tmp"

if [[ -s "$tmp" ]]; then
    printf "\n" >> "$tmp"
fi

cat >> "$tmp" << 'EOF'
# cachy-infra: ssh-agent begin
export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR}/ssh-agent.socket"
# cachy-infra: ssh-agent end
EOF

mv "$tmp" "$BASHRC_SOURCE"
ok "Updated chezmoi source: $BASHRC_SOURCE"

chezmoi apply --force ~/.bashrc
ok "Applied chezmoi for ~/.bashrc"

# 3. Add AddKeysToAgent and ForwardAgent to SSH config
SSH_SOURCE_DIR="$SOURCE_DIR/dot_ssh"
SSH_CONFIG_SOURCE="$SSH_SOURCE_DIR/private_config"
SSH_START_MARK="# cachy-infra: ssh-agent-config begin"
SSH_END_MARK="# cachy-infra: ssh-agent-config end"

mkdir -p "$SSH_SOURCE_DIR"
touch "$SSH_CONFIG_SOURCE"

tmp="$(mktemp)"
awk -v s="$SSH_START_MARK" -v e="$SSH_END_MARK" '
    $0 == s { skip=1; next }
    $0 == e { skip=0; next }
    !skip { print }
' "$SSH_CONFIG_SOURCE" > "$tmp"

if [[ -s "$tmp" ]]; then
    printf "\n" >> "$tmp"
fi

cat >> "$tmp" << 'EOF'
# cachy-infra: ssh-agent-config begin
Host *
    AddKeysToAgent yes
    ForwardAgent yes
# cachy-infra: ssh-agent-config end
EOF

mv "$tmp" "$SSH_CONFIG_SOURCE"
ok "Updated chezmoi source: $SSH_CONFIG_SOURCE"

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
chezmoi apply --force ~/.ssh/config
ok "Applied chezmoi for ~/.ssh/config"

echo
ok "SSH agent is ready. Run 'source ~/.bashrc' or start a new shell."
ok "First SSH to GitHub will auto-add your key (AddKeysToAgent yes)."
ok "ForwardAgent is enabled for all hosts."
