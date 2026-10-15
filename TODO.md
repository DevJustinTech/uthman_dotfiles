# TODO

## Monitor scale — needs a logout to settle

`.config/hypr/monitors.conf` says scale `1` (1920x1080, integer 1:1) with
`GDK_SCALE,1` to match.

Live session still reports `1.2` — leftover runtime override from testing,
not a config bug. Reboot or re-login to pick up `1.0`.

Note: `1.15` was never going to work. Hyprland only accepts scales that divide
1920x1080 into whole pixels; `1920/1.15 = 1669.57`, so it silently snapped to
`1.2`. Reachable scales on this panel: **1.0, 1.2, 1.25, 1.5, 1.6, 2.0**.
`MonitorSettings.qml` already restricts its picker to exactly that set.