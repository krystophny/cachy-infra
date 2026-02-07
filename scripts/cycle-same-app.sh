#!/bin/bash
# Cycle through windows of the same application (like Cmd+` on macOS)
# Requires: wmctrl, xprop

active_id=$(printf '0x%08x' "$(xdotool getactivewindow)")
active_class=$(xprop -id "$active_id" WM_CLASS | awk -F'"' '{print $4}')

mapfile -t windows < <(wmctrl -lx | awk -v c="$active_class" '$3 ~ c {print $1}')

[[ ${#windows[@]} -lt 2 ]] && exit 0

for i in "${!windows[@]}"; do
    if [[ "${windows[$i]}" == "$active_id" ]]; then
        next=$(( (i + 1) % ${#windows[@]} ))
        wmctrl -ia "${windows[$next]}"
        break
    fi
done
