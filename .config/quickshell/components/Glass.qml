import QtQuick

// Glass — the liquid-glass material as one component.
//
// A drop-in Rectangle: geometry, radius, anchors and the module's own content
// stay exactly where they were. Set `classicColor` / `classicBorder` to what
// the surface painted before; when the mode is off every value is unchanged.
// When it is on, the four material declarations resolve from Colors.qml:
// fill, edge, rim/inner light and (optionally) ink.
//
// Qt cannot bend a backdrop: there is no url(#map) backdrop-filter on a
// Wayland surface. The rim is therefore painted light — a bright top/left
// edge with the brief's falloff feel, a darker bottom and a fixed 1.5px
// line — not displaced refraction. Everything else (colour from behind,
// thick-slab edge, state transitions) is real.
Rectangle {
    id: root

    property var colors: null
    property string surfaceId: ""
    property color classicColor: "transparent"
    property color classicBorder: "transparent"
    property int classicBorderWidth: 0
    property bool hovered: false
    property bool selected: false
    property bool interactive: false     // rows: hover/selected are glass layers
    property bool rim: true              // inner light + rim lines
    property bool preserveBorder: false  // error/state borders win (toasts, prompts)
    property real densityOverride: -1    // fixed density for small controls
    property real densityFloor: 0        // text-heavy panels: never thinner than this
    property bool raised: false          // nested bar pill: frosted layer + legibility base + lit rim

    readonly property bool glass: colors !== null && colors.glassOn
    readonly property bool darkGlass: glass && colors ? colors.glassInkFor(surfaceId) === "light" : true
    readonly property int rowState: selected ? 2 : hovered ? 1 : 0

    color: {
        if (!glass) return classicColor
        if (interactive) return colors.glassRowColor(surfaceId, rowState)
        if (raised) return colors.glassPillColor(hovered)
        var d = densityOverride
        if (d === undefined || d < 0)
            d = Math.max(colors.glassDensity(surfaceId), densityFloor)
        return colors.glassCardColor(surfaceId, hovered, d)
    }
    border.width: (glass && !preserveBorder) ? 1 : classicBorderWidth
    border.color: {
        if (glass && !preserveBorder) {
            return interactive ? colors.glassRowBorder(surfaceId, rowState)
                               : colors.glassCardBorder(surfaceId, selected)
        }
        return classicBorder
    }

    // Global state changes glide instead of jumping (mode, theme, tint scale).
    Behavior on color { ColorAnimation { duration: 240; easing.type: Easing.OutCubic } }
    Behavior on border.color { ColorAnimation { duration: 240; easing.type: Easing.OutCubic } }

    // Ink helpers for content: `color: card.inkTitle` where the card is the
    // direct parent, otherwise `colors.inkTitle("wifi", colors.foreground)`.
    readonly property color inkTitle: colors && glass
        ? colors.inkTitle(surfaceId, colors.foreground)
        : (colors ? colors.foreground : "white")
    readonly property color inkSecondary: colors && glass
        ? colors.inkSecondary(surfaceId, colors.alpha(colors.foreground, 0.7))
        : (colors ? colors.alpha(colors.foreground, 0.7) : "white")

    // Raised pills: a soft dark base inside the capsule keeps 11px ink
    // readable over a bright backdrop while the top edge stays clear glass.
    // Declared before the sheen so the rim and inner light sit above it.
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, root.radius - 1)
        visible: root.glass && root.raised && root.darkGlass
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.18; color: "transparent" }
            GradientStop { position: 0.48; color: Qt.rgba(20 / 255, 20 / 255, 24 / 255, 0.30) }
            GradientStop { position: 1.0; color: Qt.rgba(20 / 255, 20 / 255, 24 / 255, 0.52) }
        }
    }

    // ── rim + inner light ────────────────────────────────────────────────
    // Kept under the module's own children (they are declared after this
    // component's children), so content stays on top. Skipped below 32px,
    // where a rim reads as noise rather than thickness — except raised pills,
    // which are deliberately small yet still want the lit glass edge.
    Item {
        id: sheen
        anchors.fill: parent
        visible: root.glass && root.rim && (root.raised || (root.width >= 32 && root.height >= 32))
        // Raised pills are small; without a stronger rim the glass cue vanishes
        // at 22–30px. The island keeps the sampled inner strength.
        opacity: root.glass && root.colors
            ? (root.raised ? (root.darkGlass ? 0.85 : 1.0)
                           : root.colors.glassInnerStrengthFor(root.surfaceId))
            : 0
        Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

        // rim band width — min(44, short side / 3.5), never under 4
        readonly property real rw: Math.max(4, Math.min(44, Math.min(root.width, root.height) / 3.5))
        readonly property real edgeX: Math.min(root.radius, root.width / 2)
        readonly property real edgeY: Math.min(root.radius, root.height / 2)

        // inner light: a white wash from the top, brighter at the top left
        Rectangle {
            anchors.fill: parent
            radius: root.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, sheen.lit ? 0.06 : 0.16) }
                GradientStop { position: 0.55; color: Qt.rgba(1, 1, 1, 0.0) }
            }
        }
        Rectangle {
            anchors.fill: parent
            radius: root.radius
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, sheen.lit ? 0.04 : 0.10) }
                GradientStop { position: 0.45; color: Qt.rgba(1, 1, 1, 0.0) }
            }
        }

        // top rim: hard at the edge, easing inward; brighter at the left
        Rectangle {
            x: sheen.edgeX
            y: 0.75
            width: Math.max(0, root.width - 2 * sheen.edgeX)
            height: 1.5
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, sheen.lit ? 0.30 : 0.90) }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, sheen.lit ? 0.10 : 0.32) }
            }
        }

        // left rim
        Rectangle {
            x: 0.75
            y: sheen.edgeY
            width: 1.5
            height: Math.max(0, root.height - 2 * sheen.edgeY)
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, sheen.lit ? 0.22 : 0.62) }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, sheen.lit ? 0.05 : 0.14) }
            }
        }

        // soft glow just inside the top rim
        Rectangle {
            x: sheen.edgeX
            y: 0.75
            width: Math.max(0, root.width - 2 * sheen.edgeX)
            height: Math.min(sheen.rw, root.height * 0.35)
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, sheen.lit ? 0.02 : 0.05) }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
            }
        }

        // shade at the bottom, inside the rim
        Rectangle {
            x: sheen.edgeX
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 0.75
            width: Math.max(0, root.width - 2 * sheen.edgeX)
            height: 1
            color: Qt.rgba(0, 0, 0, sheen.lit ? 0.12 : 0.05)
        }

        // dark glass gets a third of the light, per the brief
        readonly property bool lit: root.darkGlass
    }
}
