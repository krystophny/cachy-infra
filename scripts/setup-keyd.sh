#!/bin/bash
# Install and configure keyd for Mac-like keybindings
# Requires root

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../config/keyd"

log() { echo "[keyd] $*"; }
ok()  { echo "[keyd] OK: $*"; }
err() { echo "[keyd] ERROR: $*" >&2; }

# Must run as root
if [[ $EUID -ne 0 ]]; then
    err "This script must be run as root (use sudo)"
    exit 1
fi

# Install keyd if not present
if ! command -v keyd &>/dev/null; then
    log "Installing keyd..."
    pacman -S --noconfirm keyd
fi

# Copy config
log "Installing keyd config..."
mkdir -p /etc/keyd
cp "$CONFIG_DIR/default.conf" /etc/keyd/default.conf

# Enable and start service
log "Enabling keyd service..."
systemctl enable keyd
systemctl restart keyd

ok "Mac-like keybindings active"
echo ""
echo "Key mappings:"
echo "  Meta (Win) -> Alt (for Cmd+key shortcuts)"
echo "  Capslock   -> Control"
echo "  Control    -> Escape"
echo "  Escape     -> Backtick"
echo ""
echo "  Cmd+C/V/X  -> Copy/Paste/Cut"
echo "  Cmd+Z/S/A  -> Undo/Save/Select All"
echo "  Cmd+T/W/N  -> New Tab/Close Tab/New Window"
