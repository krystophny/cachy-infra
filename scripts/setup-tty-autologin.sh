#!/bin/bash
# Replace LightDM with TTY autologin + automatic XFCE start
# Faster boot to desktop
# Requires root

set -euo pipefail

TARGET_USER="${1:-ert}"

log() { echo "[tty-autologin] $*"; }
ok()  { echo "[tty-autologin] OK: $*"; }
err() { echo "[tty-autologin] ERROR: $*" >&2; }

# Must run as root
if [[ $EUID -ne 0 ]]; then
    err "This script must be run as root (use sudo)"
    exit 1
fi

# Verify user exists
if ! id "$TARGET_USER" &>/dev/null; then
    err "User $TARGET_USER does not exist"
    exit 1
fi

USER_HOME="/home/$TARGET_USER"

# ============================================
# 1. Disable LightDM
# ============================================
log "Disabling LightDM..."
if systemctl is-enabled lightdm &>/dev/null; then
    systemctl disable lightdm
    ok "LightDM disabled"
else
    ok "LightDM already disabled"
fi

# ============================================
# 2. Setup getty autologin on tty1
# ============================================
log "Configuring TTY1 autologin..."
GETTY_DIR="/etc/systemd/system/getty@tty1.service.d"
mkdir -p "$GETTY_DIR"

cat > "$GETTY_DIR/autologin.conf" << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -f -- \\\\u' --noclear --autologin $TARGET_USER %I \$TERM
EOF

ok "TTY1 autologin configured for $TARGET_USER"

# ============================================
# 3. Setup .bash_profile to start XFCE on tty1
# ============================================
log "Configuring automatic XFCE start..."
BASH_PROFILE="$USER_HOME/.bash_profile"

# Backup existing .bash_profile if it exists and doesn't have our marker
if [[ -f "$BASH_PROFILE" ]] && ! grep -q "# cachy-infra: auto-start XFCE" "$BASH_PROFILE"; then
    cp "$BASH_PROFILE" "$BASH_PROFILE.backup.$(date +%Y%m%d_%H%M%S)"
    log "Backed up existing .bash_profile"
fi

cat > "$BASH_PROFILE" << 'EOF'
# cachy-infra: auto-start XFCE on tty1
# Uses startx so ~/.xinitrc runs (gnome-keyring, dbus, etc.)
if [[ -z "$DISPLAY" ]] && [[ "$(tty)" == "/dev/tty1" ]]; then
    exec startx
fi

# Source .bashrc if it exists
[[ -f ~/.bashrc ]] && . ~/.bashrc
EOF

chown "$TARGET_USER:$TARGET_USER" "$BASH_PROFILE"
chmod 644 "$BASH_PROFILE"

ok "XFCE auto-start configured"

# ============================================
# 4. Reload systemd
# ============================================
log "Reloading systemd..."
systemctl daemon-reload

ok "TTY autologin setup complete"
log "On next boot: TTY1 autologin -> XFCE starts automatically"
log "To revert: sudo systemctl enable lightdm && rm $GETTY_DIR/autologin.conf"
