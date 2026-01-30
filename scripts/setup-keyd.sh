#!/bin/bash
# Install and configure keyd for Mac-like keybindings
# Also sets up natural scrolling (Mac-style inverted scroll)
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

# Set up natural scrolling
log "Installing natural scrolling config..."
cp "$SCRIPT_DIR/../config/X11/30-natural-scrolling.conf" /etc/X11/xorg.conf.d/

ok "Mac-like keybindings active"
ok "Natural scrolling enabled (requires logout/restart)"
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
echo ""
echo "Mouse:"
echo "  Natural scrolling (inverted wheel)"
