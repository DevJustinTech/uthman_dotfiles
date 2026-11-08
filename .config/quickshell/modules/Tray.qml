import Quickshell
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Controls
import "../components"

// Tray — glass pill container (surface .6, radius 14, padding like waybar #tray),
// 13px icons, L-click activate, R-click menu, scroll passthrough, hover tooltips.
Item {
    id: root

    property var colors

    // hide icons for apps already represented elsewhere (Spotify → NowPlaying
    // pill) and apps that should not appear in the bar at all (LocalSend).
    readonly property var hiddenApps: ["spotify", "localsend"]
    readonly property var items: SystemTray.items.values.filter(function(it) {
        var s = ((it.id || "") + " " + (it.title || "")).toLowerCase()
        for (var i = 0; i < hiddenApps.length; i++)
            if (s.indexOf(hiddenApps[i]) !== -1) return false
        return true
    })

    implicitWidth: items.length > 0 ? frame.implicitWidth : 0
    implicitHeight: 30
    visible: items.length > 0

    Glass {
        id: frame
        anchors.centerIn: parent
        width: trayRow.implicitWidth + 20
        height: 22
        radius: 14
        surfaceId: "bar-pill"
        raised: true
        colors: root.colors
        classicColor: colors.alpha(colors.surface, 0.55)
        classicBorder: colors.alpha(colors.outline, 0.15)
        classicBorderWidth: 1

        Row {
            id: trayRow
            anchors.centerIn: parent
            spacing: 8

            Repeater {
                model: root.items

                delegate: Item {
                    id: trayEntry

                    required property var modelData
                    readonly property var item: modelData

                    width: 13
                    height: 13

                    Image {
                        anchors.fill: parent
                        source: trayEntry.item.icon
                        sourceSize.width: 13
                        sourceSize.height: 13
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        opacity: trayMouse.containsMouse ? 1 : 0.75
                    }

                    MouseArea {
                        id: trayMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: {
                            if (mouse.button === Qt.RightButton && trayEntry.item.hasMenu)
                                trayEntry.item.display()
                            else
                                trayEntry.item.activate()
                        }
                        onWheel: (wheel) => trayEntry.item.scroll(
                            wheel.angleDelta.y, wheel.angleDelta.x > 0)
                    }

                    ToolTip.visible: trayMouse.containsMouse && trayEntry.item.tooltipTitle !== ""
                    ToolTip.text: trayEntry.item.tooltipTitle
                    ToolTip.delay: 400
                }
            }
        }
    }
}
