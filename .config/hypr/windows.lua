-- Window rules: float/centre/size for every Quickshell window, plus the app
-- overrides this desktop cares about.
--
-- Loaded after default.hypr.windows, so these run after Omarchy's own rules.

-- Every shell surface is the Quickshell window. Upstream Quickshell reports
-- its class as "quickshell"; older builds and some launch paths report the
-- fully-qualified "org.quickshell". The old .conf spelled both out as six
-- duplicated rules per window -- one regex covers them both instead.
local QS = "^(quickshell|org.quickshell)$"

-- Centre a shell window at a fixed size, or pin it with an x/y instead.
--
-- Keep every height at 644 or under. This screen is 1366x768 and the bar is 54
-- tall, so a centred window any taller puts its top edge behind the bar -- and
-- because the opaque part of the bar is the island in its middle, what
-- disappears is the middle of the panel rather than a corner. Four were over:
-- ThemeEditor 740, Clipboard 730, Wallshelf 700, Screen Time 660.
local function shell_window(title, width, height, x, y)
  local rule = { match = { class = QS, title = title }, float = true, size = { width, height } }
  if x then rule.move = { x, y } else rule.center = true end
  hl.window_rule(rule)
end

shell_window("System Monitor", 840, 560)
shell_window("Monitors", 440, 560)
shell_window("ThemeEditor", 440, 560)
shell_window("Earbuds", 380, 400)
shell_window("Bluetooth", 440, 520)
-- DriveHealth's window title is "Hardware Health", not the module name.
hl.window_rule({ match = { class = QS, title = "^Hardware Health$" }, float = true, center = true, size = { 580, 560 } })
shell_window("Dictionary", 520, 460)
shell_window("Package Manager", 840, 560)
shell_window("WatchCat", 820, 400)
-- Control Center opens bottom-left instead of centred -- it gets opened often
-- while other windows are in use, so it stays out of the way. 218 = 768 - 540
-- - 10, putting a gaps_out-sized margin on the bottom and left edges.
shell_window("Control Center", 700, 540, 10, 218)
shell_window("PDF Library", 860, 560)
shell_window("Wallshelf", 860, 560)
shell_window("Pomodoro", 380, 500)
shell_window("GitHubDash", 700, 500)
shell_window("QuickNotes", 440, 540)
-- Was 660x730, which put the top edge 35px behind the bar; the note on
-- shell_window above is the arithmetic.
shell_window("Clipboard", 540, 560)
shell_window("Screen Time", 660, 560)
shell_window("Grap", 560, 440)
shell_window("Clock", 360, 408)
shell_window("System", 440, 230)

-- ── Applications ────────────────────────────────────────────────────────

-- Zathura -- glass float. The third opacity value is the fullscreen one, which
-- is what keeps the glass when it covers the screen (deco fullscreen_opacity
-- would otherwise win).
hl.window_rule({ match = { class = "^(org.pwmt.zathura)$" }, float = true, center = true, size = { 1100, 750 }, border_size = 0 })
hl.window_rule({ match = { class = "^(org.pwmt.zathura)$" }, opacity = "0.78 0.70 0.78" })

-- mpv -- centred floating popup.
hl.window_rule({ match = { class = "^(mpv)$" }, float = true, center = true, size = { 960, 540 } })

-- File-manager picker -- same treatment as mpv.
hl.window_rule({ match = { class = "^(com.codetesla51.filemanager.picker)$" }, float = true, center = true, size = { 960, 540 } })

-- Screensaver -- foot fullscreen, no decorations.
hl.window_rule({ match = { class = "org.screensaver" }, float = true, fullscreen = true })

-- Zen -- glass chrome draws its own edges.
hl.window_rule({ match = { class = "^zen$" }, border_size = 0 })

-- Loupe -- small centred image popup instead of a full window.
hl.window_rule({ match = { class = "org.gnome.Loupe" }, float = true, center = true, size = { 880, 680 } })

-- Zed -- translucent editor. gen-zed-theme sets editor backgrounds to #rrggbbaa
-- and background.appearance=transparent, so the surface is see-through and the
-- global decoration.blur in looknfeel.lua supplies the blur behind it.
-- Without `opaque off`, Hyprland treats the window as opaque and skips it.
-- NOTE: blur/ignore_alpha are layer-rule-only -- as window rules they throw
-- "invalid field type". `opaque off` alone is the correct recipe here.
hl.window_rule({ match = { class = "^dev.zed.Zed$" }, opaque = false })
hl.window_rule({ match = { class = "^zed$" }, opaque = false })

-- Terminal touchpad scrolling used to live here as a kitty/Alacritty rule.
-- Omarchy's default input.lua now owns it (it also covers foot and ghostty),
-- so duplicating it here would just be a second copy to keep in sync.