#!/bin/bash
# Setup Chicago95 theme for XFCE on CachyOS
# Idempotent - safe to run multiple times

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$REPO_DIR/config"
TARGET_USER="${1:-ert}"
USER_HOME="/home/$TARGET_USER"

log() { echo "[chicago95] $*"; }
ok()  { echo "[chicago95] OK: $*"; }
err() { echo "[chicago95] ERROR: $*" >&2; }

# Check if running as appropriate user
if [[ $EUID -eq 0 ]]; then
    err "Do not run as root. Run as the target user."
    exit 1
fi

if [[ "$(whoami)" != "$TARGET_USER" ]]; then
    err "Run as user $TARGET_USER"
    exit 1
fi

# Install Chicago95 via yay if not already installed
log "Checking Chicago95 installation..."
if ! pacman -Qi chicago95-gtk-theme-git &>/dev/null; then
    log "Installing Chicago95 theme via yay..."
    yay -S --noconfirm --needed chicago95-gtk-theme-git chicago95-icon-theme-git
    ok "Chicago95 installed"
else
    ok "Chicago95 already installed"
fi

# Install Tahoma font (MS Web Core Fonts) if available
log "Checking fonts..."
if ! pacman -Qi ttf-ms-win10-auto &>/dev/null && ! pacman -Qi ttf-ms-fonts &>/dev/null; then
    if yay -Ss ttf-ms-win10-auto &>/dev/null; then
        log "Installing MS fonts for Tahoma..."
        yay -S --noconfirm --needed ttf-ms-win10-auto 2>/dev/null || true
    fi
fi

# Create XFCE config directories
log "Setting up XFCE configuration..."
mkdir -p "$USER_HOME/.config/xfce4/xfconf/xfce-perchannel-xml"

# Backup existing config if present and different
backup_if_different() {
    local src="$1"
    local dst="$2"
    if [[ -f "$dst" ]]; then
        if ! diff -q "$src" "$dst" &>/dev/null; then
            local backup="$dst.backup.$(date +%Y%m%d_%H%M%S)"
            cp "$dst" "$backup"
            log "Backed up $dst to $backup"
        fi
    fi
}

# Copy XFCE configuration files
for xml_file in "$CONFIG_DIR/xfce4/xfconf/xfce-perchannel-xml/"*.xml; do
    if [[ -f "$xml_file" ]]; then
        filename=$(basename "$xml_file")
        dst="$USER_HOME/.config/xfce4/xfconf/xfce-perchannel-xml/$filename"
        backup_if_different "$xml_file" "$dst"
        cp "$xml_file" "$dst"
        log "Installed $filename"
    fi
done

# Copy helpers.rc
if [[ -f "$CONFIG_DIR/xfce4/helpers.rc" ]]; then
    dst="$USER_HOME/.config/xfce4/helpers.rc"
    backup_if_different "$CONFIG_DIR/xfce4/helpers.rc" "$dst"
    cp "$CONFIG_DIR/xfce4/helpers.rc" "$dst"
    log "Installed helpers.rc"
fi

ok "Chicago95 theme configured"
log "NOTE: Log out and back in (or restart XFCE) for changes to take effect"
