#!/bin/bash
case "$1" in
    up)
        wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.05+ -l 1.0
        ;;
    down)
        wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.05-
        ;;
    mute)
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
        ;;
    toggle)
        VOL_STR=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
        VOL=$(echo "$VOL_STR" | awk '{print int($2 * 100 + 0.5)}')
        if [ -n "$VOL" ]; then
            /home/user/.local/bin/waybar-drawer-reveal audio toggle "$VOL" >/dev/null 2>&1 &
        else
            /home/user/.local/bin/waybar-drawer-reveal audio toggle >/dev/null 2>&1 &
        fi
        exit 0
        ;;
    *)
        exit 1
        ;;
esac

VOL_STR=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
VOL=$(echo "$VOL_STR" | awk '{print int($2 * 100 + 0.5)}')
if [ -n "$VOL" ]; then
    /home/user/.local/bin/waybar-drawer-reveal audio 2000 "$VOL" >/dev/null 2>&1 &
else
    /home/user/.local/bin/waybar-drawer-reveal audio 2000 >/dev/null 2>&1 &
fi
