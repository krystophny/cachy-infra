#!/bin/bash
# Ensure tmux local-display defaults are managed in chezmoi (single source of truth).
# Idempotent - safe to run multiple times.

set -euo pipefail

TARGET_USER="${1:-$(whoami)}"

log() { echo "[tmux-chezmoi] $*"; }
ok()  { echo "[tmux-chezmoi] OK: $*"; }
err() { echo "[tmux-chezmoi] ERROR: $*" >&2; }

if [[ "$(whoami)" != "$TARGET_USER" ]]; then
    err "Run as user $TARGET_USER"
    exit 1
fi

if ! command -v chezmoi >/dev/null 2>&1; then
    err "chezmoi is not installed"
    exit 1
fi

SOURCE_DIR="$(chezmoi source-path)"
TMUX_SOURCE="$SOURCE_DIR/dot_tmux.conf"
START_MARK="# cachy-infra: tmux-local-display begin"
END_MARK="# cachy-infra: tmux-local-display end"
USER_UID="$(id -u)"
USER_HOME="${HOME}"

mkdir -p "$SOURCE_DIR"
touch "$TMUX_SOURCE"

tmp="$(mktemp)"
awk -v s="$START_MARK" -v e="$END_MARK" '
    $0 == s { skip=1; next }
    $0 == e { skip=0; next }
    !skip { print }
' "$TMUX_SOURCE" > "$tmp"

tmp_clean="$(mktemp)"
grep -vF 'set -ga update-environment "XDG_RUNTIME_DIR WAYLAND_DISPLAY"' "$tmp" \
    | grep -vF "run-shell 'tmux set-environment -g DISPLAY \"\${DISPLAY:-:0}\";" \
    | grep -vF "set-hook -g client-attached 'run-shell \"tmux set-environment -g DISPLAY" \
    | grep -vF '# Keep GUI launching from tmux working even when the attaching client' \
    | grep -vF '# does not export DISPLAY/XAUTHORITY (common with SSH or tty login).' \
    > "$tmp_clean"
mv "$tmp_clean" "$tmp"

if [[ -s "$tmp" ]]; then
    printf "\n" >> "$tmp"
fi

cat >> "$tmp" << EOF
# cachy-infra: tmux-local-display begin

# Keep local GUI apps working from tmux panes even when client env is sparse.
set-environment -g DISPLAY ":0"
set-environment -g XAUTHORITY "${USER_HOME}/.Xauthority"
set-environment -g XDG_RUNTIME_DIR "/run/user/${USER_UID}"

# Keep dynamic vars, but do not clear DISPLAY/XAUTHORITY on attach.
set -g update-environment "SSH_ASKPASS SSH_AUTH_SOCK SSH_AGENT_PID SSH_CONNECTION WINDOWID XDG_RUNTIME_DIR WAYLAND_DISPLAY"
# cachy-infra: tmux-local-display end
EOF

mv "$tmp" "$TMUX_SOURCE"
ok "Updated chezmoi source: $TMUX_SOURCE"

chezmoi apply ~/.tmux.conf
ok "Applied chezmoi for ~/.tmux.conf"

if tmux ls >/dev/null 2>&1; then
    tmux set-environment -g DISPLAY ":0"
    tmux set-environment -g XAUTHORITY "$HOME/.Xauthority"
    tmux set-environment -g XDG_RUNTIME_DIR "/run/user/$(id -u)"
    tmux set-option -g update-environment "SSH_ASKPASS SSH_AUTH_SOCK SSH_AGENT_PID SSH_CONNECTION WINDOWID XDG_RUNTIME_DIR WAYLAND_DISPLAY" || true
    ok "Updated running tmux server environment"
fi
