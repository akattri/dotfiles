#!/bin/bash
# Open Google Calendar web app
if command -v helium &>/dev/null; then
    helium --app="https://calendar.google.com" &
elif command -v google-chrome &>/dev/null; then
    google-chrome --app="https://calendar.google.com" &
elif command -v chromium &>/dev/null; then
    chromium --app="https://calendar.google.com" &
else
    xdg-open "https://calendar.google.com" &
fi
