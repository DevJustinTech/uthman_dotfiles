-- Environment variables for the session.

local home = os.getenv("HOME")

-- Helper scripts (set-wallpaper, getTheme, shot, record, ...) live here.
hl.env("PATH", home .. "/.local/bin:" .. (os.getenv("PATH") or ""))

-- rofi askpass backend, used by PassPrompt.qml for privileged panel actions.
hl.env("SUDO_ASKPASS", home .. "/.local/bin/askpass")

-- matugen-cursor writes the matching pointer theme; getTheme keeps its colour
-- in sync with the wallpaper on every theme change.
hl.env("HYPRCURSOR_THEME", "Matugen-Cursor")
hl.env("HYPRCURSOR_SIZE", "20")
hl.env("XCURSOR_THEME", "Matugen-Cursor")
hl.env("XCURSOR_SIZE", "20")

-- GDK_SCALE must match the monitor scale below or GTK apps double-scale.
-- This panel is a native 1366x768, so both are 1. Keep them in sync if you
-- ever raise the scale in monitors.lua.
hl.env("GDK_SCALE", "1")