#!/bin/bash
# Remove plymouth from initramfs for faster boot
# Requires root

set -euo pipefail

log() { echo "[remove-plymouth] $*"; }
ok()  { echo "[remove-plymouth] OK: $*"; }
err() { echo "[remove-plymouth] ERROR: $*" >&2; }

# Must run as root
if [[ $EUID -ne 0 ]]; then
    err "This script must be run as root (use sudo)"
    exit 1
fi

MKINITCPIO_CONF="/etc/mkinitcpio.conf"

# Check if plymouth is in hooks
if ! grep -q "plymouth" "$MKINITCPIO_CONF"; then
    ok "Plymouth already removed from initramfs"
    exit 0
fi

# Backup config
if [[ ! -f "$MKINITCPIO_CONF.original" ]]; then
    cp "$MKINITCPIO_CONF" "$MKINITCPIO_CONF.original"
    log "Backed up original mkinitcpio.conf"
fi

# Remove plymouth from HOOKS
log "Removing plymouth from initramfs hooks..."
sed -i 's/ plymouth//' "$MKINITCPIO_CONF"

# Rebuild initramfs
log "Rebuilding initramfs (this may take a moment)..."
mkinitcpio -P

ok "Plymouth removed - boot will be faster"
