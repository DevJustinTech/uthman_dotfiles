-- Utility binds (standalone).
--
-- Only commands that exist on a plain Arch install are bound here. The old
-- Omarchy menu, share, transcode, reminder, weather, battery and dictation
-- binds were removed rather than left to fail silently; bindings.lua owns the
-- panels and launchers that replace most of them.

-- Window effects
hl.bind("SUPER + BACKSPACE", hl.dsp.exec_cmd("winfx transparent"), { description = "Toggle window transparency" })
hl.bind("SUPER + SHIFT + BACKSPACE", hl.dsp.exec_cmd("winfx gaps"), { description = "Toggle window gaps" })

-- Toggles
hl.bind("SUPER + CTRL + I", hl.dsp.exec_cmd("idle-toggle"), { description = "Toggle locking on idle" })
hl.bind("SUPER + CTRL + N", hl.dsp.exec_cmd("nightlight"), { description = "Toggle nightlight" })
hl.bind("SUPER + CTRL + DELETE", hl.dsp.exec_cmd("mon-toggle"), { description = "Toggle laptop display" })
hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd("mon-toggle off"), { locked = true })
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd("mon-toggle on"), { locked = true })

-- Captures. Screenshots use explicit letter keys, never Print: a spurious
-- Print event from the keyboard/greeter used to launch capture overlays.
-- bindings.lua owns SUPER + SHIFT + S (pretty) and F (full).
hl.bind("SUPER + SHIFT + D", hl.dsp.exec_cmd("shot"), { description = "Screenshot (drag area)" })

-- Information
hl.bind("SUPER + CTRL + ALT + T", hl.dsp.exec_cmd([[notify-send -u low "$(date +'%A %H:%M  ·  %d %B %Y  ·  Week %V')"]]), { description = "Show time" })

-- Activity monitor, using the terminal this setup actually runs.
hl.bind("SUPER + CTRL + T", hl.dsp.exec_cmd("foot -e btop"), { description = "Activity" })

-- Lock
hl.bind("SUPER + CTRL + L", hl.dsp.exec_cmd("lock"), { description = "Lock system" })
