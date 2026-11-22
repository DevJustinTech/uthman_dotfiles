-- Autostart for a standalone Hyprland session.
--
-- Everything is wrapped in the hyprland.start event: a top-level exec_cmd runs
-- at config-parse time (including during a reload) and would respawn processes.

local home = os.getenv("HOME")

hl.on("hyprland.start", function()
  -- Session environment for systemd user units and D-Bus activation.
  hl.exec_cmd("systemctl --user import-environment $(env | cut -d'=' -f 1)")
  hl.exec_cmd("dbus-update-activation-environment --systemd --all")

  -- Clipboard history. Quickshell's clipboard panel reads from cliphist.
  hl.exec_cmd("wl-paste --watch cliphist store")

  -- Wallpaper daemon. Guarded: without it there is simply no background rather
  -- than a failed command on every login.
  if o.cmd_present("awww") then
    hl.exec_cmd("setsid awww-daemon >/dev/null 2>&1 &")
    hl.exec_cmd(string.format(
      "sh -c 'sleep 0.5; awww img \"$(readlink %s/.config/theme/current/background)\" --transition-type none'",
      o.shell_quote(home)))
  end

  -- Pointer theme matching the current wallpaper palette.
  if o.cmd_present(home .. "/.local/bin/matugen-cursor") then
    hl.exec_cmd(home .. "/.local/bin/matugen-cursor")
  end

  -- The desktop shell: bar, panels, OSD, notifications, and the launcher. It is
  -- the only owner of org.freedesktop.Notifications in this session.
  hl.exec_cmd("setsid quickshell -p ~/.config/quickshell >/dev/null 2>&1 &")

  -- swayosd would fight the shell's own OSD for the same keys. Mask it.
  hl.exec_cmd("pkill -x swayosd-server 2>/dev/null || true")

  -- Idle + lock (hypridle reads ~/.config/hypr/hypridle.conf by convention).
  if o.cmd_present("hypridle") then
    hl.exec_cmd(o.launch("hypridle"))
  end

  -- Removable-drive automount and input-method support, when installed.
  if o.cmd_present("udiskie") then
    hl.exec_cmd(o.launch("udiskie --automount --no-notify --no-tray"))
  end
  if o.cmd_present("fcitx5") then
    hl.exec_cmd(o.launch("fcitx5 --disable notificationitem"))
  end

  -- Polkit agent for GUI privilege prompts. Arch's polkit-gnome installs this
  -- path; without an agent, pkexec-based dialogs silently fail.
  local polkit = "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"
  if o.cmd_present(polkit) then
    hl.exec_cmd(polkit)
  end

  -- Wipe runaway capture overlays if a key sticks at login.
  hl.exec_cmd(home .. "/.config/hypr/scripts/picker-guard.sh")
end)
