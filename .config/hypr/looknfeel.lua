-- Look and feel: gaps, decoration, blur, animations, and the layer-shell rules
-- that frost every surface the Quickshell shell draws.

-- GPU_TUNING
-- This machine is an Intel HD Graphics 520 (Skylake, 2015) driving a native
-- 1366x768 laptop panel. The original config asked for blur passes = 4,
-- size = 12, render_power = 3, which the HD 520 cannot sustain -- it drops
-- frames and the fan spins up under the always-blurred bar.
--
-- These are the only knobs that matter here. Step down in this order if
-- windows feel stuttery:
--   passes      1 -> 0   (disables blur entirely; biggest single win)
--   size        6 -> 4
--   render_power 2 -> 1
-- The upstream originals were passes = 4, size = 12, render_power = 3.
hl.config({
  general = {
    gaps_in = 4,
    gaps_out = 10,
    border_size = 1,
    layout = "dwindle",
    resize_on_border = true,
  },

  decoration = {
    rounding = 12,
    rounding_power = 2.4,

    blur = {
      enabled = true,
      size = 6,          -- upstream: 12
      passes = 1,        -- upstream: 4
      new_optimizations = true,
      xray = false,
      ignore_opacity = false,
      popups = true,
    },

    shadow = {
      enabled = true,
      range = 28,
      render_power = 2,  -- upstream: 3
      color = "rgba(00000066)",
      color_inactive = "rgba(00000025)",
    },

    active_opacity = 0.95,
    inactive_opacity = 0.86,
    fullscreen_opacity = 1.0,

    dim_inactive = true,
    dim_strength = 0.08,
  },

  dwindle = {
    preserve_split = true,
    smart_split = true,
    smart_resizing = true,
  },

  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    animate_manual_resizes = true,
    animate_mouse_windowdragging = true,
    focus_on_activate = true,
    mouse_move_enables_dpms = true,
    key_press_enables_dpms = true,
  },
})

-- Border colours are NOT set here -- hypr/theme.lua paints them from the
-- matugen wallpaper palette. Re-add them above only for a hardcoded fallback.

-- ── Curves ──────────────────────────────────────────────────────────────
hl.curve("overshot", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.1 } } })
hl.curve("smooth",   { type = "bezier", points = { { 0.25, 1.0 }, { 0.5, 1.0 } } })
hl.curve("snappy",   { type = "bezier", points = { { 0.4, 0.0 }, { 0.2, 1.0 } } })
hl.curve("bounce",   { type = "bezier", points = { { 0.34, 1.56 }, { 0.64, 1.0 } } })

-- ── Animations ──────────────────────────────────────────────────────────
hl.animation({ leaf = "windowsIn",        enabled = true, speed = 5,   bezier = "overshot", style = "popin 90%" })
hl.animation({ leaf = "windowsOut",       enabled = true, speed = 2,   bezier = "snappy",   style = "popin 80%" })
hl.animation({ leaf = "windowsMove",      enabled = true, speed = 4,   bezier = "snappy" })
hl.animation({ leaf = "fadeIn",           enabled = true, speed = 4,   bezier = "smooth" })
hl.animation({ leaf = "fadeOut",          enabled = true, speed = 4,   bezier = "smooth" })
hl.animation({ leaf = "fade",             enabled = true, speed = 5,   bezier = "smooth" })
hl.animation({ leaf = "border",           enabled = true, speed = 8,   bezier = "smooth" })
hl.animation({ leaf = "borderangle",      enabled = true, speed = 12,  bezier = "smooth" })
hl.animation({ leaf = "workspaces",       enabled = true, speed = 5,   bezier = "overshot", style = "slidefadevert" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4,   bezier = "smooth",   style = "slidevert" })
hl.animation({ leaf = "layers",           enabled = true, speed = 4,   bezier = "smooth",   style = "slidefade" })
hl.animation({ leaf = "fadeLayersIn",     enabled = true, speed = 3,   bezier = "smooth" })
hl.animation({ leaf = "fadeLayersOut",    enabled = true, speed = 3,   bezier = "smooth" })

-- ── Layer-shell frosting ────────────────────────────────────────────────
-- Every Quickshell surface is a layer surface. ignore_alpha is the important
-- half: without it Hyprland blurs the whole rectangular layer including the
-- transparent margin, and each panel grows a visible box around its content.

local function frost(namespace)
  hl.layer_rule({ match = { namespace = "^" .. namespace .. "$" }, blur = true, ignore_alpha = 0.15 })
end

-- Bar island, popups, toasts, and the dedicated namespaces.
for _, namespace in ipairs({
  "qs-bar",
  "qs-launcher",
  "qs-passprompt",
  "qs-nowplaying",
  "qs-notes",
  "qs-wifi",
  "qs-notify",
  "qs-toasts",
  "qs-lyrics",
  "qs-theme",
  "qs-osd",
}) do
  frost(namespace)
end

-- Default-namespace panels (power, sysmon, battery, clipboard, fetch, clock,
-- screentime, phone, drives, watchcat, failwatch, keybinds) share one rule.
frost("quickshell")

-- Hornet pet -- only the PNG is visible, so no blur, no shadow, no animation.
hl.layer_rule({
  match = { namespace = "^qs-pet$" },
  blur = false,
  ignore_alpha = 0.01,
  no_anim = true,
  xray = 1,
})