-- Hyprland configuration — Lua entry point (standalone Arch install).
--
-- The presence of this file at startup selects the Lua config; hyprland.conf is
-- then ignored entirely. It is checked once at startup, so deleting it and
-- running `hyprctl reload` does NOT fall back to hyprland.conf — a full
-- Hyprland restart is required.
--
-- No Omarchy packages are required. The vendored defaults in vendor/ are
-- sanitized copies of the old Omarchy defaults, kept here so a fresh Arch
-- install has the same keymap and window behaviour without /usr/share/omarchy.

require("helpers")

-- ── Vendored defaults ──────────────────────────────────────────────────────
require("vendor.envs")
require("vendor.looknfeel")
require("vendor.input")
require("vendor.windows")
require("vendor.bindings.media")
require("vendor.bindings.clipboard")
require("vendor.bindings.tiling")
require("vendor.bindings.utilities")

-- ── Personal overrides ─────────────────────────────────────────────────────
-- theme after vendor.looknfeel: the wallpaper palette must win over the
-- hardcoded border colours in the vendored defaults.
require("theme")
require("envs")
require("monitors")
require("input")
require("looknfeel")
require("windows")
require("bindings")
require("autostart")

-- Persisted device toggles. Kept as Lua so `hyprctl reload` re-applies them;
-- the helper scripts write these files.
local state = (os.getenv("HOME") or "") .. "/.local/state/hypr/"
pcall(dofile, state .. "touchpad-disabled.lua")
pcall(dofile, state .. "internal-monitor-disabled.lua")
