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
    // "Associated to an AP" is not "has internet". A captive portal or a dead
    // uplink leaves essid set, so `disconnected` is false and the pill claimed
    // success regardless. This adds the third state -- associated but not
    // online -- and signals it with COLOUR ONLY.
    //
    // No new icon on purpose. At the 11px this pill renders at, md-wifi,
    // md-wifi_alert and md-wifi_off are effectively identical: the dot and
    // slash that distinguish them are sub-pixel. Adding a glyph would have
    // looked like nothing changed. Border and text go amber, which is readable
    // at any size and leaves the icons alone.
    readonly property bool noInternet: essid !== "" && !ethUp && !online
    property bool online: true
    Process {
        id: netProbe
        // TCP connect, no DNS: a name lookup would make the probe itself
        // something that can fail for the wrong reason.
        command: ["sh", "-c", "timeout 3 bash -c '</dev/tcp/1.1.1.1/443' 2>/dev/null && echo up || echo down"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.online = text.trim() === "up"
        }
    }
    Timer {
        interval: 30000; running: true; repeat: true
        onTriggered: {
            // optimistic reset, so one flaky probe cannot latch "down"
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
                    : root.noInternet ? colors.alpha(colors.tertiary, 0.55)
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
            text: root.ethUp ? "󰈀 Ethernet"
                : root.essid !== "" ? "󰖩 " + root.essid
                : "󰖪 Off"
            color: root.disconnected ? colors.error
                 : root.noInternet ? colors.tertiary
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
