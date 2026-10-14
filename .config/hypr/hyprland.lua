-- Omarchy's bootstrap owns path setup and module reloading. Do not inline it.
dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")

-- Omarchy defaults stay ENABLED. This config used to vendor frozen copies of
-- them under hypr/vendor/, which drifted from the real defaults and is now
-- dead weight: Omarchy ships them as Lua. bindings.lua unbinds the handful of
-- chords this desktop actually replaces, so we inherit tiling, media, and
-- utility binds for free and pick up upstream improvements on update.
require("default.hypr.omarchy")

-- Personal overrides, loaded after the defaults so they win on every key.
-- Order matters where one file narrows another: theme repaints the border
-- colours that looknfeel lays down, and toggles must follow input so it can
-- disable a device this config just configured.
require("hypr.envs")
require("hypr.theme")
require("hypr.monitors")
require("hypr.input")
require("hypr.looknfeel")
require("hypr.windows")
require("hypr.bindings")
require("hypr.autostart")

-- Toggle config flags dynamically (input devices, workspace layout).
require("default.hypr.toggles")