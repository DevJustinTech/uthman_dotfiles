-- Multimedia keys (standalone).
--
-- Volume and display brightness deliberately live in bindings.lua, which routes
-- them through the Quickshell OSD. The keys here are the ones the shell does
-- not own: keyboard backlight, touchpad, media transport, and sink switching.

local function rep(keys, desc, cmd)
  hl.bind(keys, hl.dsp.exec_cmd(cmd), { repeating = true, locked = true, description = desc })
end
local function lk(keys, desc, cmd)
  hl.bind(keys, hl.dsp.exec_cmd(cmd), { locked = true, description = desc })
end

-- Keyboard backlight. `bright` is in ~/.local/bin and uses brightnessctl.
rep("XF86KbdBrightnessUp", "Keyboard brightness up", "bright kbd-up")
rep("XF86KbdBrightnessDown", "Keyboard brightness down", "bright kbd-down")
lk("XF86KbdLightOnOff", "Keyboard backlight cycle", "bright kbd-cycle")

-- Touchpad. The helper applies the change immediately and persists it under
-- ~/.local/state/hypr so a Hyprland reload restores the same state.
lk("XF86TouchpadToggle", "Toggle touchpad", "touchpad toggle")
lk("XF86TouchpadOn", "Enable touchpad", "touchpad on")
lk("XF86TouchpadOff", "Disable touchpad", "touchpad off")

-- Media transport. Requires playerctl.
lk("XF86AudioNext", "Next track", "playerctl next")
lk("XF86AudioPause", "Pause", "playerctl play-pause")
lk("XF86AudioPlay", "Play", "playerctl play-pause")
lk("XF86AudioPrev", "Previous track", "playerctl previous")

-- Switch audio output with SUPER + Mute.
lk("SUPER + XF86AudioMute", "Switch audio output", "vol cycle-sink")
