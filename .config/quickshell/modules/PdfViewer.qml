import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../components"

// Books — a REGULAR Hyprland floating window (not an overlay).
// Library: recents, favourites, title/author/path search, full-text search
// (pdftotext for PDFs, unzip for EPUBs), copy-path / show-in-files actions.
// Store: random discovery + search across legal public catalogs, download
// queue into ~/Books, then open in Zathura (PDF) or Foliate (EPUB).
FloatingWindow {
    id: root
    property var colors
    property bool open: false
    property string tab: "library" // library | store

    // ── library: cached list, scanned once, stats per file ──
    property var library: []
    property bool libReady: false
    property bool scanning: false
    property string libQuery: ""
    property bool libFavOnly: false
    property bool libUnreadOnly: false
    property bool libFinishedOnly: false
    property bool libContentOnly: false
    property string libSort: "recent" // recent | reads | az
    readonly property string libPath: Quickshell.env("HOME") + "/.local/state/quickshell/pdf-library.json"

    // ── content search: which books contain the query text ──
    property var contentHits: []
    property bool contentSearching: false
    property bool contentDirty: false
    property string contentQuery: ""

    title: "Books"
    implicitWidth: 860
    implicitHeight: 600
    minimumSize: Qt.size(700, 520)
    maximumSize: Qt.size(1100, 680)
    color: "transparent"
    visible: root.open || closeAnim.running

    onOpenChanged: if(open) {
        Qt.callLater(function(){ if(root.tab === "store") store.activate(); else bg.forceActiveFocus() })
        openAnim.restart()
    } else closeAnim.restart()
    onLibQueryChanged: {
        var q = root.libQuery.trim()
        if(q.length >= 3){ contentDeb.restart() }
        else { contentDeb.stop(); root.contentHits = []; root.contentQuery = ""; root.libContentOnly = false }
    }

    function switchTab(t){
        root.tab = t
        if(t === "store") Qt.callLater(function(){ store.activate() })
        else Qt.callLater(function(){ bg.forceActiveFocus() })
    }
    function extOf(path){
        var m = String(path || "").match(/\.([a-z0-9]+)$/i)
        return m ? m[1].toLowerCase() : ""
    }
    function formatFor(path){ var e = root.extOf(path); return e === "" ? "file" : e }
    function readerLabel(path){ return root.extOf(path) === "epub" ? "Foliate" : "Zathura" }
    function openWith(path){
        if(!path) return
        var e = libEntry(path)
        if(!e && libReady){
            var parts = path.split("/")
            e = {path: path, title: parts[parts.length-1].replace(/\.(pdf|epub)$/i,""), folder: parts.length>1?parts[parts.length-2]:"~", reads: 0, last: 0, fav: false, format: root.formatFor(path)}
            var lib = root.library.slice(); lib.unshift(e); root.library = lib
        }
        if(e && !e.format) e.format = root.formatFor(path)
        recordRead(path)
        libSave()
        if(root.extOf(path) === "epub"){
            Quickshell.execDetached(["sh","-c","command -v foliate >/dev/null 2>&1 && foliate " + root.shQuote(path) + " || xdg-open " + root.shQuote(path)])
        } else if(root.extOf(path) === "pdf"){
            Quickshell.execDetached(["zathura", path])
        } else {
            Quickshell.execDetached(["xdg-open", path])
        }
    }
    function addDownloaded(e){
        if(!e || !e.path) return
        var prev = libEntry(e.path)
        var entry = prev || {path: e.path, folder: e.path.split("/").slice(-2)[0] || "Books", reads: 0, last: 0, fav: false}
        if(e.title) entry.title = e.title
        if(e.author) entry.author = e.author
        if(e.source) entry.source = e.source
        if(e.sourceId) entry.sourceId = e.sourceId
        if(e.cover) entry.cover = e.cover
        if(e.year) entry.year = e.year
        entry.format = e.format || root.formatFor(e.path)
        entry.folder = entry.path.split("/").slice(-2)[0] || "Books"
        entry.reads = entry.reads || 0
        entry.last = entry.last || 0
        entry.fav = !!entry.fav
        var lib = root.library.slice()
        if(prev){
            for(var i=0;i<lib.length;i++) if(lib[i].path === e.path){ lib[i] = entry; break }
        } else {
            lib.unshift(entry)
        }
        root.library = lib
        libSave()
    }
    function libSave(){
        if(!libReady) return
        saveProc.command = ["sh","-c","mkdir -p '"+Quickshell.env("HOME")+"/.local/state/quickshell' && echo '"+Qt.btoa(JSON.stringify({files: root.library}))+"' | base64 -d > '"+root.libPath+"'"]
        saveProc.running = true
    }
    function libEntry(path){
        for(var i=0;i<root.library.length;i++) if(root.library[i].path===path) return root.library[i]
        return null
    }
    function recordRead(path){
        if(!path || !libReady) return
        var e = libEntry(path)
        if(e){
            e.reads = (e.reads||0)+1
            e.last = Date.now()
            if(!e.format) e.format = root.formatFor(path)
            root.libraryChanged()
            libSave()
        }
    }
    function toggleFav(path){
        var e = libEntry(path)
        if(e){ e.fav = !e.fav; root.libraryChanged(); libSave() }
    }
    function toggleFinished(path){
        var e = libEntry(path)
        if(e){ e.finished = !e.finished; root.libraryChanged(); libSave() }
    }
    function rowMeta(e){
        if(!e) return ""
        var bits = []
        if(e.author) bits.push(e.author)
        if(e.source && e.source !== "Local") bits.push(e.source)
        if(e.folder) bits.push(e.folder)
        bits.push((e.reads||0)>0 ? ((e.reads||0)+"×  •  "+root.fmtAgo(e.last)) : "unread")
        if(e.finished) bits.push("finished")
        return bits.join("  •  ")
    }
    function libRows(){
        var q = root.libQuery.toLowerCase()
        var rows = root.library.filter(function(e){
            if(root.libFavOnly && !e.fav) return false
            if(root.libUnreadOnly && (e.reads||0) > 0) return false
            if(root.libFinishedOnly && !e.finished) return false
            if(root.libContentOnly && root.contentHits.indexOf(e.path) === -1) return false
            if(q && (e.title||"").toLowerCase().indexOf(q)===-1
                && (e.path||"").toLowerCase().indexOf(q)===-1
                && (e.author||"").toLowerCase().indexOf(q)===-1
                && (e.source||"").toLowerCase().indexOf(q)===-1) return false
            return true
        })
        var by = root.libSort
        rows.sort(function(a,b){
            if(by==="reads") return (b.reads||0)-(a.reads||0)
            if(by==="az") return (a.title||"").localeCompare(b.title||"")
            return (b.last||0)-(a.last||0)
        })
        return rows
    }
    function recentTop(){
        var best = null
        for(var i=0;i<root.library.length;i++){
            var e = root.library[i]
            if(!(e.last||0)) continue
            if(!best || e.last > best.last) best = e
        }
        return best
    }
    function fmtAgo(ts){
        if(!ts) return "never"
        var s = Math.floor((Date.now()-ts)/1000)
        if(s < 60) return "just now"
        if(s < 3600) return Math.floor(s/60)+"m ago"
        if(s < 86400) return Math.floor(s/3600)+"h ago"
        if(s < 7*86400) return Math.floor(s/86400)+"d ago"
        return Qt.formatDate(new Date(ts), "MMM dd")
    }
    function shQuote(s){ return "'"+String(s).replace(/'/g,"'\\''")+"'" }
    function copyPath(path){
        if(!path) return
        Quickshell.execDetached(["sh","-c","printf %s "+shQuote(path)+" | (wl-copy 2>/dev/null || xclip -selection clipboard 2>/dev/null)"])
    }
    function openFolder(path){
        if(!path) return
        var dir = path.split("/").slice(0,-1).join("/") || Quickshell.env("HOME")
        Quickshell.execDetached(["xdg-open", dir])
    }
    function libRescan(){ if(!root.scanning){ root.scanning = true; scanProc.running = true } }
    function chipActive(k){
        if(k==="fav") return root.libFavOnly
        if(k==="unread") return root.libUnreadOnly
        if(k==="finished") return root.libFinishedOnly
        if(k==="content") return root.libContentOnly
        if(k==="all") return !root.libFavOnly && !root.libUnreadOnly && !root.libFinishedOnly && !root.libContentOnly && root.libSort==="recent"
        return root.libSort===k
    }
    readonly property int selIdx: { var r = libRows(); if(!r.length) return -1; return Math.max(0, Math.min(libList.currentIndex, r.length-1)) }
    function selFile(){ var r = libRows(); return root.selIdx < 0 ? null : r[root.selIdx] }
    function chipClicked(k){
        if(k==="fav"){ root.libFavOnly = !root.libFavOnly; return }
        if(k==="unread"){ root.libUnreadOnly = !root.libUnreadOnly; return }
        if(k==="finished"){ root.libFinishedOnly = !root.libFinishedOnly; return }
        if(k==="content"){ if(root.contentHits.length) root.libContentOnly = !root.libContentOnly; return }
        if(k==="all"){ root.libFavOnly = false; root.libUnreadOnly = false; root.libFinishedOnly = false; root.libContentOnly = false; root.libSort = "recent"; return }
        root.libSort = k
    }
    function startContentSearch(){
        var q = root.libQuery.trim()
        if(q.length < 3) return
        if(root.contentSearching){ root.contentDirty = true; return }
        root.contentQuery = q
        root.contentSearching = true
        var files = []
        for(var i=0;i<root.library.length && files.length<100;i++){
            var p = root.library[i].path
            if(/\.(pdf|epub)$/i.test(p)) files.push(p)
        }
        if(!files.length){ root.contentSearching = false; return }
        var lines = []
        for(var j=0;j<files.length;j++){
            var f = shQuote(files[j])
            if(/\.pdf$/i.test(files[j])){
                lines.push("if pdftotext -l 6 -q -- "+f+" - 2>/dev/null | grep -qiF -- "+shQuote(q)+"; then printf '%s\\n' "+f+"; fi")
            } else {
                lines.push("if unzip -p "+f+" '*.xhtml' '*.html' 2>/dev/null | sed 's/<[^>]*>/ /g' | grep -qiF -- "+shQuote(q)+"; then printf '%s\\n' "+f+"; fi")
            }
        }
        contentProc.command = ["sh","-c", lines.join("\n")]
        contentProc.running = true
    }

    Process { id: saveProc }
    Process {
        id: contentProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var hits = []
                var lines = text.split("\n")
                for(var i=0;i<lines.length;i++){ var p = lines[i].trim(); if(p) hits.push(p) }
                root.contentHits = hits
                root.contentSearching = false
                if(root.contentDirty){ root.contentDirty = false; root.startContentSearch() }
            }
        }
    }
    Timer { id: contentDeb; interval: 600; onTriggered: root.startContentSearch() }

    FileView {
        id: libView
        path: root.libPath
        printErrors: false
        onLoaded: {
            try {
                var d = JSON.parse(text())
                if(d && d.files){ root.library = d.files; root.libReady = true; return }
            } catch(e) {}
            root.libRescan()
        }
        onLoadFailed: root.libRescan()
    }
    Process {
        id: scanProc
        command: ["sh","-c","find '"+Quickshell.env("HOME")+"' -maxdepth 4 \\( -iname '*.pdf' -o -iname '*.epub' \\) -not -path '*/.*' 2>/dev/null | head -n 500"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var old = {}
                for(var i=0;i<root.library.length;i++) old[root.library[i].path] = root.library[i]
                var files = []
                var lines = text.split("\n")
                for(var j=0;j<lines.length;j++){
                    var p = lines[j].trim()
                    if(!p) continue
                    if(old[p]){ files.push(old[p]); continue }
                    var parts = p.split("/")
                    files.push({
                        path: p,
                        title: parts[parts.length-1].replace(/\.(pdf|epub)$/i,""),
                        folder: parts.length>1?parts[parts.length-2]:"~",
                        reads: 0, last: 0, fav: false,
                        format: /\.epub$/i.test(p) ? "epub" : "pdf",
                        source: "Local"
                    })
                }
                root.library = files
                root.libReady = true
                root.scanning = false
                root.libSave()
            }
        }
    }

    // window glass
    Glass {
        id: bg
        anchors.fill: parent
        radius: 16
        surfaceId: "pdf"
        colors: root.colors
        classicColor: root.colors ? colors.alpha(colors.surface, 0.52) : "transparent"
        classicBorder: root.colors ? colors.alpha(colors.outline, 0.15) : "transparent"
        classicBorderWidth: 1
        // bezier pair — open pops with overshoot bounce, close hurries out
        ParallelAnimation {
            id: openAnim
            NumberAnimation { target: bg; property: "opacity"; from: 0; to: 1; duration: 220; easing.type: Easing.Bezier; easing.bezierCurve: [0.32, 0.72, 0, 1] }
            NumberAnimation { target: bg; property: "scale"; from: 0.94; to: 1; duration: 280; easing.type: Easing.Bezier; easing.bezierCurve: [0.34, 1.35, 0.64, 1] }
        }
        ParallelAnimation {
            id: closeAnim
            NumberAnimation { target: bg; property: "opacity"; to: 0; duration: 160; easing.type: Easing.Bezier; easing.bezierCurve: [0.32, 0.72, 0, 1] }
            NumberAnimation { target: bg; property: "scale"; to: 0.94; duration: 180; easing.type: Easing.Bezier; easing.bezierCurve: [0.32, 0.72, 0, 1] }
        }
        focus: true
        Keys.onEscapePressed: root.open = false
        Keys.onPressed: function(e){
            if(e.key === Qt.Key_Tab){
                root.switchTab(root.tab === "library" ? "store" : "library")
                e.accepted = true
                return
            }
            if(root.tab === "store"){
                if(store.handleKey(e)) e.accepted = true
                return
            }
            var rows = root.libRows()
            if(!rows.length) return
            if(e.key===Qt.Key_F){ var r=rows[libList.currentIndex]; if(r) root.toggleFav(r.path); e.accepted=true }
            else if(e.key===Qt.Key_C){ var c=rows[libList.currentIndex]; if(c) root.copyPath(c.path); e.accepted=true }
            else if(e.key===Qt.Key_J||e.key===Qt.Key_Down){ libList.currentIndex=Math.min(rows.length-1,libList.currentIndex+1); e.accepted=true }
            else if(e.key===Qt.Key_K||e.key===Qt.Key_Up){ libList.currentIndex=Math.max(0,libList.currentIndex-1); e.accepted=true }
            else if(e.key===Qt.Key_Return||e.key===Qt.Key_Enter||e.key===Qt.Key_O){ var o=rows[libList.currentIndex]; if(o) root.openWith(o.path); e.accepted=true }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // header — icon + title + tabs + stats + rescan + close
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Rectangle {
                    Layout.preferredWidth: 26; Layout.preferredHeight: 26; radius: 13
                    color: colors.alpha(colors.primary, 0.15)
                    border.width: 1; border.color: colors.alpha(colors.primary, 0.3)
                    Text { anchors.centerIn: parent; text: ""; color: colors.primary; font.family: colors.fontSans; font.pixelSize: 12 }
                    Layout.alignment: Qt.AlignVCenter
                }
                Text { text: "BOOKS"; color: colors.foreground; font.family: colors.fontSans; font.pixelSize: 12; font.weight: Font.ExtraBold; font.letterSpacing: 1.3; Layout.alignment: Qt.AlignVCenter }
                Repeater {
                    model: [{k:"library",t:"LIBRARY"},{k:"store",t:"STORE"}]
                    Rectangle {
                        width: 76; height: 25; radius: 12
                        color: root.tab === modelData.k ? colors.alpha(colors.primary, 0.2) : (tabMa.containsMouse ? colors.alpha(colors.surfaceVariant, 0.5) : colors.alpha(colors.surface, 0.5))
                        border.width: 1; border.color: root.tab === modelData.k ? colors.alpha(colors.primary, 0.45) : colors.alpha(colors.outline, 0.12)
                        Text { anchors.centerIn: parent; text: modelData.t; color: root.tab === modelData.k ? colors.primary : colors.foreground; font.family: colors.fontSans; font.pixelSize: 7; font.weight: Font.Bold; font.letterSpacing: 0.7 }
                        MouseArea { id: tabMa; anchors.fill: parent; hoverEnabled: true; onClicked: root.switchTab(modelData.k) }
                    }
                }
                Item { Layout.fillWidth: true }
                Text { text: root.scanning ? "Scanning…" : (root.library.length+" books"); color: colors.alpha(colors.outline,0.55); font.family: colors.fontSans; font.pixelSize: 8; Layout.alignment: Qt.AlignVCenter }
                Rectangle { width: 28; height: 28; radius: 14; color: rescanMa.containsMouse?colors.alpha(colors.primary,0.22):colors.alpha(colors.surface,0.6); border.width:1; border.color: colors.alpha(colors.primary,0.3)
                    Text { anchors.centerIn: parent; text: ""; color: colors.primary; font.family: colors.fontSans; font.pixelSize: 11
                        RotationAnimation on rotation { running: root.scanning; loops: Animation.Infinite; from: 0; to: 360; duration: 700 } }
                    MouseArea { id: rescanMa; anchors.fill: parent; hoverEnabled: true; onClicked: root.libRescan() } }
                Rectangle {
                    width: 28; height: 28; radius: 14
                    color: closeMa.containsMouse ? colors.alpha(colors.surfaceVariant, 0.6) : colors.alpha(colors.surface, 0.6)
                    border.width:1; border.color: colors.alpha(colors.outline, 0.15)
                    Text { anchors.centerIn: parent; text: "󰅖"; color: colors.foreground; font.family: colors.fontSans; font.pixelSize: 12 }
                    MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled:true; onClicked: root.open=false }
                }
            }

            Rectangle { Layout.fillWidth: true; height:1; color: colors.alpha(colors.outline,0.12) }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // ── library view ─────────────────────────────────────────
                ColumnLayout {
                    id: libraryPage
                    anchors.fill: parent
                    visible: root.tab === "library"
                    spacing: 10

                    // continue-reading card
                    Rectangle {
                        visible: !root.libQuery && root.recentTop() !== null
                        Layout.fillWidth: true; Layout.preferredHeight: 64; radius: 12
                        color: colors.alpha(colors.primary, 0.08)
                        border.width: 1; border.color: colors.alpha(colors.primary, 0.25)
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 10; spacing: 10
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                Text { text: "CONTINUE READING"; color: colors.alpha(colors.primary,0.75); font.family: colors.fontSans; font.pixelSize: 7; font.weight: Font.Bold; font.letterSpacing: 1.3 }
                                Text { text: root.recentTop() ? root.recentTop().title : ""; color: colors.foreground; font.family: colors.fontSans; font.pixelSize: 11; font.weight: Font.ExtraBold; elide: Text.ElideRight; Layout.fillWidth: true }
                                Text { text: root.recentTop() ? ("last opened "+root.fmtAgo(root.recentTop().last)+"  •  "+(root.recentTop().reads||0)+"× read") : ""; color: colors.alpha(colors.outline,0.6); font.family: colors.fontSans; font.pixelSize: 8 }
                            }
                            Rectangle {
                                Layout.preferredWidth: 76; Layout.preferredHeight: 30; radius: 15
                                color: openTopMa.containsMouse ? colors.primary : colors.alpha(colors.primary,0.18)
                                border.width: 1; border.color: colors.alpha(colors.primary,0.4)
                                Text { anchors.centerIn: parent; text: "Open"; color: openTopMa.containsMouse ? colors.background : colors.primary; font.family: colors.fontSans; font.pixelSize: 9; font.weight: Font.Bold }
                                MouseArea { id: openTopMa; anchors.fill: parent; hoverEnabled: true; onClicked: { var t=root.recentTop(); if(t) root.openWith(t.path) } }
                            }
                        }
                    }

                    // search row — titles/authors instantly, full text when 3+ chars
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 34; radius: 9
                            color: colors.alpha(colors.surface, 0.85)
                            border.width: 1; border.color: libSearch.activeFocus ? colors.alpha(colors.primary,0.5) : colors.alpha(colors.outline,0.14)
                            RowLayout { anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 8; spacing: 6
                                Text { text: "󰍉"; color: colors.alpha(colors.outline,0.6); font.family: colors.fontSans; font.pixelSize: 11 }
                                TextField { id: libSearch; Layout.fillWidth: true; placeholderText: "Search titles, authors… (3+ chars also searches inside)"; placeholderTextColor: colors.alpha(colors.outline,0.45); color: colors.foreground; font.family: colors.fontSans; font.pixelSize: 10; background: null; selectByMouse: true; onTextChanged: root.libQuery = text }
                            }
                        }
                        Rectangle {
                            Layout.preferredWidth: 200; Layout.preferredHeight: 34; radius: 9
                            color: colors.alpha(colors.surface, 0.85)
                            border.width:1; border.color: pathField.activeFocus ? colors.alpha(colors.primary,0.5) : colors.alpha(colors.outline,0.14)
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 6; spacing: 6
                                TextField {
                                    id: pathField
                                    Layout.fillWidth: true
                                    placeholderText: "/path/to/book.epub"
                                    placeholderTextColor: colors.alpha(colors.outline,0.45)
                                    color: colors.foreground; font.family: colors.fontSans; font.pixelSize: 9
                                    background: null
                                    selectByMouse: true
                                    onAccepted: { root.openWith(text.trim()); text = "" }
                                }
                                Rectangle {
                                    Layout.preferredWidth: 46; Layout.preferredHeight: 22; radius: 6
                                    color: openMa.containsMouse ? colors.alpha(colors.primary,0.22) : colors.alpha(colors.primary,0.14)
                                    Text { anchors.centerIn: parent; text: "Open"; color: colors.primary; font.family: colors.fontSans; font.pixelSize: 8; font.weight: Font.Bold }
                                    MouseArea { id: openMa; anchors.fill: parent; hoverEnabled:true; onClicked: { root.openWith(pathField.text.trim()); pathField.text = "" } }
                                }
                            }
                        }
                    }

                    // chips: filters + sorts
                    RowLayout {
                        Layout.fillWidth: true; spacing: 6
                        Repeater { model: [{k:"all",t:"All"},{k:"fav",t:"★"},{k:"recent",t:"Recent"},{k:"reads",t:"Most read"},{k:"az",t:"A–Z"},{k:"unread",t:"Unread"},{k:"finished",t:"Done"},{k:"content",t: root.contentSearching ? "Searching…" : (root.contentHits.length ? "Text "+root.contentHits.length : "Text")}]
                            Rectangle { width: modelData.k==="content" ? 84 : 64; height: 26; radius: 13
                                color: root.chipActive(modelData.k) ? colors.alpha(colors.primary,0.2) : (chipMa.containsMouse?colors.alpha(colors.surfaceVariant,0.5):colors.alpha(colors.surface,0.5))
                                border.width: 1; border.color: root.chipActive(modelData.k) ? colors.alpha(colors.primary,0.45) : colors.alpha(colors.outline,0.12)
                                Text { anchors.centerIn: parent; text: modelData.t; color: root.chipActive(modelData.k) ? colors.primary : colors.foreground; font.family: colors.fontSans; font.pixelSize: 7; font.weight: Font.Bold; font.letterSpacing: 0.6 }
                                MouseArea { id: chipMa; anchors.fill: parent; hoverEnabled: true; onClicked: root.chipClicked(modelData.k) }
                            }
                        }
                        Text { Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; text: root.libContentOnly ? root.contentHits.length+" text matches" : ""; color: colors.alpha(colors.primary,0.7); font.family: colors.fontSans; font.pixelSize: 8 }
                    }

                    // rows — Enter/click opens in the right reader
                    ListView {
                        id: libList
                        Layout.fillWidth: true; Layout.fillHeight: true
                        clip: true; spacing: 4
                        highlightMoveDuration: 120
                        highlight: Rectangle { radius: 9; color: colors.alpha(colors.primary,0.10); border.width: 1; border.color: colors.alpha(colors.primary,0.25) }
                        model: root.libRows()
                        delegate: Rectangle {
                            width: ListView.view.width; height: 50; radius: 9
                            color: rowMa.containsMouse ? colors.alpha(colors.primary,0.12) : colors.alpha(colors.surface,0.45)
                            border.width: 1; border.color: colors.alpha(colors.outline,0.10)
                            RowLayout { anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
                                Text { text: modelData.fav ? "★" : "☆"; color: modelData.fav ? colors.primary : colors.alpha(colors.outline,0.5); font.family: colors.fontSans; font.pixelSize: 13
                                    MouseArea { anchors.fill: parent; onClicked: root.toggleFav(modelData.path) } }
                                ColumnLayout { Layout.fillWidth: true; spacing: 1
                                    Text { text: modelData.title; color: colors.foreground; font.family: colors.fontSans; font.pixelSize: 10; font.weight: Font.ExtraBold; elide: Text.ElideRight; Layout.fillWidth: true }
                                    Text { text: root.rowMeta(modelData); color: colors.alpha(colors.outline,0.6); font.family: colors.fontSans; font.pixelSize: 8; elide: Text.ElideRight; Layout.fillWidth: true }
                                }
                                Rectangle {
                                    visible: root.contentHits.indexOf(modelData.path) !== -1
                                    width: 52; height: 18; radius: 9
                                    color: colors.alpha(colors.tertiary, 0.15)
                                    border.width: 1; border.color: colors.alpha(colors.tertiary, 0.35)
                                    Text { anchors.centerIn: parent; text: "TEXT"; color: colors.tertiary; font.family: colors.fontSans; font.pixelSize: 7; font.weight: Font.Bold; font.letterSpacing: 0.6 }
                                }
                                Rectangle {
                                    width: 38; height: 18; radius: 9
                                    color: colors.alpha(colors.primary, 0.12)
                                    border.width: 1; border.color: colors.alpha(colors.primary, 0.25)
                                    Text { anchors.centerIn: parent; text: (modelData.format || root.formatFor(modelData.path)).toUpperCase(); color: colors.primary; font.family: colors.fontSans; font.pixelSize: 6; font.weight: Font.Bold; font.letterSpacing: 0.4 }
                                }
                                Text { text: root.readerLabel(modelData.path)+" →"; color: colors.alpha(colors.primary,0.7); font.family: colors.fontSans; font.pixelSize: 8 }
                            }
                            MouseArea { id: rowMa; anchors.fill: parent; hoverEnabled: true; onClicked: { libList.currentIndex = index; root.openWith(modelData.path) } }
                        }
                        Text {
                            visible: root.libReady && root.libRows().length === 0
                            anchors.centerIn: parent
                            text: root.scanning ? "scanning for books…" : (root.contentSearching ? "searching inside books…" : "nothing here — try another filter")
                            color: colors.alpha(colors.outline, 0.5)
                            font.family: colors.fontSans
                            font.pixelSize: 9
                        }
                    }

                    // selected-file action bar
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 40; radius: 10
                        color: colors.alpha(colors.surface, 0.6)
                        border.width: 1; border.color: colors.alpha(colors.outline, 0.12)
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 8; spacing: 8
                            Text { text: root.selFile() ? root.selFile().title : "—"; color: colors.foreground; font.family: colors.fontSans; font.pixelSize: 9; font.weight: Font.Bold; elide: Text.ElideRight; Layout.fillWidth: true }
                            Rectangle { width: 34; height: 26; radius: 8; color: finMa.containsMouse?colors.alpha(colors.primary,0.22):"transparent"
                                Text { anchors.centerIn: parent; text: (root.selFile() && root.selFile().finished) ? "" : "○"; color: colors.primary; font.family: colors.fontSans; font.pixelSize: 12 }
                                MouseArea { id: finMa; anchors.fill: parent; hoverEnabled: true; onClicked: { var r=root.selFile(); if(r) root.toggleFinished(r.path) } } }
                            Rectangle { width: 30; height: 26; radius: 8; color: actFavMa.containsMouse?colors.alpha(colors.primary,0.22):"transparent"
                                Text { anchors.centerIn: parent; text: (root.selFile() && root.selFile().fav) ? "★" : "☆"; color: colors.primary; font.family: colors.fontSans; font.pixelSize: 12 }
                                MouseArea { id: actFavMa; anchors.fill: parent; hoverEnabled: true; onClicked: { var r=root.selFile(); if(r) root.toggleFav(r.path) } } }
                            Rectangle { width: 34; height: 26; radius: 8; color: actCpMa.containsMouse?colors.alpha(colors.primary,0.22):"transparent"
                                Text { anchors.centerIn: parent; text: "󰅌"; color: colors.foreground; font.family: colors.fontSans; font.pixelSize: 12 }
                                MouseArea { id: actCpMa; anchors.fill: parent; hoverEnabled: true; onClicked: { var r=root.selFile(); if(r) root.copyPath(r.path) } } }
                            Rectangle { width: 34; height: 26; radius: 8; color: actFoMa.containsMouse?colors.alpha(colors.primary,0.22):"transparent"
                                Text { anchors.centerIn: parent; text: "󰉋"; color: colors.foreground; font.family: colors.fontSans; font.pixelSize: 12 }
                                MouseArea { id: actFoMa; anchors.fill: parent; hoverEnabled: true; onClicked: { var r=root.selFile(); if(r) root.openFolder(r.path) } } }
                            Rectangle { width: 76; height: 26; radius: 13; color: actOpMa.containsMouse ? colors.primary : colors.alpha(colors.primary,0.18); border.width: 1; border.color: colors.alpha(colors.primary,0.4)
                                Text { anchors.centerIn: parent; text: "Open"; color: actOpMa.containsMouse ? colors.background : colors.primary; font.family: colors.fontSans; font.pixelSize: 9; font.weight: Font.Bold }
                                MouseArea { id: actOpMa; anchors.fill: parent; hoverEnabled: true; onClicked: { var r=root.selFile(); if(r) root.openWith(r.path) } } }
                        }
                    }
                }

                // ── store view ───────────────────────────────────────────
                BookStore {
                    id: store
                    anchors.fill: parent
                    visible: root.tab === "store"
                    colors: root.colors
                    library: root.library
                    active: root.tab === "store"
                    onBookDownloaded: function(entry){ root.addDownloaded(entry) }
                    onOpenBook: function(path){ root.openWith(path) }
                }
            }

            // keyboard hints
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.tab === "store" ? "↑↓ scroll · ↵ download/open · S shuffle · / search · Esc close" : "↑↓ browse · ↵ open · F favourite · C copy path · Tab store · Esc close"
                color: colors.alpha(colors.outline, 0.5)
                font.family: colors.fontSans
                font.pixelSize: 8
                font.letterSpacing: 0.3
            }
        }
    }
}
