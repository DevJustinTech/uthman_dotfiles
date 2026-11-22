#!/bin/bash
# Status pill: how many package updates are waiting.
#
# `checkupdates` comes from pacman-contrib and checks the official repos
# without touching the sync databases. yay is used as a fallback for AUR/foreign
# updates. Output is the JSON shape StatusPill.qml expects.

if command -v checkupdates >/dev/null 2>&1; then
  out=$(timeout 20 checkupdates 2>/dev/null)
else
  out=$(timeout 20 yay -Qu 2>/dev/null)
fi

count=$(printf '%s\n' "$out" | grep -c . || true)

if (( count > 0 )); then
  echo "{\"text\":\"󰇥\",\"tooltip\":\"${count} update(s) available — click to open the updater\",\"class\":\"pending\"}"
else
  echo '{"text":""}'
fi
