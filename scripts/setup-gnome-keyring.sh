#!/bin/bash
# Install gnome-keyring and configure PAM auto-unlock on TTY login
# Requires root

set -euo pipefail

log() { echo "[gnome-keyring] $*"; }
ok()  { echo "[gnome-keyring] OK: $*"; }
err() { echo "[gnome-keyring] ERROR: $*" >&2; }

if [[ $EUID -ne 0 ]]; then
    err "This script must be run as root (use sudo)"
    exit 1
fi

# ============================================
# 1. Install gnome-keyring
# ============================================
log "Installing gnome-keyring..."
if pacman -Q gnome-keyring &>/dev/null; then
    ok "gnome-keyring already installed"
else
    pacman -S --noconfirm gnome-keyring
    ok "gnome-keyring installed"
fi

# ============================================
# 2. Add PAM integration to /etc/pam.d/login
# ============================================
PAM_LOGIN="/etc/pam.d/login"

log "Configuring PAM auto-unlock in $PAM_LOGIN..."
if grep -q "pam_gnome_keyring.so" "$PAM_LOGIN"; then
    ok "PAM already configured"
else
    cp "$PAM_LOGIN" "$PAM_LOGIN.backup.$(date +%Y%m%d_%H%M%S)"

    # Insert -auth after the last auth line
    sed -i '/^auth.*system-local-login/a -auth      optional     pam_gnome_keyring.so' "$PAM_LOGIN"
    # Insert -session after the last session line
    sed -i '/^session.*system-local-login/a -session   optional     pam_gnome_keyring.so auto_start' "$PAM_LOGIN"

    ok "PAM auto-unlock configured"
fi

ok "gnome-keyring setup complete"
log "Keyring unlocks automatically with TTY login password"
log "Requires ~/.xinitrc to start gnome-keyring-daemon (managed by chezmoi)"
