#!/bin/bash
# Install gnome-keyring and configure PAM unlock for TTY autologin
# Requires root

set -euo pipefail

log() { echo "[gnome-keyring] $*"; }
ok()  { echo "[gnome-keyring] OK: $*"; }
err() { echo "[gnome-keyring] ERROR: $*" >&2; }

backup_file() {
    local file="$1"
    local backup

    backup="$file.backup.$(date +%Y%m%d_%H%M%S_%N)"
    cp "$file" "$backup"
    log "Backed up $file to $backup"
}

ensure_line_after_regex() {
    local file="$1"
    local anchor_regex="$2"
    local line="$3"
    local tmp

    tmp=$(mktemp)
    if ! awk -v anchor_regex="$anchor_regex" -v line="$line" '
        { print }
        !added && $0 ~ anchor_regex { print line; added = 1 }
        END { exit added ? 0 : 1 }
    ' "$file" > "$tmp"; then
        rm -f "$tmp"
        err "Failed to update $file: missing anchor $anchor_regex"
        exit 1
    fi

    mv "$tmp" "$file"
}

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
# 2. Add PAM integration for autologin + keyring sync
# ============================================
PAM_LOGIN="/etc/pam.d/login"
PAM_PASSWD="/etc/pam.d/passwd"
LOADKEY_LINE="-auth      optional     pam_systemd_loadkey.so"
AUTH_LINE="-auth      optional     pam_gnome_keyring.so"
SESSION_LINE="-session   optional     pam_gnome_keyring.so auto_start"
PASSWD_LINE="password   optional     pam_gnome_keyring.so use_authtok"

log "Configuring PAM unlock in $PAM_LOGIN..."
login_changed=0
if ! grep -Eq '^-auth[[:space:]]+optional[[:space:]]+pam_systemd_loadkey\.so$' "$PAM_LOGIN"; then
    if (( login_changed == 0 )); then
        backup_file "$PAM_LOGIN"
        login_changed=1
    fi
    ensure_line_after_regex \
        "$PAM_LOGIN" \
        '^auth[[:space:]]+include[[:space:]]+system-local-login$' \
        "$LOADKEY_LINE"
fi

if ! grep -Eq '^-auth[[:space:]]+optional[[:space:]]+pam_gnome_keyring\.so$' "$PAM_LOGIN"; then
    if (( login_changed == 0 )); then
        backup_file "$PAM_LOGIN"
        login_changed=1
    fi
    ensure_line_after_regex \
        "$PAM_LOGIN" \
        '^-auth[[:space:]]+optional[[:space:]]+pam_systemd_loadkey\.so$' \
        "$AUTH_LINE"
fi

if ! grep -Eq '^-session[[:space:]]+optional[[:space:]]+pam_gnome_keyring\.so[[:space:]]+auto_start$' "$PAM_LOGIN"; then
    if (( login_changed == 0 )); then
        backup_file "$PAM_LOGIN"
        login_changed=1
    fi
    ensure_line_after_regex \
        "$PAM_LOGIN" \
        '^session[[:space:]]+include[[:space:]]+system-local-login$' \
        "$SESSION_LINE"
fi

if (( login_changed == 1 )); then
    ok "PAM login stack configured"
else
    ok "PAM login stack already configured"
fi

log "Configuring keyring password sync in $PAM_PASSWD..."
passwd_changed=0
if grep -Eq '^password[[:space:]]+optional[[:space:]]+pam_gnome_keyring\.so[[:space:]]+use_authtok$' "$PAM_PASSWD"; then
    ok "PAM password stack already configured"
else
    backup_file "$PAM_PASSWD"
    passwd_changed=1
    ensure_line_after_regex \
        "$PAM_PASSWD" \
        '^password[[:space:]]+include[[:space:]]+system-auth$' \
        "$PASSWD_LINE"
fi

if (( passwd_changed == 1 )); then
    ok "PAM password stack configured"
fi

ok "gnome-keyring setup complete"
log "TTY autologin can unlock the login keyring from the boot keyring"
log "This requires the keyring password to match the LUKS passphrase"
