import Quickshell
import Quickshell.Io
import QtQuick

// Palette parsed live from Matugen's ~/.config/quickshell/colors.css.
// Matugen-generated palette — theme changes propagate instantly
// via FileView's native file watching.
//
// It is also the home of the liquid-glass material. Surfaces opt in by
// binding the glass tokens below (or by using components/Glass.qml) — no
// component owns its own material numbers. Two Colors instances exist
// (Bar.qml and shell.qml); state is shared through
// ~/.cache/quickshell/glass.json and polled, the same way colors.css is.
Item {
    id: root

    property string colorsFile: Quickshell.env("HOME") + "/.config/quickshell/colors.css"

    property color background: "#17130f"
    property color foreground: "#ebe1da"
    property color primary: "#f3bc87"
    property color secondary: "#dfc1a8"
    property color tertiary: "#9bcee3"
    property color error: "#ffb4ab"
    property color surface: "#17130f"
    property color on_surface: "#efe5df"
    property color surfaceVariant: "#50453b"
    property color outline: "#a39487"

    readonly property real pillBg: 0.6
    readonly property real pillBgHover: 0.8
    readonly property real pillBorder: 0.15
    readonly property real pillBorderHover: 0.45

    // Single font knob — swap here to re-font every module.
    readonly property string fontSans: "FiraCode Nerd Font"

    readonly property string fontHeading: "FiraCode Nerd Font"

    function apply(css) {
        var re = /@define-color\s+(\w+)\s+(#[0-9a-fA-F]{6})\s*;/g
        var m
        var map = {}
        while ((m = re.exec(css)) !== null) {
            map[m[1].toLowerCase()] = m[2]
        }
        if (map["background"]) background = hexToColor(map["background"])
        if (map["foreground"]) foreground = hexToColor(map["foreground"])
        if (map["primary"]) primary = hexToColor(map["primary"])
        if (map["secondary"]) secondary = hexToColor(map["secondary"])
        if (map["tertiary"]) tertiary = hexToColor(map["tertiary"])
        if (map["error"]) error = hexToColor(map["error"])
        if (map["surface"]) surface = hexToColor(map["surface"])
        if (map["on_surface"]) on_surface = hexToColor(map["on_surface"])
        if (map["surface_variant"]) surfaceVariant = hexToColor(map["surface_variant"])
        if (map["outline"]) outline = hexToColor(map["outline"])
    }

    function hexToColor(h) {
        var r = parseInt(h.substr(1, 2), 16) / 255
        var g = parseInt(h.substr(3, 2), 16) / 255
        var b = parseInt(h.substr(5, 2), 16) / 255
        return Qt.rgba(r, g, b, 1)
    }

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    // ── Liquid glass ────────────────────────────────────────────────────
    // One set of variables per state; a surface opts in by using them.
    // Numbers follow the material brief: tints are bands of five steps,
    // ink is one colour in fixed steps, the rim is painted light (Qt has no
    // backdrop displacement; the bend itself is the one effect this stack
    // cannot render — see components/Glass.qml).

    readonly property string glassStateFile: Quickshell.env("HOME") + "/.cache/quickshell/glass.json"
    readonly property string glassSampleFile: Quickshell.env("HOME") + "/.cache/quickshell/glass-sample.json"

    property bool glassOn: false            // the toggle; off = today's look
    property real glassLightTint: 1.0       // 0..1.5, light theme
    property real glassDarkTint: 1.0        // 0..1.5, dark theme
    property string glassInkMode: "auto"    // auto | light | dark
    property var glassSamples: ({})         // per-surface sampler output
    property real glassLastWrite: 0         // suppress stale poll right after a write

    // Surfaces whose every text/icon colour is wired to the ink tokens.
    // Only these may flip the tint family to dark glass in a light theme;
    // everything else keeps theme ink on the light (white) glass — the
    // brief's safe fallback rather than dark ink on a dark tint.
    readonly property var glassInkReady: ["toast"]

    // The palette itself tells us which matugen scheme is live: light and dark
    // backgrounds sit on opposite sides of 0.5 luminance.
    readonly property bool darkTheme: luminance(background) < 0.5
    readonly property real glassTintScale: darkTheme ? glassDarkTint : glassLightTint

    function luminance(c) { return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b }
    function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }
    function clamp01(v) { return clamp(v, 0, 1) }

    function glassDensity(surfaceId) {
        var s = glassSamples ? glassSamples[surfaceId] : null
        if (s && typeof s.density === "number") return clamp01(s.density)
        return 0.35
    }

    // Ink first: it decides the tint family. Dark themes are always light
    // text. In a light theme only ink-ready surfaces flip on the sampled
    // scene luminance (the sampler applies the ±0.05 hysteresis); the rest
    // keep dark theme ink on white glass.
    function glassInkFor(surfaceId) {
        if (!glassOn) return darkTheme ? "light" : "dark"
        if (glassInkMode === "light" || glassInkMode === "dark") return glassInkMode
        if (darkTheme) return "light"
        if (glassInkReady.indexOf(surfaceId) < 0) return "dark"
        var s = glassSamples ? glassSamples[surfaceId] : null
        if (!s) return "dark"
        if (s.ink === "light" || s.ink === "dark") return s.ink
        if (typeof s.lum === "number") return s.lum < 0.5 ? "light" : "dark"
        return "dark"
    }

    // The tint, banded (density 0 → thinnest, 1 → densest):
    //   light glass (light scene, dark ink)       white 6–22%,  steps of 4
    //   light theme over a dark area              rgb(16 18 22) 10–30%
    //   dark theme                                rgb(20 20 24) 16–38%
    // tintScale multiplies the alpha (the §5 slider); hover brightens by 14%.
    function glassCardColor(surfaceId, hovered, densityOverride) {
        if (!glassOn) return "transparent"
        if (hovered === undefined) hovered = false
        var d = (densityOverride !== undefined && densityOverride >= 0)
              ? clamp01(densityOverride) : glassDensity(surfaceId)
        var band = Math.round(d * 4)
        var lightInk = glassInkFor(surfaceId) === "light"
        var a

        if (darkTheme || lightInk) {
            a = (darkTheme ? 0.16 + band * 0.055 : 0.10 + band * 0.05) * glassTintScale
            if (hovered) a *= 1.14
            a = clamp01(a)
            return darkTheme ? Qt.rgba(20 / 255, 20 / 255, 24 / 255, a)
                             : Qt.rgba(16 / 255, 18 / 255, 22 / 255, a)
        }

        a = (0.06 + band * 0.04) * glassTintScale
        if (hovered) a *= 1.14
        return Qt.rgba(1, 1, 1, clamp01(a))
    }

    // A highlighted row is a lighter layer of the glass — never a grey wash.
    // state: 0 idle, 1 hover, 2 selected.
    function glassRowColor(surfaceId, state) {
        if (!glassOn) return "transparent"
        var lightScene = !darkTheme && glassInkFor(surfaceId) === "dark"
        if (lightScene) {
            if (state === 2) return Qt.rgba(1, 1, 1, 0.76)
            if (state === 1) return Qt.rgba(1, 1, 1, 0.42)
            return "transparent"
        }
        // dark glass — the same layers at a third of their strength
        if (state === 2) return Qt.rgba(1, 1, 1, darkTheme ? 0.26 : 0.30)
        if (state === 1) return Qt.rgba(1, 1, 1, darkTheme ? 0.14 : 0.16)
        return "transparent"
    }

    function glassRowBorder(surfaceId, state) {
        if (!glassOn) return "transparent"
        var lightScene = !darkTheme && glassInkFor(surfaceId) === "dark"
        if (state === 2) return Qt.rgba(1, 1, 1, lightScene ? 0.80 : 0.30)
        if (state === 1) return Qt.rgba(1, 1, 1, lightScene ? 0.45 : 0.16)
        return "transparent"
    }

    // A bar pill is a lighter frosted layer on the island, not a second scene
    // tint. It brightens on hover; the base gradient in Glass protects the
    // small ink from a bright backdrop.
    function glassPillColor(hovered) {
        if (!glassOn) return "transparent"
        if (darkTheme) return Qt.rgba(1, 1, 1, hovered ? 0.24 : 0.16)
        return Qt.rgba(1, 1, 1, hovered ? 0.52 : 0.36)
    }


    function glassCardBorder(surfaceId, selected) {
        if (!glassOn) return "transparent"
        var lightInk = glassInkFor(surfaceId) === "light"
        if (lightInk) return Qt.rgba(1, 1, 1, selected ? 0.42 : 0.19)
        return Qt.rgba(0, 0, 0, selected ? 0.18 : 0.12)
    }

    // The inner light lives in Glass.qml; dark glass gets a third of it.
    function glassInnerStrengthFor(surfaceId) {
        return (glassOn && glassInkFor(surfaceId) === "light") ? 0.34 : 1.0
    }

    // Ink, one colour in fixed steps, for everything drawn on the glass.
    // Icons still draw opaque and fade as a whole item.
    function inkTitle(surfaceId, fallback) {
        if (!glassOn) return fallback
        return glassInkFor(surfaceId) === "light"
             ? Qt.rgba(1, 1, 1, 0.94)
             : Qt.rgba(0, 0, 0, 0.86)
    }

    function inkSecondary(surfaceId, fallback) {
        if (!glassOn) return fallback
        return glassInkFor(surfaceId) === "light"
             ? Qt.rgba(235 / 255, 235 / 255, 245 / 255, 0.64)
             : Qt.rgba(60 / 255, 60 / 255, 67 / 255, 0.70)
    }

    // Shape-based surfaces (the bar island) can't inherit Glass.qml, so they
    // bind the same tint directly.
    function glassShapeFill(surfaceId) { return glassCardColor(surfaceId, false) }

    function applyGlassState(txt) {
        if (Date.now() < glassLastWrite + 900) return
        var o = null
        try { o = JSON.parse(txt) } catch (e) { return }
        if (!o || typeof o !== "object") return
        if (typeof o.enabled === "boolean") glassOn = o.enabled
        if (typeof o.lightTint === "number") glassLightTint = clamp(o.lightTint, 0, 1.5)
        if (typeof o.darkTint === "number") glassDarkTint = clamp(o.darkTint, 0, 1.5)
        if (o.inkMode === "light" || o.inkMode === "dark" || o.inkMode === "auto") glassInkMode = o.inkMode
    }

    function applyGlassSamples(txt) {
        try {
            var o = JSON.parse(txt)
            if (o && typeof o === "object") glassSamples = o
        } catch (e) {}
    }

    function saveGlass() {
        glassLastWrite = Date.now()
        var payload = JSON.stringify({
            enabled: glassOn,
            lightTint: glassLightTint,
            darkTint: glassDarkTint,
            inkMode: glassInkMode
        })
        Quickshell.execDetached(["sh", "-c",
            "mkdir -p \"$HOME/.cache/quickshell\" && printf '%s' '" + payload + "' > \"$HOME/.cache/quickshell/glass.json\" && \"$HOME/.local/bin/glass-apply\""])
    }

    function setGlass(on) { glassOn = on; saveGlass() }
    function toggleGlass() { setGlass(!glassOn) }
    function setTint(which, v) {
        v = clamp(v, 0, 1.5)
        if (which === "light") glassLightTint = v
        else glassDarkTint = v
        saveGlass()
    }

    // poll cheaply; text() triggers an async read, onLoaded applies
    // Matugen REPLACES colors.css (new inode) on every theme switch, which
    // silently breaks FileView's watcher. Poll + force a fresh read by
    // resetting path — cheap for a 300-byte file, bulletproof against replaces.
    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!root.colorsFile) return
            colorsView.path = ""
            colorsView.path = root.colorsFile
        }
    }

    // Glass state changes on user action; 500ms keeps two Colors instances
    // (Bar + ShellRoot) within a blink of each other.
    Timer {
        interval: 500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (Date.now() < root.glassLastWrite + 900) return
            glassView.path = ""
            glassView.path = root.glassStateFile
        }
    }

    // Sampler output changes only on wallpaper/theme/geometry changes.
    Timer {
        interval: 1500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            sampleView.path = ""
            sampleView.path = root.glassSampleFile
        }
    }

    FileView {
        id: colorsView
        path: root.colorsFile
        printErrors: false
        onLoaded: root.apply(text())
    }

    FileView {
        id: glassView
        path: root.glassStateFile
        printErrors: false
        onLoaded: root.applyGlassState(text())
    }

    FileView {
        id: sampleView
        path: root.glassSampleFile
        printErrors: false
        onLoaded: root.applyGlassSamples(text())
    }
}
