#!/bin/bash
# Automatically finds and sets wallpaper from Pictures/wall
WALL=$(find /home/user/Pictures/wall -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" -o -iname "*.webp" \) | head -n 1)
if [ -z "$WALL" ]; then
    WALL="/home/user/Pictures/wall/beautiful-landscape.jpg"
fi
pkill -x swaybg 2>/dev/null
exec /home/user/.local/bin/swaybg -i "$WALL" -m fill
