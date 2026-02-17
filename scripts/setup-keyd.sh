#!/bin/bash
# Install and configure keyd for Mac-like keybindings
# Also sets up natural scrolling (Mac-style inverted scroll)
# Requires root

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../config/keyd"
KEYD_CONFIG_DST="/etc/keyd/default.conf"
KEYD_CONFIG_SRC="$CONFIG_DIR/default.conf"

log() { echo "[keyd] $*"; }
ok()  { echo "[keyd] OK: $*"; }
err() { echo "[keyd] ERROR: $*" >&2; }

ensure_cut_mapping() {
    local file="$1"
    local tmp backup

    tmp="$(mktemp)"
    awk '
BEGIN { in_main = 0; done = 0 }
{
    if ($0 ~ /^\[main\][[:space:]]*$/) {
        in_main = 1
        print
        next
    }

    if (in_main && $0 ~ /^\[[^]]+\][[:space:]]*$/) {
        if (!done) {
            print "cut = f13"
            done = 1
        }
        in_main = 0
    }

    if (in_main && $0 ~ /^[[:space:]]*cut[[:space:]]*=/) {
        if (!done) {
            print "cut = f13"
            done = 1
        }
        next
    }

    print
}
END {
    if (in_main && !done) {
        print "cut = f13"
        done = 1
    }
    if (!done) {
        print ""
        print "[main]"
        print "cut = f13"
    }
}
' "$file" >"$tmp"

    if cmp -s "$file" "$tmp"; then
        rm -f "$tmp"
        log "Existing keyd config already has cut = f13"
        return 0
    fi

    backup="${file}.bak.$(date +%Y%m%d-%H%M%S)"
    cp "$file" "$backup"
    install -m 0644 "$tmp" "$file"
    rm -f "$tmp"
    ok "Updated $file (backup: $backup)"
}

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
if [[ ! -f "$KEYD_CONFIG_DST" ]]; then
    install -m 0644 "$KEYD_CONFIG_SRC" "$KEYD_CONFIG_DST"
    ok "Installed new keyd config at $KEYD_CONFIG_DST"
else
    ensure_cut_mapping "$KEYD_CONFIG_DST"
fi

# Enable and start service
log "Enabling keyd service..."
systemctl enable keyd
systemctl restart keyd

# Set up natural scrolling
log "Installing natural scrolling config..."
mkdir -p /etc/X11/xorg.conf.d
cp "$SCRIPT_DIR/../config/X11/30-natural-scrolling.conf" /etc/X11/xorg.conf.d/

# Set up fast keyboard repeat rate
log "Installing keyboard repeat rate config..."
cp "$SCRIPT_DIR/../config/X11/40-keyboard-repeat.conf" /etc/X11/xorg.conf.d/

ok "Mac-like keybindings active"
ok "Natural scrolling enabled (requires logout/restart)"
echo ""
echo "Key mappings:"
echo "  Meta (Win) -> Alt (for Cmd+key shortcuts)"
echo "  Capslock   -> Control"
echo "  Control    -> Escape"
echo "  Escape     -> Backtick"
echo "  Cut key    -> F13 (Sun keyboard compatible)"
echo ""
echo "  Cmd+C/V/X  -> Copy/Paste/Cut"
echo "  Cmd+Z/S/A  -> Undo/Save/Select All"
echo "  Cmd+T/W/N  -> New Tab/Close Tab/New Window"
echo ""
echo "Mouse:"
echo "  Natural scrolling (inverted wheel)"
echo ""
echo "Keyboard:"
echo "  Fast repeat (225ms delay, 30/s rate)"
