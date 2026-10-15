-- Keybindings.
--
-- Omarchy's defaults stay loaded (see hyprland.lua). This file unbinds the
-- specific chords this desktop replaces and binds them to the Quickshell
-- shell's IPC targets instead. Everything else -- tiling, workspaces, media,
-- utilities -- is inherited.
--
-- Audit with: hyprctl binds
-- Check descriptions: hyprctl binds | grep -i bindd

-- The canonical IPC path string. Mismatched -p values fail with "Target not
-- found" even while a shell is clearly running, so every call below must use
-- this exact string.
local function ipc(target, method, ...)
  local args = { ... }
  local call = string.format("quickshell -p ~/.config/quickshell ipc call %s %s", target, method)
  for _, arg in ipairs(args) do
    call = string.format("%s %s", call, arg)
  end
  return "sh -c " .. o.shell_quote(call)
end

local function open(target, method)
  return ipc(target, method or "toggle")
end

-- ── Application launches ────────────────────────────────────────────────
-- No SUPER + RETURN here. Omarchy already binds it to omarchy-launch-terminal
-- (and SUPER CTRL T to Herdr, SUPER ALT RETURN to Tmux), so binding it again
-- fired twice: this repo's hardcoded kitty plus Omarchy's launcher, which goes
-- through ~/.local/bin/xdg-terminal-exec and so now opens foot. Two terminals
-- per press, one of each.
--
-- Leaving it to Omarchy is the better behaviour anyway: omarchy-launch-terminal
-- opens in the current terminal's working directory, which the bare binary does
-- not. Anything else wanting a terminal should go through the same shim so it
-- follows whatever terminal is configured, rather than hardcoding a name.
o.bind("SUPER + SHIFT + F", "File manager", o.launch("thunar"))
-- Firefox is the default xdg handler, so the old `xdg-open <url>` form resolved
-- to it anyway -- it just forced a URL on every launch. Bind firefox directly.
o.bind("SUPER + SHIFT + B", "Browser", o.launch("firefox"))
o.bind("SUPER + ALT + SHIFT + B", "Browser (private)", o.launch("firefox --private-window"))

-- Killed the vendored zoom-in (SUPER CTRL Z): key-repeat turns a slip into
-- runaway zoom. (Zen launch key removed 10-08 -- too close to the zoom chord.)
hl.unbind("SUPER + CTRL + Z")

o.bind("SUPER + SHIFT + M", "Music", o.launch("spotify"))
o.bind("SUPER + SHIFT + N", "Editor", o.launch("zed"))
o.bind("SUPER + SHIFT + O", "Obsidian", o.launch("obsidian -disable-gpu --enable-wayland-ime"))

-- If a web app URL contains #, type it as ## to prevent Hyprland treating it
-- as a comment. Web apps open chromeless (Chrome --app style) via:
--   ffapp <name> <url> [title-regex]
o.bind("SUPER + SHIFT + A", "ChatGPT", "ffapp chatgpt https://chatgpt.com ChatGPT")
o.bind("SUPER + ALT + SHIFT + A", "Grok", "ffapp grok https://grok.com Grok")
o.bind("SUPER + SHIFT + C", "Calendar", "ffapp heycal https://app.hey.com/calendar/weeks/ Calendar")
o.bind("SUPER + SHIFT + E", "Email", "ffapp heymail https://app.hey.com \"IMBOX|HEY\"")
o.bind("SUPER + SHIFT + Y", "YouTube", "ffapp youtube https://youtube.com/ YouTube")
o.bind("SUPER + CTRL + SHIFT + G", "Google Messages", "ffapp messages https://messages.google.com/web/conversations Messages")
o.bind("SUPER + SHIFT + P", "Google Photos", "ffapp photos https://photos.google.com/ \"Google Photos\"")
o.bind("SUPER + SHIFT + X", "X", "ffapp x https://x.com/ \"\\\\bX\\\\b\"")
o.bind("SUPER + ALT + SHIFT + X", "X Post", "ffapp x https://x.com/compose/post \"\\\\bX\\\\b\"")

