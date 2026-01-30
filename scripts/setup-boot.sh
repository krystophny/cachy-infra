#!/bin/bash
# Configure boot settings for CachyOS:
# - Set systemd-boot timeout to 0
# - Remove quiet/splash for text boot output
# Idempotent - safe to run multiple times
# Requires root

set -euo pipefail

LOADER_CONF="/boot/loader/loader.conf"
ENTRIES_DIR="/boot/loader/entries"

log() { echo "[boot] $*"; }
ok()  { echo "[boot] OK: $*"; }
err() { echo "[boot] ERROR: $*" >&2; }

# Must run as root
if [[ $EUID -ne 0 ]]; then
    err "This script must be run as root (use sudo)"
    exit 1
fi

# Verify systemd-boot is in use
if [[ ! -d "/boot/loader" ]]; then
    err "systemd-boot not found at /boot/loader"
    exit 1
fi

# ============================================
# 1. Set boot timeout to 0
# ============================================
log "Configuring boot loader timeout..."

if [[ -f "$LOADER_CONF" ]]; then
    # Backup if not already done
    if [[ ! -f "$LOADER_CONF.original" ]]; then
        cp "$LOADER_CONF" "$LOADER_CONF.original"
        log "Backed up original loader.conf"
    fi

    # Check current timeout
    if grep -q "^timeout 0$" "$LOADER_CONF"; then
        ok "Timeout already set to 0"
    else
        # Update timeout line or add it
        if grep -q "^timeout" "$LOADER_CONF"; then
            sed -i 's/^timeout.*/timeout 0/' "$LOADER_CONF"
        else
            echo "timeout 0" >> "$LOADER_CONF"
        fi
        ok "Set boot timeout to 0"
    fi
else
    # Create loader.conf
    cat > "$LOADER_CONF" << 'EOF'
timeout 0
console-mode max
editor no
EOF
    ok "Created loader.conf with timeout 0"
fi

# ============================================
# 2. Remove quiet and splash from kernel cmdline
# ============================================
log "Configuring kernel command line for text boot..."

# Find and update boot entries
updated=0
for entry in "$ENTRIES_DIR"/*.conf; do
    if [[ -f "$entry" ]]; then
        entry_name=$(basename "$entry")

        # Check if entry has quiet or splash
        if grep -q '\bquiet\b\|\bsplash\b' "$entry"; then
            # Backup if not already done
            if [[ ! -f "$entry.original" ]]; then
                cp "$entry" "$entry.original"
                log "Backed up $entry_name"
            fi

            # Remove quiet and splash
            sed -i 's/\s*quiet\b//g; s/\s*splash\b//g' "$entry"
            # Clean up multiple spaces
            sed -i 's/  */ /g' "$entry"

            log "Removed quiet/splash from $entry_name"
            ((updated++))
        else
            ok "$entry_name already configured for text boot"
        fi
    fi
done

if [[ $updated -gt 0 ]]; then
    ok "Updated $updated boot entries"
fi

# ============================================
# 3. Optionally disable Plymouth
# ============================================
log "Checking Plymouth configuration..."

# Check if plymouth is in mkinitcpio hooks
if grep -q '\bplymouth\b' /etc/mkinitcpio.conf 2>/dev/null; then
    log "Plymouth is in initramfs hooks"
    log "To fully disable Plymouth, remove 'plymouth' from HOOKS in /etc/mkinitcpio.conf"
    log "Then run: sudo mkinitcpio -P"
fi

ok "Boot configuration complete"
log "Changes take effect on next reboot"
