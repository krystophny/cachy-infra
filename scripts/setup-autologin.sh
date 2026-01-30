#!/bin/bash
# Configure auto-login for LightDM on CachyOS
# Idempotent - safe to run multiple times
# Requires root

set -euo pipefail

TARGET_USER="${1:-ert}"
LIGHTDM_CONF="/etc/lightdm/lightdm.conf"

log() { echo "[autologin] $*"; }
ok()  { echo "[autologin] OK: $*"; }
err() { echo "[autologin] ERROR: $*" >&2; }

# Must run as root
if [[ $EUID -ne 0 ]]; then
    err "This script must be run as root (use sudo)"
    exit 1
fi

# Verify LightDM is installed
if ! command -v lightdm &>/dev/null; then
    err "LightDM is not installed"
    exit 1
fi

# Verify user exists
if ! id "$TARGET_USER" &>/dev/null; then
    err "User $TARGET_USER does not exist"
    exit 1
fi

# Create autologin group if it doesn't exist
if ! getent group autologin &>/dev/null; then
    log "Creating autologin group..."
    groupadd -r autologin
    ok "Created autologin group"
else
    ok "autologin group exists"
fi

# Add user to autologin group
if ! groups "$TARGET_USER" | grep -q '\bautologin\b'; then
    log "Adding $TARGET_USER to autologin group..."
    usermod -aG autologin "$TARGET_USER"
    ok "Added $TARGET_USER to autologin group"
else
    ok "$TARGET_USER already in autologin group"
fi

# Configure LightDM for auto-login
log "Configuring LightDM..."

# Backup config if not already backed up
if [[ -f "$LIGHTDM_CONF" ]] && [[ ! -f "$LIGHTDM_CONF.original" ]]; then
    cp "$LIGHTDM_CONF" "$LIGHTDM_CONF.original"
    log "Backed up original lightdm.conf"
fi

# Check if autologin is already configured correctly
if grep -q "^autologin-user=$TARGET_USER" "$LIGHTDM_CONF" 2>/dev/null; then
    ok "Auto-login already configured for $TARGET_USER"
else
    # Update or add autologin settings in [Seat:*] section
    if grep -q '^\[Seat:\*\]' "$LIGHTDM_CONF"; then
        # Section exists, update/add settings
        # Remove any existing autologin-user line first
        sed -i '/^autologin-user=/d' "$LIGHTDM_CONF"
        sed -i '/^autologin-user-timeout=/d' "$LIGHTDM_CONF"
        # Add after [Seat:*]
        sed -i '/^\[Seat:\*\]/a autologin-user-timeout=0' "$LIGHTDM_CONF"
        sed -i '/^\[Seat:\*\]/a autologin-user='"$TARGET_USER" "$LIGHTDM_CONF"
    else
        # Add section if missing
        echo "" >> "$LIGHTDM_CONF"
        echo "[Seat:*]" >> "$LIGHTDM_CONF"
        echo "autologin-user=$TARGET_USER" >> "$LIGHTDM_CONF"
        echo "autologin-user-timeout=0" >> "$LIGHTDM_CONF"
    fi
    ok "Configured auto-login for $TARGET_USER"
fi

ok "Auto-login setup complete"
log "Changes take effect on next reboot"