-- ── Print safety ────────────────────────────────────────────────────────
-- Print must never launch an action. The keyboard/greeter can emit a spurious
-- Print while another key is held, which previously made screenshot overlays
-- appear during unrelated shortcuts. Screenshot binds use explicit letter keys;
-- these unbinds also reject any Print combination a future Omarchy default
-- might introduce.
-- Hyprland's Lua API needs "+" between every modifier (the old .conf syntax
-- allowed space-separated ones like "SUPER SHIFT"). Order of modifiers in a
-- multi-modifier chord is also normalised as SUPER <other> <SHIFT>.
for _, mods in ipairs({
  "", "SHIFT", "ALT", "SUPER", "SUPER CTRL", "SUPER SHIFT",
  "SUPER ALT SHIFT", "SUPER CTRL SHIFT", "SUPER ALT CTRL SHIFT",
}) do
  hl.unbind(mods .. " + PRINT")
end
-- Omarchy binds SUPER SHIFT S to the Google Maps webapp; the pretty
-- screenshot takes that chord instead, so drop the default first.
hl.unbind("SUPER + SHIFT + S")
-- Omarchy also binds the audio keys (media.lua) to its own scripts. Those
-- binds SURVIVE alongside the ones below -- hyprctl lists both 'Mute' and
-- 'Mute toggle' on XF86AudioMute -- so a keypress ran both mute paths at
-- once. Two toggles cancel: the sink muted and unmuted within the same
-- press, which is why the OSD appeared and the audio never changed. The
-- silent half (omarchy-audio-output-volume) left no trace in the media log,
-- which is what made it look like the one logged call had failed.
hl.unbind("XF86AudioMute")
hl.unbind("XF86AudioMicMute")
-- Screenshots use letter keys only (see above) -- T is OCR text capture.
o.bind("SUPER + SHIFT + T", "OCR from screenshot", "shot ocr")
-- S: mac-style capture of the focused window, rounded over a blurred wallpaper.
-- Deliberately NOT on PRINT, unlike upstream: the unbind list above exists
-- because spurious Print events fired screenshot overlays during unrelated
-- chords. The same hazard applies to this one.
o.bind("SUPER + SHIFT + S", "Pretty screenshot", "shot pretty")

-- ── Shell panels ────────────────────────────────────────────────────────
-- Omarchy puts its menu on SUPER+SPACE and a panel set on SUPER+H/U/B. All of
-- those are unbound here first so the shell's own panels land cleanly --
-- otherwise two bindings fire on the same chord.
for _, keys in ipairs({
  "SUPER + SPACE", "SUPER + H", "SUPER + U", "SUPER + C", "SUPER + ALT + B",
  "SUPER + CTRL + E", "SUPER + CTRL + V", "SUPER + ALT + SPACE", "SUPER + CTRL + SPACE",
  "SUPER + E", "SUPER + N", "SUPER + I", "SUPER + K", "SUPER + L",
  "SUPER + ALT + P", "SUPER + ALT + T", "SUPER + ALT + K", "SUPER + ALT + D",
  "SUPER + ALT + E", "SUPER + ESCAPE", "SUPER + ALT + O", "SUPER + SHIFT + SPACE",
}) do
  hl.unbind(keys)
end

o.bind("SUPER + SPACE", "Launcher", open("launcher"))
o.bind("SUPER + K", "Keybind cheatsheet", open("keybinds"))
o.bind("SUPER + H", "Wi-Fi panel", open("wifi"))
o.bind("SUPER + U", "System monitor", open("sysmon"))
o.bind("SUPER + C", "Clipboard", open("clipboard"))
o.bind("SUPER + ALT + B", "Battery panel", open("battery"))
o.bind("SUPER + ALT + C", "Pomodoro", open("pomodoro"))
o.bind("SUPER + ALT + L", "Lyrics", open("lyrics"))
o.bind("SUPER + E", "Theme panel", open("theme"))
o.bind("SUPER + ALT + G", "Theme editor", open("themeedit"))
o.bind("SUPER + N", "System info", open("fastfetch"))
o.bind("SUPER + I", "Package manager", open("pkgman"))
o.bind("SUPER + ALT + N", "PDF library", open("pdfviewer"))
o.bind("SUPER + CTRL + SPACE", "Wallpaper store", open("wallshelf"))
o.bind("SUPER + ALT + O", "Workspace overview", open("wsview"))
o.bind("SUPER + ALT + P", "Control center", open("controlcenter"))
o.bind("SUPER + ALT + T", "Screen time", open("screentime"))
o.bind("SUPER + ALT + D", "Drive health", open("drives"))
o.bind("SUPER + ALT + E", "Earbuds", open("earbuds"))
o.bind("SUPER + ALT + Y", "WatchCat", open("watchcat"))
o.bind("SUPER + CTRL + V", "Clipboard window", open("clipboard"))
o.bind("SUPER + CTRL + P", "Pin clipboard to sticky shelf", ipc("sticky", "pin"))
o.bind("SUPER + ESCAPE", "Power menu", open("power"))
o.bind("SUPER + L", "Lock screen", "pidof hyprlock || hyprlock")
o.bind("SUPER + ALT + SPACE", "Island style", ipc("bar", "toggleIsland"))
o.bind("SUPER + SHIFT + SPACE", "Bar sides", ipc("bar", "toggle"))
o.bind("SUPER + COMMA", "Notification center", open("notifications"))
o.bind("SUPER + SHIFT + COMMA", "Toggle do not disturb", ipc("notifications", "toggleDnd"))

