#!/bin/bash
# Export explicitly installed package names to a yay-compatible list

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_FILE="${1:-$SCRIPT_DIR/../config/packages/yay-explicit.txt}"

log() { echo "[packages-export] $*"; }
err() { echo "[packages-export] ERROR: $*" >&2; }

mkdir -p "$(dirname "$OUT_FILE")"

if command -v yay &>/dev/null; then
    list_cmd=(yay -Qqe)
elif command -v pacman &>/dev/null; then
    list_cmd=(pacman -Qqe)
else
    err "Neither yay nor pacman found"
    exit 1
fi

{
    echo "# Explicit packages snapshot"
    echo "# Generated: $(date -Iseconds)"
    echo "# Host: $(hostname)"
    "${list_cmd[@]}" | sort -u
} > "$OUT_FILE"

log "Wrote package list to $OUT_FILE"
