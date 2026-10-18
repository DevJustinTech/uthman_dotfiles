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

      -- libinput's tap-and-drag is the OS feature behind double-tap-then-
      -- drag text selection, so it stays ON.  It also synthesizes its own
      -- drag press (single tap + touch-move) that travels libinput ->
      -- Hyprland -> clients and never reaches the pad's evdev stream, so
      -- while it owns a gesture edge-motion cannot see it (busy() false
      -- while slurp drives the box through the invisible press: "the box
      -- opens but the pad edge never glides").  The two systems only ever
      -- fight during a pick, and every pick starts on a keybinding before
      -- the fingers touch the pad, so slurp-tap flips tap_and_drag off in
      -- the same eval dance that silences tap-to-click and restores both
      -- on every exit path.  Tap-to-click stays as Hyprland defaults it
      -- (enabled).
      tap_and_drag = true,
    },
  },
})