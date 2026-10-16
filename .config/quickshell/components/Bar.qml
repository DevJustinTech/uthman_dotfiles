import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import "../modules"

// Center trapezoid island tab (\_____/) hanging flush from the screen
// top — 8px rounded bottom corners, no border.
PanelWindow {
    id: bar

    anchors { top: true; left: true; right: true }
    exclusionMode: ExclusionMode.Auto
    implicitHeight: 54
    color: "transparent"
    WlrLayershell.namespace: "qs-bar"
    margins { top: 0; left: 8; right: 8 }

    property alias colors: palette
    property alias leftItems: leftRow.children
    property alias centerItems: islandRow.children
    property alias rightItems: rightRow.children

    Colors { id: palette }

    NotificationCenter { id: ntfy; colors: palette }

    // ---- resident panels: every popup stays loaded, zero RAM saved but
    // zero first-paint white flash (the battery lesson — lazy Loaders
    // stall the first frames while the tree builds). Panels self-gate
    // their timers/watchers on open, so idle cost is RAM only.
    // Bar owns each IPC target directly on the instance (panels must NOT
    // register the same target — see MonitorSettings lesson). Bar pills
    // call toggleX()/showX(); Hyprland binds call `ipc call <target> toggle`.

    // WifiPanel (1183 lines, heaviest) — Network pill + `wifi` bind
    WifiPanel { id: wifiPanel; colors: palette }
    IpcHandler { target: "wifi"; function toggle(): void { wifiPanel.open = !wifiPanel.open } function radio(): void { wifiPanel.toggleRadio() } }
    function toggleWifi() { wifiPanel.open = !wifiPanel.open }

    // SystemMonitor (544 lines) — Memory/Cpu pills + `sysmon` bind
    SystemMonitor { id: sysPanel; colors: palette }
    IpcHandler { target: "sysmon"; function toggle(): void { sysPanel.open = !sysPanel.open } }
    function showSysMon() { sysPanel.open = true }

    // BatteryPanel stays resident: opened constantly, and lazy-loading it
    // caused a first-paint white flash on open (surface maps before the
    // card finishes its entrance). ~10MB to never see that again.
    BatteryPanel { id: batPanel; colors: palette }

    // ClipboardPanel (577 lines) — `clipboard` bind. `sticky` too: the shelf
    // binds (SUPER ALT 1-4) fire snippets with no window — always loaded
    // now, so the actions run directly, never opening the panel.
    ClipboardPanel { id: clipPanel; colors: palette }
    IpcHandler { target: "clipboard"; function toggle(): void { clipPanel.open = !clipPanel.open } function close(): void { clipPanel.open = false } }
    IpcHandler {
        target: "sticky"
        // pin() also opens the panel. The pin itself always worked -- the rows
        // land in the qs_stickies database -- but the only UI for them lives
        // inside this panel, and pinning by key never opened it. So the note
        // was saved, a toast fired, and nothing appeared anywhere.
        function pin(): void { clipPanel.addStickyFromClipboard(); clipPanel.open = true }
        function copy(slot: string): void { clipPanel.copyStickyBySlot(slot) }
        function clearAll(): void { clipPanel.clearStickies() }
    }

    // ThemePanel (361 lines) — `theme` bind
    ThemePanel { id: themePanel; colors: palette }
    IpcHandler { target: "theme"; function toggle(): void { themePanel.open = !themePanel.open } }

    // FastFetchWindow (191 lines) — `fastfetch` bind
    FastFetchWindow { id: fetchPanel; colors: palette }
    IpcHandler { target: "fastfetch"; function toggle(): void { fetchPanel.open = !fetchPanel.open } }

    // ClockWindow (308 lines) — Clock pin + `clockwin` bind
    ClockWindow { id: clockPanel; colors: palette }
    IpcHandler { target: "clockwin"; function toggle(): void { clockPanel.open = !clockPanel.open } }
    function toggleClockWin() { clockPanel.open = !clockPanel.open }

    // ScreenTime (211 lines) — `screentime` bind
    ScreenTime { id: stPanel; colors: palette }
    IpcHandler { target: "screentime"; function toggle(): void { stPanel.open = !stPanel.open } }
    // PhoneBridge and WhatsApp were removed at the user's request, along with
    // their binds, float rules, systemd unit, helpers and logo. The phonebridge
    // backend was never installed here, so the module only ever logged
    // "Process failed to start ... /home/justin/phonebridge/phonebridge" and
    // loading it cost ~1200 lines of QML to build on every shell start.
    // Launcher lives here (not shell.qml) so Bar pills/IPC can reach it —
    // and `plugins` (PluginMenu scrapped; the ten plugin apps ride the
    // launcher now, so the alias lands on its utilities view — opening, not
    // toggling: nothing needs to close the launcher through here).
    AppLauncher { id: launcherPanel; colors: palette }
    IpcHandler { target: "plugins"; function toggle(): void { launcherPanel.showUtilities() } }

    // KeybindsPanel resident (battery treatment): lazy first-paint flashed
    // white — the list build stalls the first frames. Opened constantly,
    // so ~3MB resident to never see it again.
    KeybindsPanel { id: keysPanel; colors: palette }
    IpcHandler { target: "keybinds"; function toggle(): void { keysPanel.open = !keysPanel.open } }

    // DriveHealth (739 lines) — `drives` bind (+ `dbg` stays in panel)
    DriveHealth { id: drivesPanel; colors: palette }
    IpcHandler { target: "drives"; function toggle(): void { drivesPanel.open = !drivesPanel.open } }

    // WatchCatPanel (333 lines) — WatchCat pill + `watchcat` bind
    WatchCatPanel { id: wcPanel; colors: palette }
    IpcHandler { target: "watchcat"; function toggle(): void { wcPanel.open = !wcPanel.open } }
    function toggleWatchCat() { wcPanel.open = !wcPanel.open }

    // FailWatchPanel (441 lines) — FailWatch pill + `failwatch` bind
    FailWatchPanel { id: fwPanel; colors: palette }
    IpcHandler { target: "failwatch"; function toggle(): void { fwPanel.open = !fwPanel.open } }
    MediaOsd { id: mediaOsd; colors: palette }

    // Bar sides.
    //
    // Two separate things: barsPinned is what SUPER SHIFT SPACE toggles, and
    // barsVisible is what actually paints. Unpinned, the sides stay hidden and
    // sweep in when the cursor reaches either edge, then retract when it
    // leaves -- the mouse is the whole interaction, no key needed.
    // Pinned, the toggle holds them open regardless of the pointer.
    //
    // Default is island only: it matches upstream and the README screenshots,
    // and suits a 1366px panel better than the full row of pills.
    property bool barsPinned: false
    property bool barsVisible: false
    // Hover is tracked in four bits, not two. The strips sit BELOW the rows and
    // every pill has a hoverEnabled MouseArea, so crossing a pill can take
    // hover away from the strip underneath it. That produced a repeating cycle:
    // pointer rests on a pill -> strip hover drops -> 320ms grace -> row
    // retracts and slides 40px away -> pill no longer under the cursor -> strip
    // hover returns -> row slides back under the cursor -> hover drops again.
    // Counting the row itself as hovered closes the loop, so leaving the
    // pointer on a pill is no longer ambiguous.
    property bool leftZoneHover: false
    property bool leftRowHover: false
    property bool rightZoneHover: false
    property bool rightRowHover: false
    readonly property bool leftHover: leftZoneHover || leftRowHover
    readonly property bool rightHover: rightZoneHover || rightRowHover

    // Retracting is deferred, revealing is not. Going in should feel instant;
    // coming out should not fire on a single dropped frame or a 1px gap
    // between two pills, which read as flicker.
    Timer {
        id: barsGrace
        interval: 320
        onTriggered: bar.barsVisible = bar.barsPinned
    }
    function refreshBars() {
        const wanted = barsPinned || leftHover || rightHover
        if (wanted) {
            barsGrace.stop()
            barsVisible = true
        } else if (!barsGrace.running) {
            barsGrace.restart()
        }
    }
    function clearHover() {
        leftZoneHover = false
        leftRowHover = false
        rightZoneHover = false
        rightRowHover = false
    }
    function setBars(pinned: bool) {
        barsPinned = pinned
        clearHover()
        if (pinned) {
            barsGrace.stop()
            barsVisible = true
        } else {
            barsGrace.restart()
        }
    }
    // center style — SUPER ALT SPACE flips trapezoid tab against the Dynamic Island
    property bool dynamicIsland: false
    // island hover swells the NowPlaying glass card; the linger timer keeps it from
    // flickering when the cursor cuts the corner between island and card
    property bool musicHover: false
    Timer {
        id: musicLinger
        interval: 250
        onTriggered: bar.musicHover = false
    }
    // SUPER ALT SPACE cinches the island down to a 44px dot and springs it
    // back open, so swapping trapezoid <-> capsule reads as one continuous
    // move instead of a hard swap. Notifications are the toast's job, not
    // the bar's.
    function pulseIsland() { growAnim.restart() }

    IpcHandler {
        target: "bar"
        // Toggles the PIN, not the current visibility: pressing it while the
        // sides are out on hover would otherwise unpin them and they would
        // vanish under the cursor.
        function toggle(): void { bar.setBars(!bar.barsPinned) }
        function toggleIsland(): void { bar.dynamicIsland = !bar.dynamicIsland; bar.pulseIsland() }
    }

    Item {
        id: content
        anchors.fill: parent

        // ── hover reveal ────────────────────────────────────────────────
        // One invisible strip per end of the bar, sized to COVER THE WHOLE
        // ROW it reveals. This is the part that matters: a strip that only
        // covers the corner makes the sides unusable, because you flick the
        // pointer into the corner, the row slides out, and then every step
        // toward the pill you actually wanted carries you off the strip and
        // the row retracts before the click lands. The rows are ~210px and
        // ~420px wide, so a fixed 110/200px strip covered only the first
        // pill or two of each.
        //
        // Width binds to the row's own width, so it stays correct as the
        // pills change (battery appearing, CPU label growing).
        //
        // z is BELOW the rows. A strip on top shadowed the pills and ate
        // their clicks. Below, the rows sit on top and take every click;
        // HoverHandler only tracks the pointer and accepts no button, so it
        // never competes for the press.
        //
        // Overlap with the centre island is harmless for the same reason:
        // the island's own items are above these strips.
        //
        // enabled is gated on the pin: when the sides are pinned open the
        // strips go dead so moving the pointer away cannot yank them shut.
        Item {
            id: leftZone
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: Math.max(120, leftRow.width + 60)
            z: -1
            HoverHandler {
                id: leftHoverHandler
                enabled: !bar.barsPinned
                onHoveredChanged: {
                    bar.leftZoneHover = hovered
                    bar.refreshBars()
                }
            }
        }
        Item {
            id: rightZone
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
            width: Math.max(200, rightRow.width + 60)
            z: -1
            HoverHandler {
                id: rightHoverHandler
                enabled: !bar.barsPinned
                onHoveredChanged: {
                    bar.rightZoneHover = hovered
                    bar.refreshBars()
                }
            }
        }

        RowLayout {
            id: leftRow
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: 6; bottomMargin: 8 }
            spacing: 6
            opacity: bar.barsVisible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            transform: Translate { x: bar.barsVisible ? 0 : -40; Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } } }
            ArchLogo { colors: bar.colors }
            Workspaces { colors: bar.colors }
            // Counts as hovered so the pill MouseAreas above cannot starve the
            // strip below and start the retract/reveal cycle.             // is emptied so nothing on top of this row can take hover away.
            HoverHandler {
                enabled: !bar.barsPinned
                onHoveredChanged: {
                    bar.leftRowHover = hovered
                    bar.refreshBars()
                }
            }
        }

        // Trapezoid tab (\_____/) — soft 8px bottom corners, no border.
        // Top edge stays flush to the screen.
        Item {
            id: island
            anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
            anchors.topMargin: 0
            property real naturalWidth: islandRow.implicitWidth + 40
            // growT 0 = cinched to a dot, 1 = natural. The grow animation
            // overshoots past 1 and settles, same as the reference easing.
            property real growT: 1
            width: 44 + (naturalWidth - 44) * growT
            height: 54
            // content-driven resizes stay smooth; the pulse owns growT
            Behavior on naturalWidth { NumberAnimation { duration: 380; easing.type: Easing.Bezier; easing.bezierCurve: [0.32, 0.72, 0, 1] } }
            // trapezoid geometry — rounded bottom corners
            readonly property real inset: 18         // horizontal inset of bottom edge
            readonly property real r: 14
            readonly property real len: Math.sqrt(inset*inset + height*height)
            readonly property real sx: inset / len
            readonly property real sy: height / len
            NumberAnimation {
                id: growAnim
                target: island; property: "growT"
                from: 0; to: 1; duration: 420
                easing.type: Easing.Bezier; easing.bezierCurve: [0.2, 0.9, 0.3, 1.2]
            }
            // glow follows the music: album-art dominant hue while playing,
            // theme primary when idle — the line reads as a play indicator.
            // Near-black art is unreadable on the dark bar, so it blends
            // halfway toward primary (keeps the hue, guarantees light).
            function satFor(c, b) {
                var avg = (c.r + c.g + c.b) / 3
                return Qt.rgba(
                    Math.min(1, Math.max(0, avg + (c.r - avg) * b)),
                    Math.min(1, Math.max(0, avg + (c.g - avg) * b)),
                    Math.min(1, Math.max(0, avg + (c.b - avg) * b)), 1)
            }
            function glowFor(t) {
                var lum = 0.2126 * t.r + 0.7152 * t.g + 0.0722 * t.b
                var c = satFor(t, 1.6)
                if (lum < 0.10) {
                    var p = colors.primary
                    c = satFor(Qt.rgba((c.r + p.r) / 2, (c.g + p.g) / 2, (c.b + p.b) / 2, 1), 1.6)
                }
                // vivid enforcement: stretch dull browns/greys to a 0.35
                // channel spread; true grey has no hue — use primary instead
                var mx = Math.max(c.r, c.g, c.b), mn = Math.min(c.r, c.g, c.b)
                var spread = mx - mn
                if (spread <= 0.02) return satFor(colors.primary, 1.6)
                if (spread < 0.35) {
                    var avg = (c.r + c.g + c.b) / 3, k = 0.35 / spread
                    return Qt.rgba(
                        Math.min(1, Math.max(0, avg + (c.r - avg) * k)),
                        Math.min(1, Math.max(0, avg + (c.g - avg) * k)),
                        Math.min(1, Math.max(0, avg + (c.b - avg) * k)), 1)
                }
                return c
            }
            readonly property color glowBase: nowPlaying.isPlaying ? glowFor(nowPlaying.trackColor) : colors.primary

            // Dynamic-Island capsule overlay (SUPER ALT SPACE minimal mode)
            Rectangle {
                opacity: bar.dynamicIsland ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.Bezier; easing.bezierCurve: [0.32, 0.72, 0, 1] } }
                anchors.centerIn: parent
                width: island.width
                height: 40
                radius: height / 2
                color: colors.alpha(colors.background, 0.85)
                border.color: colors.alpha(colors.surfaceVariant, 0.8)
                border.width: 2
            }

            Shape {
                id: shp
                readonly property real f: 14   // flare size

                x: -f
                y: 0
                width: island.width + 2 * f
                height: island.height
                opacity: bar.dynamicIsland ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.Bezier; easing.bezierCurve: [0.32, 0.72, 0, 1] } }
                antialiasing: true
                layer.enabled: true
                layer.samples: 4

                ShapePath {
                    // 0.6: frosted, not flat — Hyprland's `blur on, match:namespace qs-bar`
                    // layerrule blurs the wallpaper behind; this alpha lets it bite
                    fillColor: colors.alpha(colors.background, 0.6)
                    strokeColor: "transparent"
                    strokeWidth: 0

                    // every x below is offset by shp.f because the Shape starts at x = -f
                    startX: 0; startY: 0
                    PathLine { x: shp.width; y: 0 }

                    // top-right flare
                    PathQuad { controlX: shp.f + island.width; controlY: 0
                               x: shp.f + island.width - island.sx * shp.f; y: island.sy * shp.f }

                    // right slant, then rounded bottom corner
                    PathLine { x: shp.f + island.width - island.inset + island.sx * island.r
                               y: island.height - island.sy * island.r }
                    PathQuad { controlX: shp.f + island.width - island.inset; controlY: island.height
                               x: shp.f + island.width - island.inset - island.r; y: island.height }

                    // bottom edge
                    PathLine { x: shp.f + island.inset + island.r; y: island.height }

                    // left rounded corner, then slant up
                    PathQuad { controlX: shp.f + island.inset; controlY: island.height
                               x: shp.f + island.inset - island.sx * island.r; y: island.height - island.sy * island.r }
                    PathLine { x: shp.f + island.sx * shp.f; y: island.sy * shp.f }

                    // top-left flare
                    PathQuad { controlX: shp.f; controlY: 0; x: 0; y: 0 }
                }
            }

            RowLayout {
                id: islandRow
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -1
                spacing: 10
                // clock small left
                Clock {
                    id: clockItem
                    colors: bar.colors
                    // smaller clock when NowPlaying is focus — keep time but de-emphasized
                    onPinRequested: toggleClockWin()
                }
                // hairline dividers — siblings, never children (§4);
                // 1x14 outline @ 0.28 per the island spec
                Rectangle {
                    width: 1; height: 14
                    color: colors.alpha(colors.outline, 0.28)
                    Layout.alignment: Qt.AlignVCenter
                }
                // NowPlaying focus — big centered, fills available width
                NowPlaying {
                    id: nowPlaying
                    colors: bar.colors
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    Layout.maximumWidth: 340
                    onHoverChanged: function(h) {
                        if (h) { musicLinger.stop(); bar.musicHover = true }
                        else musicLinger.restart()
                    }
                }
                Rectangle {
                    width: 1; height: 14
                    color: colors.alpha(colors.outline, 0.28)
                    Layout.alignment: Qt.AlignVCenter
                }
                // bell small right
                BellButton {
                    colors: bar.colors
                    historyCount: ntfy.historyCount
                    panelOpen: ntfy.panelOpen
                    dnd: ntfy.dnd
                    onToggleRequested: ntfy.togglePanel()
                }
            }

            // Island underline: a hairline that REACTS instead of animating on
            // its own.
            //
            // This replaced three intertwined sine waves on a 66ms Timer. That
            // cost about a third of a core (33.9% CPU on quickshell) because it
            // repainted unconditionally, 15 times a second, forever, whether or
            // not anything was playing: a full-width Canvas, three strokes,
            // ~450 lineTo per stroke, so roughly 20k canvas ops per second to
            // draw a decorative ripple nobody was watching.
            //
            // Now the line only has a gradient and a handful of bars that move
            // to the real spectrum, and only while music is actually playing.
            // Idle it is a static hairline costing nothing.
            // No MouseArea: clicks pass through.
            Item {
                id: islandLine
                anchors { left: parent.left; right: parent.right; top: parent.top }
                anchors.leftMargin: island.inset + 8
                anchors.rightMargin: island.inset + 8
                anchors.topMargin: 0
                height: 11
                clip: true

                Rectangle {
                    y: 5
                    width: parent.width
                    height: 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.18; color: colors.alpha(island.glowBase, 0.35) }
                        GradientStop { position: 0.82; color: colors.alpha(island.glowBase, 0.35) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                // Live spectrum, pushed from NowPlaying's existing cava feed --
                // no second cava process, no timer of our own. Repeater is bound
                // to vizLevels, so a level update is one property write per bar
                // and Qt animates only that bar. Idle, vizLevels is empty and no
                // bars exist to paint.
                Row {
                    id: spectrum
                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
                    anchors.bottomMargin: 0
                    height: 4
                    spacing: 2
                    opacity: nowPlaying.isPlaying ? 0.85 : 0

                    Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

                    Repeater {
                        model: nowPlaying.isPlaying ? nowPlaying.vizLevels : []
                        delegate: Rectangle {
                            required property int modelData
                            width: 2
                            radius: 1
                            color: island.glowBase
                            height: 1 + Math.max(0, Math.min(100, modelData)) / 100 * 4
                            Behavior on height { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
                        }
                    }
                }

            }
        }

        RowLayout {
            id: rightRow
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: 6; bottomMargin: 8; rightMargin: 6 }
            spacing: 6
            opacity: bar.barsVisible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            transform: Translate { x: bar.barsVisible ? 0 : 40; Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } } }

            // unified transient pill: idle · DND · recording · tray (LocalSend/OBS/etc.)
            // was 4 separate popping pills — now one glass pill, hidden when empty
            StatusPill {
                colors: bar.colors
                dnd: ntfy.dnd
                onToggleDndRequested: ntfy.toggleDnd()
            }
            Memory { colors: bar.colors; onOpenRequested: showSysMon() }
            Cpu { colors: bar.colors; onOpenRequested: showSysMon() }
            Network {
                colors: bar.colors
                onOpenRequested: toggleWifi()
            }
            WatchCat {
                colors: bar.colors
                onOpenRequested: toggleWatchCat()
            }
            FailWatch {
                colors: bar.colors
                onOpenRequested: fwPanel.open = !fwPanel.open
            }
            Battery { colors: bar.colors; onOpenRequested: batPanel.open = !batPanel.open }
            HoverHandler {
                enabled: !bar.barsPinned
                onHoveredChanged: {
                    bar.rightRowHover = hovered
                    bar.refreshBars()
                }
            }
        }

    }
}
