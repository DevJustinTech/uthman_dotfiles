#!/usr/bin/env bash
# Keybindings browser — reads the live binds from Hyprland.
#
# The old version parsed ~/.config/hypr/bindings.conf, which no longer exists:
# this desktop uses the Lua config, so the authoritative list comes from
# `hyprctl binds`. Entries without a description are internal/unbound noise.

mods() {
  local mask=$1 out=""
  (( mask & 1 ))   && out+="SHIFT + "
  (( mask & 4 ))   && out+="CTRL + "
  (( mask & 8 ))   && out+="ALT + "
  (( mask & 64 ))  && out+="SUPER + "
  printf '%s' "${out% + }"
}

format() {
  hyprctl binds -j 2>/dev/null |
    jq -r '.[] | select((.description // "") != "" and (.key // "") != "") | [.modmask, .key, .description] | @tsv' |
    while IFS=$'\t' read -r mask key desc; do
      local m
      m=$(mods "$mask")
      [[ -n $m ]] && printf '%s + %s — %s\n' "$m" "$key" "$desc" || printf '%s — %s\n' "$key" "$desc"
    done | sort -u
}

format | rofi -dmenu -theme ~/.config/rofi/list.rasi -p '⌨️  Keybindings' -i -lines 20
