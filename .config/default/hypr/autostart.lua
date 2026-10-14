-- SHADOW OF $OMARCHY_PATH/default/hypr/autostart.lua -- read this first.
--
-- This desktop replaced Omarchy's Quickshell shell with its own (the bar
-- island, 55 panel modules, and wallpaper-driven Matugen theming). Both shells
-- cannot run: they would each claim org.freedesktop.Notifications and the
-- same layer surfaces, and whichever lost the race would take the toasts down
-- with it.
--
-- Hyprland resolves `require("default.hypr.autostart")` against ~/.config
-- BEFORE $OMARCHY_PATH, so this file shadows the packaged default and
-- `hyprland.lua` picks it up with no change to any packaged file. Nothing
-- under /usr/share/omarchy is touched.
--
-- The only difference from upstream is that `omarchy-launch-shell` is gone.
-- Everything else is copied verbatim, including the comments, so a diff against
-- upstream stays readable.
--
-- ---> RE-SYNC CHECK: after an `omarchy update`, compare:
--        diff <(cat /usr/share/omarchy/default/hypr/autostart.lua) ~/.config/default/hypr/autostart.lua
--     Expect exactly one removed line: `hl.exec_cmd("omarchy-launch-shell")`.
--     If upstream adds new startup lines, copy them in.

hl.on("hyprland.start", function()
  -- Slow app launch fix -- set systemd vars before starting session services.
  hl.exec_cmd("systemctl --user import-environment $(env | cut -d'=' -f 1)")
  hl.exec_cmd("dbus-update-activation-environment --systemd --all")

  -- hl.exec_cmd("omarchy-launch-shell")   <-- intentionally omitted; see above.

  hl.exec_cmd("omarchy-provision-first-run")
  hl.exec_cmd("omarchy-powerprofiles-init")
  hl.exec_cmd(o.launch("omarchy-hyprland-monitor-watch"))
  hl.exec_cmd(o.launch("udiskie --automount --no-notify --no-tray"))

  -- Run post-boot hooks after startup config has loaded.
  hl.exec_cmd("sleep 2 && omarchy-hook post-boot")
end)