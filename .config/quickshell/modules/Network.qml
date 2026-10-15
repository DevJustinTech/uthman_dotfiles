import Quickshell
import Quickshell.Io
import Quickshell.Networking
import QtQuick

// Network pill — glass island, primary accent; disconnected → error (waybar parity).
Item {
    id: root

    property var colors
    property bool hovered: netMouse.containsMouse
    signal openRequested()

    readonly property var devices: Networking.devices.values
    readonly property var wifiDev: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wiredDev: devices.find(d => d.type === DeviceType.Wired) ?? null
    readonly property bool ethUp: wiredDev ? wiredDev.hasLink && wiredDev.connected : false
    readonly property var wifiNet: {
        if (!wifiDev || !wifiDev.connected) return null
        var nets = wifiDev.networks ? wifiDev.networks.values : []
        return nets.find(n => n.connected) ?? null
    }
    readonly property string essid: wifiNet ? (wifiNet.name ?? "").trim() : ""
    readonly property bool disconnected: !ethUp && essid === ""
    // "Associated to an AP" is not the same as "has internet". A captive
    // portal or a dead uplink leaves essid set and connectivity false, and the
    // pill used to claim success in that state. Kept deliberately simple: any
    // successful TCP connect to a well-known host counts, no DNS involved, so
    // it cannot itself be what is broken.
    property bool online: true
    Process {
        id: netProbe
        command: ["sh", "-c", "timeout 3 bash -c '</dev/tcp/1.1.1.1/443' 2>/dev/null && echo up || echo down"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.online = text.trim() === "up"
        }
    }
    Timer {
        interval: 30000; running: true; repeat: true
        onTriggered: {
            // Optimistic reset so a flaky probe cannot leave a stale "down".
            if (root.disconnected) root.online = true
            netProbe.running = true
        }
    }

    // compact cap — small names stay small, long SSIDs elide at ~96px total
    readonly property int maxLabelW: 64
    implicitWidth: Math.min(label.implicitWidth + 32, root.maxLabelW + 32)
    implicitHeight: 30

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: root.hovered ? colors.alpha(colors.surface, 0.75) : colors.alpha(colors.surface, 0.55)
        border.width: 1
        border.color: root.disconnected ? colors.alpha(colors.error, 0.3)
                    : root.hovered ? colors.alpha(colors.primary, 0.45)
                    : colors.alpha(colors.outline, 0.15)

        Behavior on color { ColorAnimation { duration: 300 } }
        Behavior on border.color { ColorAnimation { duration: 300 } }

        Text {
            id: label
            anchors.centerIn: parent
            width: Math.min(implicitWidth, root.maxLabelW)
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            // GLYPHS VERIFIED BY NAME against FiraCode Nerd Font. Do not "fix" by eye:
            //   md-ethernet   = U+F0200  (was correct)
            //   md-wifi       = U+F05A9  connected
            //   md-wifi_alert = U+F16B5  associated, but no internet
            //   md-wifi_off   = U+F05AA  no association at all
            //
            // The connected branch used U+F06A9, which is md-robot -- a robot
            // head. Verified by name and rendered side by side to confirm.
            text: root.ethUp ? "󰈀 Ethernet"
                : root.essid !== "" ? (root.online ? "󰤩 " : "󰘵 ") + root.essid
                : "󰖪 Off"
            color: root.disconnected ? colors.error
                 : root.hovered ? colors.foreground
                 : colors.primary
            font.family: colors.fontSans
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.letterSpacing: 0.3
            Behavior on color { ColorAnimation { duration: 300 } }
        }

        MouseArea {
            id: netMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.openRequested()
        }
    }
}
