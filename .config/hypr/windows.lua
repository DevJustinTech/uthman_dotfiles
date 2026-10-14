-- Window rules: float/centre/size for every Quickshell window, plus the app
-- overrides this desktop cares about.
--
-- Loaded after default.hypr.windows, so these run after Omarchy's own rules.

-- Every shell surface is the Quickshell window. Upstream Quickshell reports
-- its class as "quickshell"; older builds and some launch paths report the
-- fully-qualified "org.quickshell". The old .conf spelled both out as six
-- duplicated rules per window -- one regex covers them both instead.
local QS = "^(quickshell|org.quickshell)$"

-- Centre a shell window at a fixed size.
local function shell_window(title, width, height)
  hl.window_rule({ match = { class = QS, title = title }, float = true, center = true, size = { width, height } })
end

shell_window("System Monitor", 920, 640)
shell_window("Monitors", 460, 620)
shell_window("PhoneBridge", 460, 520)
shell_window("ThemeEditor", 460, 740)
shell_window("Earbuds", 380, 420)
shell_window("Bluetooth", 440, 560)
shell_window("WhatsApp", 640, 720)
-- DriveHealth's window title is "Hardware Health", not the module name.
hl.window_rule({ match = { class = QS, title = "^Hardware Health$" }, float = true, center = true, size = { 600, 640 } })
shell_window("Dictionary", 560, 500)
shell_window("Package Manager", 980, 640)
shell_window("WatchCat", 920, 440)
shell_window("Control Center", 760, 600)
shell_window("PDF Library", 960, 640)
shell_window("Wallshelf", 980, 700)
shell_window("Pomodoro", 400, 540)
shell_window("GitHubDash", 760, 560)
shell_window("QuickNotes", 460, 600)
shell_window("Clipboard", 660, 730)
shell_window("Grap", 600, 470)
shell_window("Clock", 360, 408)

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

-- Screensaver -- kitty fullscreen, no decorations.
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