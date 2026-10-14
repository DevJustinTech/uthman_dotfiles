-- Extra autostart processes, on top of the ones Omarchy's defaults run
-- (systemd env import, monitor watch, udiskie, power profiles, post-boot hooks).

local home = os.getenv("HOME")

hl.on("hyprland.start", function()
  -- Clipboard history. Quickshell's clipboard panel reads from cliphist.
  hl.exec_cmd("wl-paste --watch cliphist store")

  -- Wallpaper daemon. Omarchy's own background switcher was part of the shell
  -- we replaced, so awww owns the wallpaper now. Guarded: without it there is
  -- simply no desktop background rather than a red error on every login.
  if o.cmd_present("awww") then
    hl.exec_cmd("setsid awww-daemon >/dev/null 2>&1 &")

    -- Paint the wallpaper with no transition so login does not animate in.
    hl.exec_cmd(string.format(
      "sh -c 'sleep 0.5; awww img \"$(readlink %s/.config/theme/current/background)\" --transition-type none'",
      o.shell_quote(home)))
  end

  -- Pointer theme matching the current wallpaper palette.
  hl.exec_cmd(home .. "/.local/bin/matugen-cursor")

  -- The desktop shell: bar, panels, OSD, notifications, and the launcher.
  -- This is the Quickshell instance that replaced omarchy-shell, so it is the
  -- only owner of org.freedesktop.Notifications. autostart.lua under
  -- ~/.config/default/hypr/ is what stops the original from starting too.
  hl.exec_cmd("setsid quickshell -p ~/.config/quickshell >/dev/null 2>&1 &")

  -- swayosd would fight the shell's own OSD for the same chord. Mask it.
  hl.exec_cmd("pkill -x swayosd-server")

  -- Idle + lock. Omarchy's shell used to own this via shell.json's idle.lock /
  -- idle.screensaver, and that shell is no longer running, so nothing would
  -- ever lock the screen. hypridle reads ~/.config/hypr/hypridle.conf, which
  -- hypridle loads by convention.
  hl.exec_cmd(o.launch("hypridle"))

  -- Wipe runaway capture overlays (slurp/hyprpicker) if a key sticks at login.
  hl.exec_cmd(home .. "/.config/hypr/scripts/picker-guard.sh")
end)