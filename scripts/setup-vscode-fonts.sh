#!/bin/bash
# Fix VS Code UI fonts when bitmap Helvetica (Chicago95) is installed.
# Installs a per-app fontconfig that rejects bitmap fonts and remaps
# Helvetica to Noto Sans, plus a wrapper script that applies it.
# Idempotent - safe to run multiple times.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="$SCRIPT_DIR/../config/vscode-fontconfig/fonts.conf"

TARGET_USER="${1:-$(whoami)}"
TARGET_HOME="$(eval echo ~"$TARGET_USER")"

ok()  { echo "[vscode-fonts] OK: $*"; }
err() { echo "[vscode-fonts] ERROR: $*" >&2; }

if [[ "$(whoami)" != "$TARGET_USER" ]]; then
    err "Run as user $TARGET_USER"
    exit 1
fi

FONTCONFIG_DIR="$TARGET_HOME/.config/vscode-fontconfig"
WRAPPER="$TARGET_HOME/bin/code"
DESKTOP_LOCAL="$TARGET_HOME/.local/share/applications/code.desktop"

# 1. Install fontconfig (substitute __HOME__ with actual home)
mkdir -p "$FONTCONFIG_DIR"
sed "s|__HOME__|$TARGET_HOME|g" "$CONFIG_SRC" > "$FONTCONFIG_DIR/fonts.conf"
ok "Installed $FONTCONFIG_DIR/fonts.conf"

# 2. Rebuild fontconfig cache for the custom config
FONTCONFIG_FILE="$FONTCONFIG_DIR/fonts.conf" fc-cache -f 2>/dev/null
ok "Rebuilt fontconfig cache"

# 3. Install wrapper script
if [[ ! -f /usr/bin/code ]]; then
    err "/usr/bin/code not found - install VS Code first"
    exit 1
fi

mkdir -p "$TARGET_HOME/bin"
cat > "$WRAPPER" << EOF
#!/usr/bin/env bash
export FONTCONFIG_FILE="$FONTCONFIG_DIR/fonts.conf"
export GTK_THEME="Adwaita:light"
exec /usr/bin/code "\$@"
EOF
chmod +x "$WRAPPER"
ok "Installed wrapper: $WRAPPER"

# 4. Install desktop file pointing to wrapper
mkdir -p "$(dirname "$DESKTOP_LOCAL")"
if [[ -f /usr/share/applications/code.desktop ]]; then
    sed "s|Exec=/usr/bin/code|Exec=$WRAPPER|g" \
        /usr/share/applications/code.desktop > "$DESKTOP_LOCAL"
    ok "Installed desktop file: $DESKTOP_LOCAL"
fi

echo
ok "Restart VS Code to apply font fix."
