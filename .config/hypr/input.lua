-- https://wiki.hypr.land/Configuring/Variables/#input

-- Omarchy's default input.lua sets CapsLock as the compose key and picks the
-- layout from /etc/vconsole.conf. This only narrows the values it already
-- establishes, so a future Omarchy default change still lands.
hl.config({
  input = {
    kb_layout = "us",
    -- Omarchy binds Compose to CapsLock by default (compose:caps plus
    -- shift:both_capslock_cancel, so both Shifts can stand in for it).
    -- compose:ralt puts Compose on Right Alt instead, which is what the rest of
    -- this setup assumes.
    kb_options = "compose:ralt",

    repeat_rate = 40,
    repeat_delay = 600,
    numlock_by_default = true,

    touchpad = {
      natural_scroll = true,
      scroll_factor = 1,
    },
  },
})