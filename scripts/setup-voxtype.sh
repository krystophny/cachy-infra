#!/bin/bash
# Install and configure Voxtype for a target user
# Must run as the target user (not root)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="$SCRIPT_DIR/../config/voxtype/config.toml"
WP_CONFIG_SRC="$SCRIPT_DIR/../config/wireplumber/51-no-suspend.conf"
TARGET_USER="${1:-$USER}"

log() { echo "[voxtype] $*"; }
ok()  { echo "[voxtype] OK: $*"; }
err() { echo "[voxtype] ERROR: $*" >&2; }

if [[ $EUID -eq 0 ]]; then
    err "Run this script as the target user, not root"
    exit 1
fi

if [[ "$USER" != "$TARGET_USER" ]]; then
    err "Current user ($USER) does not match target user ($TARGET_USER)"
    exit 1
fi

if [[ ! -f "$CONFIG_SRC" ]]; then
    err "Missing config source: $CONFIG_SRC"
    exit 1
fi

if ! command -v yay &>/dev/null; then
    err "yay is required but not installed"
    exit 1
fi

required_packages=(voxtype ydotool wtype wl-clipboard xclip)
missing_packages=()
for pkg in "${required_packages[@]}"; do
    if ! pacman -Qi "$pkg" &>/dev/null; then
        missing_packages+=("$pkg")
    fi
done

if [[ ${#missing_packages[@]} -gt 0 ]]; then
    log "Installing required packages: ${missing_packages[*]}"
    yay -S --noconfirm --needed "${missing_packages[@]}"
else
    log "Required packages already installed: ${required_packages[*]}"
fi

TARGET_CONFIG_DIR="$HOME/.config/voxtype"
TARGET_CONFIG_FILE="$TARGET_CONFIG_DIR/config.toml"

mkdir -p "$TARGET_CONFIG_DIR"
if [[ -f "$TARGET_CONFIG_FILE" ]]; then
    backup="$TARGET_CONFIG_FILE.bak.$(date +%Y%m%d-%H%M%S)"
    cp "$TARGET_CONFIG_FILE" "$backup"
    log "Backed up existing config to $backup"
fi

install -m 0644 "$CONFIG_SRC" "$TARGET_CONFIG_FILE"
ok "Installed voxtype config to $TARGET_CONFIG_FILE"

if [[ -f "$WP_CONFIG_SRC" ]]; then
    WP_TARGET_DIR="$HOME/.config/wireplumber/wireplumber.conf.d"
    WP_TARGET_FILE="$WP_TARGET_DIR/51-no-suspend.conf"
    mkdir -p "$WP_TARGET_DIR"
    install -m 0644 "$WP_CONFIG_SRC" "$WP_TARGET_FILE"
    ok "Installed WirePlumber no-suspend rule to $WP_TARGET_FILE"
else
    log "WirePlumber no-suspend config not found at $WP_CONFIG_SRC (skipping)"
fi

if systemctl --user list-unit-files 2>/dev/null | grep -q '^voxtype\.service'; then
    log "Configuring voxtype autostart on default.target..."
    # Move away from vendor WantedBy=graphical-session.target so voxtype also
    # starts in tty/non-graphical user sessions.
    systemctl --user disable voxtype.service >/dev/null 2>&1 || true
    systemctl --user add-wants default.target voxtype.service
    ok "voxtype.service linked to default.target"

    if systemctl --user is-active --quiet voxtype.service; then
        log "Restarting voxtype user service to apply updated config..."
        systemctl --user restart voxtype.service
        ok "voxtype.service restarted"
    else
        log "Starting voxtype user service..."
        systemctl --user start voxtype.service
        ok "voxtype.service started"
    fi
else
    log "voxtype.service not available in user systemd; skipping service setup"
fi

if systemctl --user list-unit-files 2>/dev/null | grep -q '^wireplumber\.service'; then
    log "Restarting wireplumber user service to apply no-suspend mic rule..."
    systemctl --user restart wireplumber.service
    ok "wireplumber.service restarted"
else
    log "wireplumber.service not available in user systemd; skipping restart"
fi

if systemctl --user list-unit-files 2>/dev/null | grep -q '^ydotool\.service'; then
    log "Enabling ydotool user service..."
    systemctl --user enable --now ydotool.service
    ok "ydotool.service enabled and started"
else
    log "ydotool.service not available in user systemd; skipping enable"
fi
