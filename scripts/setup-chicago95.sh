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
    yay -S --noconfirm --needed chicago95-gtk-theme-git chicago95-icon-theme-git xcursor-chicago95-git
    ok "Chicago95 installed"
else
    ok "Chicago95 already installed"
fi

# Install Helvetica bitmap font (works better than Tahoma with modern Pango)
# Downloaded from Chicago95 GitHub - fixes kerning issues with Pango 1.44+
log "Checking Helvetica bitmap font..."
FONT_DIR="$USER_HOME/.local/share/fonts/cronyx-cyrillic"
if [[ ! -d "$FONT_DIR" ]]; then
    log "Downloading Helvetica bitmap font from Chicago95..."
    TMPDIR=$(mktemp -d)
    curl -sL "https://github.com/grassmunk/Chicago95/archive/refs/heads/master.tar.gz" | \
        tar -xz -C "$TMPDIR" --strip-components=3 "Chicago95-master/Fonts/bitmap/cronyx-cyrillic"
    mkdir -p "$USER_HOME/.local/share/fonts"
    mv "$TMPDIR/cronyx-cyrillic" "$USER_HOME/.local/share/fonts/"
    rm -rf "$TMPDIR"
    fc-cache -f "$USER_HOME/.local/share/fonts"
    ok "Helvetica bitmap font installed"
else
    ok "Helvetica bitmap font already installed"
fi

# Kill xfconfd if running so config changes take effect
if pgrep -x xfconfd &>/dev/null; then
    log "Stopping xfconfd to apply config..."
    pkill xfconfd || true
    sleep 1
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