-- Sticky shelf -- fire a pinned snippet straight to the clipboard from any
-- app, no panel. Slot 1 is the oldest sticky; add more in the panel.
for slot = 1, 9 do
  o.bind(string.format("SUPER + ALT + %d", slot), "Sticky slot " .. slot, ipc("sticky", "copy", slot))
end

-- ── Emoji picker ────────────────────────────────────────────────────────
o.bind("SUPER + CTRL + E", "Emoji picker", o.launch("~/.config/rofi/emoji.sh"))

-- ── Screen recording ────────────────────────────────────────────────────
-- Local toggle (gpu-screen-recorder, saves to ~/Videos/Recordings).
o.bind("SUPER + R", "Screen record toggle", o.launch("record"))

-- ── Power ───────────────────────────────────────────────────────────────
-- Reboot bind removed 2026-10-03: too easy to fat-finger. Use the power menu.
o.bind("SUPER + SHIFT + Q", "Shut down", "systemctl poweroff")
hl.unbind("SUPER + SHIFT + R")

-- ── Full reload (SUPER HOME) ────────────────────────────────────────────
-- Reloads Hyprland then kills and restarts quickshell, so every module
-- re-reads its config rather than relying on Quickshell's hot reload.
o.bind("SUPER + HOME", "Reload Hyprland and shell",
  "sh -c 'hyprctl reload >/dev/null 2>&1; pkill -x quickshell; sleep 0.3; setsid quickshell -p ~/.config/quickshell >/dev/null 2>&1 &'")

-- ── fn-row media keys -> quickshell OSD ─────────────────────────────────
-- Omarchy binds these to swayosd/omarchy clients. All are unbound first --
-- including the no-space and space-after-comma forms, since the defaults use
-- the former -- so the shell's OSD is the only responder.
for _, keys in ipairs({
  "XF86AudioRaiseVolume", "XF86AudioLowerVolume", "XF86AudioMute", "XF86AudioMicMute",
  "XF86MonBrightnessUp", "XF86MonBrightnessDown",
}) do
  for _, mods in ipairs({ "", "SHIFT", "ALT" }) do
    hl.unbind(mods .. " + " .. keys)
  end
end

o.bind("XF86AudioRaiseVolume", "Volume up", ipc("media", "volup"), { repeating = true })
o.bind("XF86AudioLowerVolume", "Volume down", ipc("media", "voldown"), { repeating = true })
o.bind("XF86AudioMute", "Mute toggle", ipc("media", "volmute"))
o.bind("XF86AudioMicMute", "Mic mute toggle", ipc("media", "micmute"))
o.bind("XF86MonBrightnessUp", "Brightness up", ipc("media", "briup"), { repeating = true })
o.bind("XF86MonBrightnessDown", "Brightness down", ipc("media", "bridown"), { repeating = true })
o.bind("SHIFT + XF86MonBrightnessUp", "Brightness maximum", ipc("media", "brimax"))
o.bind("SHIFT + XF86MonBrightnessDown", "Brightness minimum", ipc("media", "brimin"))
o.bind("ALT + XF86AudioRaiseVolume", "Volume up precise", ipc("media", "volup"))
o.bind("ALT + XF86AudioLowerVolume", "Volume down precise", ipc("media", "voldown"))