#!/bin/bash
# Master setup script for CachyOS infrastructure
# Runs all setup scripts in order
# Usage: sudo ./setup-all.sh [username]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_USER="${1:-ert}"

log() { echo ""; echo "========================================"; echo "$*"; echo "========================================"; }

# Verify we're on CachyOS/Arch
if [[ ! -f /etc/arch-release ]] && [[ ! -f /etc/cachyos-release ]]; then
    echo "ERROR: This script is designed for CachyOS/Arch Linux"
    exit 1
fi

# Check if sudo/root
if [[ $EUID -ne 0 ]]; then
    echo "ERROR: This script must be run with sudo"
    echo "Usage: sudo $0 [$TARGET_USER]"
    exit 1
fi

# Verify target user exists
if ! id "$TARGET_USER" &>/dev/null; then
    echo "ERROR: User $TARGET_USER does not exist"
    exit 1
fi

echo "CachyOS Infrastructure Setup"
echo "Target user: $TARGET_USER"
echo ""

# Run scripts that need root
log "Setting up TTY autologin..."
"$SCRIPT_DIR/setup-tty-autologin.sh" "$TARGET_USER"

log "Setting up boot configuration..."
"$SCRIPT_DIR/setup-boot.sh"

log "Removing plymouth for faster boot..."
"$SCRIPT_DIR/setup-remove-plymouth.sh"

# Run Chicago95 setup as target user
log "Setting up Chicago95 theme..."
sudo -u "$TARGET_USER" "$SCRIPT_DIR/setup-chicago95.sh" "$TARGET_USER"

log "Setup complete!"
echo ""
echo "Summary of changes:"
echo "  - Chicago95 theme installed and configured"
echo "  - TTY autologin enabled (LightDM disabled)"
echo "  - Boot timeout set to 0"
echo "  - Removed quiet/splash for text boot"
echo ""
echo "Reboot to apply all changes: sudo reboot"
