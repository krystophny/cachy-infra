#!/bin/bash
# Mount RAID storage at /mnt/storage
# Requires root

set -euo pipefail

log() { echo "[storage] $*"; }
ok()  { echo "[storage] OK: $*"; }
err() { echo "[storage] ERROR: $*" >&2; }

# Must run as root
if [[ $EUID -ne 0 ]]; then
    err "This script must be run as root (use sudo)"
    exit 1
fi

MOUNT_POINT="/mnt/storage"
UUID="53c68cbf-07bd-4890-a210-5acafb5b96db"

# Create mount point
mkdir -p "$MOUNT_POINT"

# Add to fstab if not present
if ! grep -q "$UUID" /etc/fstab; then
    log "Adding storage to fstab..."
    echo "UUID=$UUID $MOUNT_POINT ext4 defaults,nofail 0 2" >> /etc/fstab
    ok "Added to fstab"
else
    log "Already in fstab"
fi

# Mount if not mounted
if ! mountpoint -q "$MOUNT_POINT"; then
    log "Mounting storage..."
    mount "$MOUNT_POINT"
fi

ok "Storage mounted at $MOUNT_POINT"
