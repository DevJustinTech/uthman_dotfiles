-- https://wiki.hypr.land/Configuring/Basics/Monitors/
-- Inspect the current layout with: hyprctl monitors all

-- Laptop panel, native 1366x768@60. "preferred" rather than a hardcoded mode,
-- because this panel only ever advertises 1366x768 -- naming a resolution it
-- does not have makes Hyprland reject the rule and fall back to defaults.
-- Scale 1, and GDK_SCALE in envs.lua matches.
hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = 1 })

-- Portrait/rotated external display (transform: 1 = 90deg, 3 = 270deg).
-- hl.monitor({ output = "DP-2", mode = "preferred", position = "auto", scale = 1, transform = 1 })

-- The old monitors-override.conf (written by the Monitors panel so a pick
-- could persist across restarts) is gone: in Lua the Monitors module now sets
-- the keyword directly with hyprctl, so there is no generated file to source.