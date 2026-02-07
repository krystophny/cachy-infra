#!/bin/bash
# Cycle through windows of the same application on the current desktop (like Cmd+` on macOS)
# Requires: wmctrl, xdotool, xprop

active_id=$(printf '0x%08x' "$(xdotool getactivewindow)")
active_class=$(xprop -id "$active_id" WM_CLASS | awk -F'"' '{print $4}')
current_desktop=$(wmctrl -d | awk '$2 == "*" {print $1}')

mapfile -t windows < <(wmctrl -lx | awk -v c="$active_class" -v d="$current_desktop" '$3 ~ c && $2 == d {print $1}')

[[ ${#windows[@]} -lt 2 ]] && exit 0

for i in "${!windows[@]}"; do
    if [[ "${windows[$i]}" == "$active_id" ]]; then
        next=$(( (i + 1) % ${#windows[@]} ))
        next_id="${windows[$next]}"
        wmctrl -ia "$next_id"
        xdotool mousemove --window "$next_id" --polar 0 0
        break
    fi
done
