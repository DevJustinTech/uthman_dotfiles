-- Matugen wallpaper palette -> Hyprland border colours.
--
-- This replaces the old `source = ~/.config/theme/current/colors.conf` line,
-- which is dead under Hyprland's Lua config. The palette is generated instead
-- as a Lua module by matugen and picked up with require(); see
-- ~/.config/matugen/templates/hyprland-colors.lua.
--
-- Required after default.hypr.omarchy so these win over the stock Omarchy
-- theme's border colours.
--
-- Before the first `matugen image` run there is no palette on disk. That is a
-- normal state on a fresh clone, not an error: fall back to the same neutral
-- greys the config used to hardcode, so Hyprland always starts with a valid
-- border colour.

local require_optional = require("default.hypr.require_optional")

-- bootstrap.lua clears package.loaded for anything under "omarchy.current.theme"
-- and "default.hypr" on reload, but NOT for "theme.colors" -- this module.
-- Without dropping it here, a reload would re-apply the palette captured on the
-- very first load and the wallpaper change would appear to do nothing to the
-- borders.
package.loaded["theme.colors"] = nil

local colors = require_optional.module("theme.colors")

if colors then
  hl.config({
    general = {
      col = {
        active_border = { colors = { colors.primary, colors.secondary }, angle = 45 },
        inactive_border = colors.outline,
      },
    },
    group = {
      col = {
        border_active = colors.primary,
        border_inactive = colors.outline,
      },
    },
  })
else
  -- No wallpaper palette yet. `matugen image <wallpaper>` (or set-wallpaper)
  -- fills this in on the next run.
  hl.config({
    general = {
      col = {
        active_border = { colors = { "rgba(33ccffee)", "rgba(00ff99ee)" }, angle = 45 },
        inactive_border = "rgba(595959aa)",
      },
    },
  })
end