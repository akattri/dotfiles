#!/bin/bash
# Initialize focused workspace
IDX=$(niri msg --json workspaces 2>/dev/null | grep -o '{"id":[^}]*"is_focused":true[^}]*}' | grep -o '"idx":[0-9]*' | cut -d: -f2)
[ -n "$IDX" ] && echo "$IDX" > /tmp/niri_focused_ws

# Continuously monitor Niri event stream
niri msg --json event-stream 2>/dev/null | while read -r line; do
    if [[ "$line" == *"WorkspacesChanged"* || "$line" == *"WorkspaceActivated"* ]]; then
        NEW_IDX=$(niri msg --json workspaces 2>/dev/null | grep -o '{"id":[^}]*"is_focused":true[^}]*}' | grep -o '"idx":[0-9]*' | cut -d: -f2)
        if [ -n "$NEW_IDX" ]; then
            OLD_IDX=$(cat /tmp/niri_focused_ws 2>/dev/null)
            if [ "$NEW_IDX" != "$OLD_IDX" ]; then
                echo "$NEW_IDX" > /tmp/niri_focused_ws
                pkill -RTMIN+10 waybar 2>/dev/null
            fi
        fi
    fi
done
