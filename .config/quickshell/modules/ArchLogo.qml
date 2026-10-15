import Quickshell
import QtQuick

// Arch logo pill — waybar #custom-arch parity:
// 󰌽 glyph at 16px, primary color, glass island slightly brighter than others.
Item {
    id: root

    property var colors
    property bool hovered: logoMouse.containsMouse

    implicitWidth: label.implicitWidth + 26
    implicitHeight: 30

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: root.hovered ? colors.alpha(colors.surface, 0.75) : colors.alpha(colors.surface, 0.55)
        border.width: 1
        border.color: root.hovered ? colors.alpha(colors.primary, 0.45) : colors.alpha(colors.outline, 0.15)

        Behavior on color { ColorAnimation { duration: 300 } }
        Behavior on border.color { ColorAnimation { duration: 300 } }

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
