import Quickshell
import Quickshell.Io
import QtQuick
import "../components"

// WatchCat pill — hotspot data watchdog. Shows live down-rate (NetRate),
// glass island with tertiary accent; error border while currently hot
// (>500 KB/s). All tracking/alerts live in the watchcat.service daemon
// (scripts/watchcat-daemon.py) — this pill displays, it doesn't log.
Item {
    id: root

    property var colors
    property bool hovered: wcMouse.containsMouse
    signal openRequested()

    readonly property real hotKbs: 500

    NetRate { id: rate }

    readonly property bool hot: rate.rxKbs >= hotKbs

    implicitWidth: label.implicitWidth + 32
    implicitHeight: 30

    Glass {
        anchors.fill: parent
        radius: 14
        surfaceId: "bar-pill"
        raised: true
        colors: root.colors
        hovered: root.hovered
        classicColor: root.hovered ? colors.alpha(colors.surface, 0.75) : colors.alpha(colors.surface, 0.55)
        classicBorder: root.hot ? colors.alpha(colors.error, 0.5)
                    : root.hovered ? colors.alpha(colors.tertiary, 0.45)
                    : colors.alpha(colors.outline, 0.15)
        classicBorderWidth: 1
        preserveBorder: root.hot

        Text {
            id: label
            anchors.centerIn: parent
            text: "↓ " + rate.fmt(rate.rxKbs)
            color: root.hot ? colors.error : root.hovered ? colors.foreground : colors.tertiary
            font.family: colors.fontSans
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.letterSpacing: 0.3
            Behavior on color { ColorAnimation { duration: 300 } }
        }

        MouseArea {
            id: wcMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.openRequested()
        }
    }
}
