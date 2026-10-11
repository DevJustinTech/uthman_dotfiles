import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

// ThemeEditor — post-wallpaper theme tweaks (mode / scheme / contrast).
// Port of ui-options/theme option A (control strip). Opens after an explicit
// wallpaper pick (Wallshelf) or via SUPER ALT G. Apply re-runs getTheme with
// the chosen flags on the current wallpaper; choices persist in cache.
// HEIGHT BUDGET 820: margins 32 + header 30 + 6x10 gaps + wprow 84 + mode 92
//   + scheme 262 + contrast 78 + palette 100 + footer 56.
// TYPE SCALE: 9 caps labels · 11 body · 13 titles. Spacing: 16 / 10 / 14.
FloatingWindow {
    id: root
    property var colors
    property bool open: false
    property string fontUi: "JetBrainsMono Nerd Font Mono"

    title: "ThemeEditor"
    implicitWidth: 460
    implicitHeight: 820
    minimumSize: Qt.size(440, 760)
    maximumSize: Qt.size(480, 880)
    color: "transparent"
    visible: root.open || closeAnim.running

    // NOTE: no IpcHandler here on purpose. shell.qml owns target "themeedit"
    // and lazy-loads this module; a second handler for the same target wins
    // nothing and logs "registered but will not be used".

    // ── state ──
    property string mode: "dark"
    property string scheme: "scheme-fidelity"
    property double contrast: 0.2
    property string wallPath: ""
    property string wallName: ""
    property bool working: false
    property string statusMsg: ""
    property bool statusErr: false
    readonly property string stateFile: Quickshell.env("HOME") + "/.cache/quickshell/themeedit.json"
    readonly property var schemes: [
        { k: "scheme-content", t: "content" },
        { k: "scheme-expressive", t: "expressive" },
        { k: "scheme-fidelity", t: "fidelity" },
        { k: "scheme-fruit-salad", t: "fruit-salad" },
        { k: "scheme-monochrome", t: "monochrome" },
        { k: "scheme-neutral", t: "neutral" },
        { k: "scheme-rainbow", t: "rainbow" },
        { k: "scheme-tonal-spot", t: "tonal-spot" },
        { k: "scheme-vibrant", t: "vibrant" },
        { k: "scheme-smart", t: "smart" }
    ]

    function fmtC(v) { return (v >= 0 ? "+" : "") + v.toFixed(2) }
    function fmtCs(v) { return (v >= 0 ? "+" : "") + (Math.round(v * 10) / 10).toFixed(1) }
    function schemeName(k) { return String(k).replace(/^scheme-/, "") }

    onOpenChanged: {
        if (root.open) {
            root.statusMsg = ""
            root.statusErr = false
            loadProc.running = true
            wallProc.running = true
            card.forceActiveFocus()
            openAnim.restart()
        } else closeAnim.restart()
    }

    // current wallpaper: the live background symlink
    Process {
        id: wallProc
        command: ["sh", "-c", "readlink \"$HOME/.config/theme/current/background\" 2>/dev/null || readlink \"$HOME/.config/omarchy/current/background\" 2>/dev/null"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var p = text.trim()
                if (p !== "") {
                    root.wallPath = p
                    root.wallName = p.split("/").pop()
                }
            }
        }
    }
    // last choices (written on every successful apply)
    Process {
        id: loadProc
        command: ["sh", "-c", "cat \"" + root.stateFile + "\" 2>/dev/null"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var o = null
                try { o = JSON.parse(text) } catch (e) { o = null }
                if (!o) return
                if (o.mode === "dark" || o.mode === "light") root.mode = o.mode
                if (typeof o.scheme === "string" && o.scheme.indexOf("scheme-") === 0) root.scheme = o.scheme
                if (typeof o.contrast === "number" && isFinite(o.contrast)) root.contrast = Math.min(1, Math.max(-1, o.contrast))
            }
        }
    }
    // the heavy run: getTheme recolors everything off the current wallpaper
    Process {
        id: applyProc
        stdout: StdioCollector { id: applyOut; waitForEnd: true }
        onExited: function (code) {
            root.working = false
            if (code === 0) {
                root.statusErr = false
                root.statusMsg = "Applied " + root.schemeName(root.scheme) + " · " + root.mode + " · " + root.fmtCs(root.contrast)
                Quickshell.execDetached(["sh", "-c", "printf '%s' '{\"mode\":\"" + root.mode + "\",\"scheme\":\"" + root.scheme + "\",\"contrast\":" + root.contrast + "}' > \"" + root.stateFile + "\""])
            } else {
                root.statusErr = true
                root.statusMsg = "matugen failed — kept previous theme"
            }
            statusClear.restart()
        }
    }
    Timer { id: statusClear; interval: 6000; onTriggered: { root.statusMsg = ""; root.statusErr = false } }

    function doApply() {
        if (root.working || root.wallPath === "") return
        root.working = true
        root.statusMsg = ""
        root.statusErr = false
        applyProc.command = [Quickshell.env("HOME") + "/.local/bin/getTheme", "-m", root.mode, "-t", root.scheme, "-c", String(root.contrast), root.wallPath]
        applyProc.running = true
    }
    function openTheme() {
        Quickshell.execDetached(["quickshell", "-p", Quickshell.env("HOME") + "/.config/quickshell", "ipc", "call", "theme", "toggle"])
    }

    // ================= UI =================
    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: card; property: "opacity"; from: 0; to: 1; duration: 220; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.32, 0.72, 0, 1, 1, 1] }
        NumberAnimation { target: card; property: "scale"; from: 0.94; to: 1; duration: 280; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.34, 1.35, 0.64, 1, 1, 1] }
    }
    ParallelAnimation {
        id: closeAnim
        NumberAnimation { target: card; property: "opacity"; to: 0; duration: 160; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.32, 0.72, 0, 1, 1, 1] }
        NumberAnimation { target: card; property: "scale"; to: 0.94; duration: 180; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.32, 0.72, 0, 1, 1, 1] }
    }

    component Cap: Text {
        color: colors.alpha(colors.outline, 0.75)
        font.family: root.fontUi
        font.pixelSize: 9
        font.weight: Font.Bold
        font.letterSpacing: 1.2
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: 16
        color: colors.alpha(colors.surface, 0.52)
        border.width: 1
        border.color: colors.alpha(colors.outline, 0.15)
        focus: root.open
        Keys.onEscapePressed: root.open = false

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            Text {
                text: "Theme editor"
                color: colors.foreground
                font.family: root.fontUi
                font.pixelSize: 13
                font.weight: Font.Bold
                Layout.fillWidth: true
            }

            // ── wallpaper row ──
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 84
                spacing: 14
                Rectangle {
                    width: 64; height: 64; radius: 10
                    Layout.alignment: Qt.AlignVCenter
                    clip: true
                    color: colors.alpha(colors.tertiary, 0.25)
                    border.width: 1
                    border.color: colors.alpha(colors.tertiary, 0.45)
                    Image {
                        anchors.fill: parent
                        source: root.wallPath !== "" ? "file://" + root.wallPath : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 5
                    Text {
                        text: root.wallName !== "" ? root.wallName : "no wallpaper"
                        color: colors.foreground
                        font.family: root.fontUi
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        text: root.schemeName(root.scheme) + " · " + root.mode + " · " + root.fmtCs(root.contrast)
                        color: colors.secondary
                        font.family: root.fontUi
                        font.pixelSize: 11
                        Layout.fillWidth: true
                    }
                }
                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 76; implicitHeight: 32; radius: 8
                    color: chMa.containsMouse ? colors.alpha(colors.secondary, 0.16) : "transparent"
                    border.width: 1
                    border.color: colors.alpha(colors.secondary, 0.5)
                    transform: Translate { y: chMa.containsMouse ? -2 : 0; Behavior on y { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } } }
                    Text { anchors.centerIn: parent; text: "Change"; color: colors.secondary; font.family: root.fontUi; font.pixelSize: 11; font.weight: Font.DemiBold }
                    MouseArea { id: chMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.openTheme() }
                }
            }

            // ── mode ──
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                Cap { text: "MODE" }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Repeater {
                        model: ["dark", "light"]
                        Rectangle {
                            required property string modelData
                            Layout.fillWidth: true
                            implicitHeight: 38; radius: 9
                            color: root.mode === modelData ? colors.alpha(colors.primary, 0.2) : "transparent"
                            border.width: 1
                            border.color: root.mode === modelData ? colors.alpha(colors.primary, 0.55) : colors.alpha(colors.outline, 0.2)
                            transform: Translate { y: segMa.containsMouse && root.mode !== modelData ? -2 : 0; Behavior on y { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } } }
                            Text { anchors.centerIn: parent; text: modelData === "dark" ? "Dark" : "Light"; color: root.mode === modelData ? colors.primary : colors.alpha(colors.outline, 0.8); font.family: root.fontUi; font.pixelSize: 12; font.weight: Font.DemiBold }
                            MouseArea { id: segMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.mode = modelData }
                        }
                    }
                }
            }

            // ── scheme ──
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                Cap { text: "COLOR SCHEME" }
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 8
                    rowSpacing: 8
                    Repeater {
                        model: root.schemes
                        Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 40; radius: 9
                            color: root.scheme === modelData.k ? colors.alpha(colors.primary, 0.16) : colors.alpha(colors.surface, 0.5)
                            border.width: 1
                            border.color: root.scheme === modelData.k ? colors.alpha(colors.primary, 0.6) : colors.alpha(colors.outline, 0.2)
                            transform: Translate { y: chipMa.containsMouse ? -2 : 0; Behavior on y { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } } }
                            Behavior on color { ColorAnimation { duration: 150 } }
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 10
                                Text {
                                    text: modelData.t
                                    color: root.scheme === modelData.k ? colors.primary : colors.foreground
                                    font.family: root.fontUi
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                                RowLayout {
                                    spacing: 4
                                    Repeater {
                                        model: [colors.primary, colors.secondary, colors.tertiary]
                                        Rectangle { required property var modelData; width: 9; height: 9; radius: 4.5; color: modelData }
                                    }
                                }
                            }
                            MouseArea { id: chipMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.scheme = modelData.k }
                        }
                    }
                }
            }

            // ── contrast ──
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    Cap { text: "CONTRAST"; Layout.fillWidth: true }
                    Text { text: root.fmtC(root.contrast); color: colors.secondary; font.family: root.fontUi; font.pixelSize: 11; font.weight: Font.DemiBold }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    Text { text: "-1"; color: colors.alpha(colors.outline, 0.7); font.family: root.fontUi; font.pixelSize: 10 }
                    Slider {
                        id: contrastSlider
                        Layout.fillWidth: true
                        from: -1; to: 1; stepSize: 0.01
                        value: root.contrast
                        onMoved: root.contrast = value
                        background: Rectangle {
                            implicitHeight: 7; radius: 3.5
                            color: colors.alpha(colors.surfaceVariant, 0.55)
                            border.width: 1
                            border.color: colors.alpha(colors.outline, 0.2)
                            Rectangle {
                                width: parent.width * (contrastSlider.value + 1) / 2
                                height: parent.height; radius: 3.5
                                color: colors.alpha(colors.secondary, 0.9)
                            }
                        }
                        handle: Rectangle {
                            width: 18; height: 18; radius: 9
                            color: colors.secondary
                            border.width: 3
                            border.color: colors.background
                        }
                    }
                    Text { text: "+1"; color: colors.alpha(colors.outline, 0.7); font.family: root.fontUi; font.pixelSize: 10 }
                }
            }

            // ── live palette ──
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                Cap { text: "LIVE PALETTE" }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Repeater {
                        model: [
                            { t: "primary", c: colors.primary },
                            { t: "secondary", c: colors.secondary },
                            { t: "tertiary", c: colors.tertiary },
                            { t: "surface", c: colors.surfaceVariant }
                        ]
                        ColumnLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 4
                            Rectangle { Layout.fillWidth: true; implicitHeight: 34; radius: 9; color: modelData.c; border.width: 1; border.color: colors.alpha(colors.outline, 0.2) }
                            Text { text: modelData.t; color: colors.alpha(colors.outline, 0.7); font.family: root.fontUi; font.pixelSize: 9; Layout.fillWidth: true; elide: Text.ElideRight }
                        }
                    }
                }
            }

            // ── footer: status slot (fixed height, swaps in place) + apply ──
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: root.statusMsg !== ""
                    text: root.statusMsg
                    color: root.statusErr ? colors.error : colors.primary
                    font.family: root.fontUi
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 44; radius: 10
                    color: root.working ? colors.alpha(colors.primary, 0.4) : colors.primary
                    opacity: root.working ? 0.7 : 1
                    transform: Translate { y: apMa.containsMouse && !root.working ? -2 : 0; Behavior on y { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } } }
                    Text { anchors.centerIn: parent; text: root.working ? "Working…" : "Apply theme"; color: colors.background; font.family: root.fontUi; font.pixelSize: 13; font.weight: Font.Bold }
                    Rectangle {
                        visible: root.working
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        height: 2
                        width: 0
                        radius: 1
                        color: colors.surfaceVariant
                    }
                    MouseArea { id: apMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: !root.working; onClicked: root.doApply() }
                }
                Text {
                    text: "esc closes"
                    color: colors.alpha(colors.outline, 0.7)
                    font.family: root.fontUi
                    font.pixelSize: 10
                }
            }
        }
    }
}
