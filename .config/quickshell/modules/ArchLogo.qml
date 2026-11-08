import Quickshell
import QtQuick
import "../components"

// Arch logo pill — waybar #custom-arch parity:
// 󰌽 glyph at 16px, primary color, glass island slightly brighter than others.
Item {
    id: root

    property var colors
    property bool hovered: logoMouse.containsMouse

    implicitWidth: label.implicitWidth + 26
    implicitHeight: 30

    Glass {
        anchors.fill: parent
        radius: 14
        surfaceId: "bar-pill"
        raised: true
        colors: root.colors
        hovered: root.hovered
        classicColor: root.hovered ? colors.alpha(colors.surface, 0.75) : colors.alpha(colors.surface, 0.55)
        classicBorder: root.hovered ? colors.alpha(colors.primary, 0.45) : colors.alpha(colors.outline, 0.15)
        classicBorderWidth: 1

        Text {
            id: label
            anchors.centerIn: parent
            text: ""
            color: colors.primary
            font.family: colors.fontSans
            font.pixelSize: 16
        }

        MouseArea {
            id: logoMouse
            anchors.fill: parent
            hoverEnabled: true
            // This pill was hover-styled but had no click handler at all --
            // it looked live and did nothing. Wire it to the same launcher
            // panel SUPER+SPACE opens, which is what a distro glyph in the
            // corner of a bar is expected to do.
            onClicked: Quickshell.execDetached([
                "sh", "-c",
                "quickshell -p ~/.config/quickshell ipc call launcher toggle"
            ])
        }
    }
}
