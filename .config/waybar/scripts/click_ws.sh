#!/bin/bash
TARGET="$1"
LOCKFILE="/tmp/niri_ws_last_click"

NOW_MS=$(($(date +%s%N)/1000000))

if [ -f "$LOCKFILE" ]; then
    read -r PREV_TARGET PREV_TIME < "$LOCKFILE"
else
    PREV_TARGET=""
    PREV_TIME=0
fi

DIFF=$((NOW_MS - PREV_TIME))

if [ "$PREV_TARGET" = "$TARGET" ] && [ "$DIFF" -ge 0 ] && [ "$DIFF" -le 350 ]; then
    # Double-click: toggle overview on this workspace
    echo "" > "$LOCKFILE"
    niri msg action focus-workspace "$TARGET"
    niri msg action toggle-overview
else
    # Single click: direct switch immediately
    echo "$TARGET $NOW_MS" > "$LOCKFILE"
    niri msg action focus-workspace "$TARGET"
fi

# Update state for Waybar pill display
echo "$TARGET" > /tmp/niri_focused_ws
pkill -RTMIN+10 waybar 2>/dev/null
