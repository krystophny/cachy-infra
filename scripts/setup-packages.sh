#!/bin/bash
# Install packages from a plain text list using yay
# Run as a regular user (not root)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_FILE="${1:-$SCRIPT_DIR/../config/packages/yay-explicit.txt}"

log() { echo "[packages] $*"; }
ok()  { echo "[packages] OK: $*"; }
err() { echo "[packages] ERROR: $*" >&2; }

if [[ $EUID -eq 0 ]]; then
    err "Run this script as a regular user (yay should not run as root)"
    exit 1
fi

if [[ ! -f "$PKG_FILE" ]]; then
    err "Package list not found: $PKG_FILE"
    exit 1
fi

if ! command -v yay &>/dev/null; then
    err "yay is required but not installed"
    exit 1
fi

count="$(grep -Ecv '^\s*(#|$)' "$PKG_FILE")"
if [[ "$count" -eq 0 ]]; then
    log "No packages found in $PKG_FILE"
    exit 0
fi

log "Installing $count packages from $PKG_FILE..."
grep -Ev '^\s*(#|$)' "$PKG_FILE" | xargs -r -n 100 yay -S --noconfirm --needed
ok "Package install complete"
