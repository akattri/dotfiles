#!/bin/sh
curr=$(cat /tmp/niri_focused_ws 2>/dev/null)
if [ -z "$curr" ]; then
    curr=$(niri msg --json workspaces 2>/dev/null | grep -o '{"id":[^}]*"is_focused":true[^}]*}' | grep -o '"idx":[0-9]*' | cut -d: -f2)
    echo "$curr" > /tmp/niri_focused_ws
fi

if [ "$curr" = "$1" ]; then
    cls="active"
else
    cls="inactive"
fi

printf '{"text":"%s","class":"%s"}\n' "$1" "$cls"
