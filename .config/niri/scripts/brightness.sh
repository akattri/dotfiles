#!/bin/bash
DEVICE="intel_backlight"
MAX=$(cat /sys/class/backlight/$DEVICE/max_brightness 2>/dev/null)
CURR=$(cat /sys/class/backlight/$DEVICE/brightness 2>/dev/null)

if [ -z "$MAX" ] || [ -z "$CURR" ]; then
    exit 1
fi

STEP=$(( MAX / 20 )) # 5% increment
MIN=$(( MAX / 100 ))  # minimum 1% to prevent screen turning completely dark

case "$1" in
    toggle)
        BRIGHT=$(( CURR * 100 / MAX ))
        /home/user/.local/bin/waybar-drawer-reveal brightness toggle "$BRIGHT" >/dev/null 2>&1 &
        exit 0
        ;;
    up|+)
        NEW=$(( CURR + STEP ))
        [ "$NEW" -gt "$MAX" ] && NEW=$MAX
        ;;
    down|-)
        NEW=$(( CURR - STEP ))
        [ "$NEW" -lt "$MIN" ] && NEW=$MIN
        ;;
    *)
        exit 1
        ;;
esac

busctl call org.freedesktop.login1 /org/freedesktop/login1/session/auto org.freedesktop.login1.Session SetBrightness ssu "backlight" "$DEVICE" "$NEW" >/dev/null 2>&1

BRIGHT=$(( NEW * 100 / MAX ))
/home/user/.local/bin/waybar-drawer-reveal brightness 2000 "$BRIGHT" >/dev/null 2>&1 &
