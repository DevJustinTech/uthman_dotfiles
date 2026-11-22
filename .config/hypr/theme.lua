-- Matugen wallpaper palette -> Hyprland border colours.
--
-- Matugen writes ~/.config/theme/colors.lua. Loading it with dofile() avoids
-- relying on Omarchy's package.path bootstrap; on a fresh clone the file does
-- not exist yet, so fall back to neutral greys and keep Hyprland startable.

local path = (os.getenv("HOME") or "") .. "/.config/theme/colors.lua"
local ok, colors = pcall(dofile, path)

if ok and type(colors) == "table" then
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
