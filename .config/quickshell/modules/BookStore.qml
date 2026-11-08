import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

// BookStore — the acquisition half of the books panel.
//
// Catalogs: Project Gutenberg (Gutendex), Open Library / Internet Archive
// public scans, Standard Ebooks, and Anna's Archive. Search runs in
// parallel, discovery is random (except AA, which is search-only), and
// downloads are queued into ~/Books.
//
// Annas Archive notes (verified against annas-archive.gl):
//  - /search and /md5 sit behind DDoS-Guard. A browser that has cleared
//    the guard leaves __ddg1_/__ddg2_/__ddgid_/__ddgmark_ in its
//    cookies.sqlite, and AA sets aa_ddg_check, a 15-minute ticket whose
//    payload names the matching __ddg5_. scripts/aa-fetch.py replays that
//    state with a Firefox TLS fingerprint; plain curl is rejected.
//    QtWebEngine can't replace it: quickshell crashes at profile init
//    (upstream issue quickshell-mirror/quickshell#935).
//  - When the ticket is stale, the panel opens the search URL in Zen and
//    waits for a fresh ticket in the profile database, then retries over
//    HTTP. The tab only exists to satisfy the guard; results render in
//    the grid. No browser window is opened while the ticket is fresh.
//  - Results pages carry 25 entries; &page=N pages forward.
//  - Every AA account has a "Secret key"; it is only used by the member
//    fast-download API and does not bypass the guard for free accounts.
//  - Free downloads: the /md5 page lists external mirrors (IPFS and
//    Libgen). Those links are queued and saved like every other source.
//  - The key lives at ~/.local/state/quickshell/aa-key.txt (0600).
Item {
    id: store
    property var colors
    property var library: []
    property bool active: false

    signal bookDownloaded(var entry)
    signal openBook(string path)

    readonly property string booksDir: Quickshell.env("HOME") + "/Books"
    property string source: "all"       // all | gutenberg | openlibrary | standardebooks | annasarchive
    property string query: ""
    property string sortMode: "discover" // discover | search
    property string notice: ""
    property bool loading: false
    property int pending: 0
    property bool searchQueued: false
    property var results: []
    property var raw: ({})
    property var seen: ({})
    property int gPage: 0
    property int olPage: 0
    property bool gHasMore: true
    property bool olHasMore: true

    // annas archive state
    readonly property string aaBase: Quickshell.env("ANNAS_ARCHIVE_BASE") || "https://annas-archive.gl"
    readonly property string aaJar: Quickshell.env("HOME") + "/.local/state/quickshell/aa-jar.txt"
    readonly property string aaKeyPath: Quickshell.env("HOME") + "/.local/state/quickshell/aa-key.txt"
    readonly property string aaUA: "Mozilla/5.0 (X11; Linux x86_64; rv:146.0) Gecko/20100101 Firefox/146.0"
    readonly property string aaPy: Quickshell.env("HOME") + "/.local/state/quickshell/aa-venv/bin/python"
    readonly property string aaHelper: Quickshell.env("HOME") + "/.config/quickshell/scripts/aa-fetch.py"
    property string aaKey: ""
    property bool aaLoggedIn: false
    property bool aaReloginTried: false
    property int aaPage: 0
    property bool aaHasMore: true
    property var aaBook: null
    property var aaLoginDone: null
    property bool aaRefreshing: false
    property bool aaRefreshUsed: false
    property int aaRefreshTries: 0
    property double aaLastRefresh: 0
    property string aaRetryKind: "search"   // search | record | ipfs
    property int aaReqSeq: 0
    property int aaPageSeq: 0
    property int aaReqPage: 1
    property string aaReqQuery: ""
    property string aaRecordUrl: ""
    property string aaPendingUrl: ""

    // download queue
    property var dlQueue: []
    property var dlState: ({})
    property var downloaded: ({})
    property string dlCurrentKey: ""
    property var dlCurrentMeta: null
    property string dlPath: ""
    property string dlTmp: ""
    property double dlTotal: 0
    property var iaBook: null

    readonly property var sourceChips: [
        {k:"all", t:"All"},
        {k:"gutenberg", t:"Gutenberg"},
        {k:"openlibrary", t:"Open Library"},
        {k:"standardebooks", t:"Standard Ebooks"},
        {k:"annasarchive", t:"Annas"}
    ]
    readonly property var selBook: {
        if(!store.results.length) return null
        var i = store.gridIndex
        if(i < 0 || i >= store.results.length) return null
        return store.results[i]
    }
    property int gridIndex: 0

    onActiveChanged: if(active) activate()
    onResultsChanged: {
        if(gridIndex < 0 && results.length) gridIndex = 0
        if(gridIndex >= results.length) gridIndex = Math.max(0, results.length - 1)
    }

    function shQuote(s){ return "'" + String(s).replace(/'/g, "'\\''") + "'" }
    function enc(s){ return encodeURIComponent(String(s || "")) }
    function randomInt(a, b){ return a + Math.floor(Math.random() * (b - a + 1)) }
    function decodeEntities(s){
        return String(s || "")
            .replace(/&amp;/g, "&")
            .replace(/&quot;/g, "\"")
            .replace(/&#39;|&apos;/g, "'")
            .replace(/&lt;/g, "<")
            .replace(/&gt;/g, ">")
            .replace(/&nbsp;/g, " ")
            .replace(/&#([0-9]+);/g, function(_, n){ return String.fromCharCode(parseInt(n, 10)) })
    }
    function authorName(n){
        var s = String(n || "").trim()
        var p = s.split(", ")
        if(p.length === 2) return p[1] + " " + p[0]
        return s
    }
    function activate(){
        if(!active) return
        if(!results.length) shuffle()
        Qt.callLater(function(){ if(store.active) grid.forceActiveFocus() })
    }
    function sourceLabel(k){
        if(k === "gutenberg") return "Gutenberg"
        if(k === "openlibrary") return "Open Library"
        if(k === "standardebooks") return "Standard Ebooks"
        if(k === "annasarchive") return "Annas Archive"
        return "All"
    }
    function fmtFormats(b){
        if(!b) return ""
        if(b.aaMd5 && !b.epubUrl && !b.pdfUrl) return String(b.aaExt || "AA").toUpperCase()
        if(b.iaId) return "EPUB / PDF"
        if(b.epubUrl && b.pdfUrl) return "EPUB + PDF"
        if(b.epubUrl) return "EPUB"
        if(b.pdfUrl) return "PDF"
        if(b.borrowUrl) return "BORROW"
        return "DETAILS"
    }
    function dlFor(key){ return store.dlState[key] || ({}) }
    function isDownloaded(key){
        if(store.downloaded[key]) return true
        for(var i=0;i<store.library.length;i++) if(store.library[i].sourceId === key) return true
        return false
    }
    function downloadedPath(key){
        if(store.downloaded[key]) return store.downloaded[key]
        for(var i=0;i<store.library.length;i++) if(store.library[i].sourceId === key) return store.library[i].path
        return ""
    }
    function actionLabel(b){
        if(!b) return "Select a book"
        if(store.isDownloaded(b.key)) return "Open"
        var s = store.dlFor(b.key).status
        if(s === "queued") return "Queued"
        if(s === "resolving" || s === "downloading") return "Downloading…"
        if(s === "failed") return "Retry"
        if(b.epubUrl || b.pdfUrl || b.iaId || b.aaMd5) return "Download"
        if(b.borrowUrl) return "Borrow"
        return "Details"
    }
    function actionFor(b){
        if(!b) return
        var p = store.downloadedPath(b.key)
        if(p){ store.openBook(p); return }
        var s = store.dlFor(b.key).status
        if(s === "queued" || s === "resolving" || s === "downloading") return
        if(b.epubUrl || b.pdfUrl || b.iaId || b.aaMd5){ store.enqueue(b); return }
        if(b.borrowUrl){ Quickshell.execDetached(["xdg-open", b.borrowUrl]); return }
        if(b.detailsUrl) Quickshell.execDetached(["xdg-open", b.detailsUrl])
    }
    function openDetails(b){
        if(!b) return
        var u = b.detailsUrl || b.borrowUrl
        if(u) Quickshell.execDetached(["xdg-open", u])
    }

    // ── search / discovery ──────────────────────────────────────────────
    function shuffle(){
        search.text = ""
        store.query = ""
        store.source = "all"
        store.startSearch(true)
    }
    function startSearch(reset){
        if(reset && store.loading){
            store.searchQueued = true
            return
        }
        if(!reset && store.loading) return
        var q = store.query.trim()
        if(reset){
            store.raw = ({})
            store.seen = ({})
            store.results = []
            store.gridIndex = 0
            store.gPage = 0
            store.olPage = 0
            store.gHasMore = true
            store.olHasMore = true
            store.aaPage = 1
            store.aaHasMore = true
            store.aaReloginTried = false
            store.aaRefreshing = false
            store.aaRefreshUsed = false
            store.aaRefreshTries = 0
            if(aaRefreshTimer) aaRefreshTimer.stop()
            store.notice = ""
            store.sortMode = q === "" ? "discover" : "search"
            Qt.callLater(function(){ if(grid.count) grid.currentIndex = 0 })
        }
        var srcs = []
        if(store.source === "all" || store.source === "gutenberg") srcs.push("g")
        if(store.source === "all" || store.source === "openlibrary") srcs.push("ol")
        if((store.source === "standardebooks" || (store.source === "all" && q !== "")) && reset) srcs.push("se")
        var wantAA = store.source === "annasarchive" || (store.source === "all" && q !== "" && store.aaKey.trim() !== "")
        if(q !== "" && wantAA) srcs.push("aa")
        if(store.source === "annasarchive" && q === ""){
            if(reset) store.notice = "Type something — Annas Archive is search-only"
        }
        if(!srcs.length){ store.loading = false; return }
        store.pending = srcs.length
        store.loading = true
        if(store.source === "annasarchive" && srcs.indexOf("aa") === -1){ store.finishSource(); return }
        for(var i=0;i<srcs.length;i++){
            if(srcs[i] === "g") store.fetchG(reset)
            else if(srcs[i] === "ol") store.fetchOL(reset)
            else if(srcs[i] === "aa") store.fetchAA(reset)
            else store.fetchSE(reset)
        }
    }
    function loadMore(){
        if(store.loading || !store.results.length) return
        var srcs = []
        if((store.source === "all" || store.source === "gutenberg") && store.gHasMore) srcs.push("g")
        if((store.source === "all" || store.source === "openlibrary") && store.olHasMore) srcs.push("ol")
        if(store.source === "annasarchive" && store.aaHasMore && store.query.trim() !== "") srcs.push("aa")
        if(!srcs.length){ store.notice = "End of the shelf"; return }
        store.pending = srcs.length
        store.loading = true
        for(var i=0;i<srcs.length;i++){
            if(srcs[i] === "g") store.fetchG(false)
            else if(srcs[i] === "ol") store.fetchOL(false)
            else if(srcs[i] === "aa") store.fetchAA(false)
        }
    }
    function finishSource(){
        store.pending = Math.max(0, store.pending - 1)
        if(store.pending === 0){
            store.loading = false
            if(store.sortMode === "search") store.rebuild()
            if(store.results.length === 0 && store.notice === "") store.notice = "No books found — check connection"
            if(store.searchQueued){
                store.searchQueued = false
                store.startSearch(true)
            }
        } else if(store.sortMode === "search"){
            store.rebuild()
        }
    }
    function addBook(b){
        if(!b || !b.key || store.seen[b.key]) return
        store.seen[b.key] = true
        if(store.sortMode === "search"){
            store.raw[b.key] = b
        } else {
            store.results = store.results.concat([b])
        }
    }
    function scoreBook(b){
        var q = store.query.trim().toLowerCase()
        if(!q) return 0
        var t = String(b.title || "").toLowerCase()
        var a = String(b.author || "").toLowerCase()
        var s = 0
        if(t === q) s += 100
        else if(t.indexOf(q) === 0) s += 60
        else if(t.indexOf(q) !== -1) s += 30
        if(a.indexOf(q) !== -1) s += 15
        if(b.epubUrl || b.pdfUrl || b.iaId || b.aaMd5) s += 8
        if(b.cover) s += 2
        b.score = s
        return s
    }
    function rebuild(){
        var arr = []
        for(var k in store.raw) arr.push(store.raw[k])
        arr.sort(function(a,b){
            var d = (b.score || 0) - (a.score || 0)
            if(d !== 0) return d
            return String(a.title || "").localeCompare(String(b.title || ""))
        })
        store.results = arr
    }

    // ── Gutenberg / Gutendex ───────────────────────────────────────────
    function fetchG(reset){
        if(!reset && !store.gHasMore){ store.finishSource(); return }
        var page
        if(reset) page = store.query.trim() === "" ? store.randomInt(1, 24) : 1
        else page = store.gPage + 1
        if(page > 60){ store.gHasMore = false; store.finishSource(); return }
        store.gPage = page
        var u = "https://gutendex.com/books/?languages=en&page=" + page
        if(store.query.trim() !== "") u += "&search=" + store.enc(store.query.trim())
        else u += "&sort=popular"
        gProc.command = ["sh","-c","curl -sSL -m 30 -A 'bookshelf/1.0' " + store.shQuote(u) + " 2>/dev/null"]
        gProc.running = true
    }
    Process {
        id: gProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var d = null
                try { d = JSON.parse(text) } catch(e) {}
                if(!d || !d.results){
                    store.finishSource()
                    return
                }
                store.gHasMore = !!d.next
                for(var i=0;i<d.results.length;i++){
                    var b = d.results[i]
                    var f = b.formats || {}
                    var epub = f["application/epub+zip"] || ""
                    var pdf = f["application/pdf"] || ""
                    if(!epub && !pdf) continue
                    var authors = b.authors || []
                    var a = authors.length ? store.authorName(authors[0].name) : ""
                    var summary = b.summaries && b.summaries.length ? b.summaries[0] : ""
                    store.addBook({
                        key: "gutenberg:" + b.id,
                        title: store.decodeEntities(b.title || "Untitled"),
                        author: store.decodeEntities(a),
                        year: "",
                        cover: f["image/jpeg"] || "",
                        epubUrl: epub,
                        pdfUrl: pdf,
                        iaId: "",
                        borrowUrl: "",
                        detailsUrl: "https://www.gutenberg.org/ebooks/" + b.id,
                        source: "Gutenberg",
                        sourceKey: "gutenberg",
                        summary: store.decodeEntities(summary)
                    })
                }
                store.finishSource()
            }
        }
    }

    // ── Open Library / Internet Archive ────────────────────────────────
    function fetchOL(reset){
        if(!reset && !store.olHasMore){ store.finishSource(); return }
        var page = reset ? 1 : store.olPage + 1
        if(page > 50){ store.olHasMore = false; store.finishSource(); return }
        store.olPage = page
        var q = store.query.trim()
        var disc = q === ""
        if(disc) q = "subject:fiction AND ebook_access:public"
        var u = "https://openlibrary.org/search.json?"
        u += "q=" + store.enc(q) + "&page=" + page + "&limit=24"
        u += "&fields=key,title,author_name,first_publish_year,cover_i,ebook_access,ia,isbn,edition_count"
        if(disc) u += "&sort=random"
        olProc.command = ["sh","-c","curl -sSL -m 30 -A 'bookshelf/1.0' " + store.shQuote(u) + " 2>/dev/null"]
        olProc.running = true
    }
    Process {
        id: olProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var d = null
                try { d = JSON.parse(text) } catch(e) {}
                if(!d || !d.docs){
                    store.finishSource()
                    return
                }
                store.olHasMore = d.docs.length >= 24
                for(var i=0;i<d.docs.length;i++){
                    var x = d.docs[i]
                    var access = x.ebook_access || ""
                    if(access !== "public" && access !== "borrowable") continue
                    var key = x.key || ""
                    if(!key) continue
                    var ia = ""
                    if(x.ia){
                        if(Array.isArray(x.ia)) ia = x.ia.length ? x.ia[0] : ""
                        else ia = String(x.ia)
                    }
                    var auth = ""
                    if(x.author_name && x.author_name.length) auth = x.author_name.slice(0, 2).join(", ")
                    var cover = x.cover_i ? ("https://covers.openlibrary.org/b/id/" + x.cover_i + "-M.jpg") : ""
                    store.addBook({
                        key: "openlibrary:" + key,
                        title: store.decodeEntities(x.title || "Untitled"),
                        author: store.decodeEntities(auth),
                        year: x.first_publish_year ? String(x.first_publish_year) : "",
                        cover: cover,
                        epubUrl: "",
                        pdfUrl: "",
                        iaId: access === "public" ? ia : "",
                        borrowUrl: access === "public" ? "" : ("https://openlibrary.org" + key),
                        detailsUrl: "https://openlibrary.org" + key,
                        source: "Open Library",
                        sourceKey: "openlibrary",
                        summary: "",
                        access: access
                    })
                }
                store.finishSource()
            }
        }
    }

    // ── Standard Ebooks (public HTML search) ───────────────────────────
    function fetchSE(reset){
        if(!reset){ store.finishSource(); return }
        var u = "https://standardebooks.org/ebooks?view=grid&per-page=24&sort="
        u += store.query.trim() === "" ? "popularity" : "relevance"
        if(store.query.trim() !== "") u += "&query=" + store.enc(store.query.trim())
        seProc.command = ["sh","-c","curl -sSL -m 30 -A 'bookshelf/1.0' " + store.shQuote(u) + " 2>/dev/null"]
        seProc.running = true
    }
    Process {
        id: seProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var html = text || ""
                var re = /<li[^>]*typeof="schema:Book"[^>]*about="([^"]+)"[^>]*>([\s\S]*?)<\/li>/g
                var m
                while((m = re.exec(html)) !== null){
                    var path = m[1]
                    var block = m[2]
                    var tm = block.match(/<span property="schema:name">([^<]*)<\/span>/)
                    var am = block.match(/<p class="author"[\s\S]*?<span property="schema:name">([^<]*)<\/span>/)
                    var cm = block.match(/<img[^>]+src="([^"]+)"/)
                    if(!tm) continue
                    var slug = path.replace(/^\/ebooks\//, "").replace(/\//g, "_")
                    var cover = cm ? cm[1] : ""
                    if(cover.indexOf("http") !== 0) cover = "https://standardebooks.org" + cover
                    store.addBook({
                        key: "standardebooks:" + path,
                        title: store.decodeEntities(tm[1]),
                        author: am ? store.decodeEntities(am[1]) : "",
                        year: "",
                        cover: cover,
                        epubUrl: "https://standardebooks.org" + path + "/downloads/" + slug + ".epub?source=download",
                        pdfUrl: "",
                        iaId: "",
                        borrowUrl: "",
                        detailsUrl: "https://standardebooks.org" + path,
                        source: "Standard Ebooks",
                        sourceKey: "standardebooks",
                        summary: ""
                    })
                }
                store.finishSource()
            }
        }
    }

    // ── Anna's Archive (session HTML search + shrinking) ───────────────
    function extractFormat(meta){
        // "English [en] · EPUB · 0.4MB · 2014 · 🚀 ..." → "epub" + year
        var segs = String(meta || "").split("·")
        var ext = ""
        var year = ""
        for(var i=0;i<segs.length;i++){
            var seg = segs[i].trim()
            var tok = seg.toLowerCase().replace(/-/g, "")
            if(seg.indexOf("[") !== -1 && tok.length <= 6) continue
            if(!ext && tok.length >= 1 && tok.length <= 6 && /^[a-z][a-z0-9]*$/.test(tok)) ext = tok
            var ym = seg.match(/^(19|20)[0-9]{2}$/)
            if(ym && year === "") year = seg
        }
        return {ext: ext, year: year}
    }
    function aaStripTags(s){
        return store.decodeEntities(String(s || "").replace(/<[^>]+>/g, " "))
            .replace(/\s+/g, " ").trim()
    }
    function fetchAA(reset){
        if(!reset && !store.aaHasMore){ store.finishSource(); return }
        store.aaFetchPage(reset ? 1 : store.aaPage + 1)
    }
    function aaFetchPage(page){
        if(page > 20){ store.aaHasMore = false; store.finishSource(); return }
        var q = store.query.trim()
        store.aaPage = page
        store.aaReqPage = page
        store.aaReqQuery = q
        store.aaReqSeq++
        store.aaRetryKind = "search"
        var u = store.aaBase + "/search?q=" + store.enc(q)
        if(page > 1) u += "&page=" + page
        aaProc.reqSeq = store.aaReqSeq
        aaProc.command = [store.aaPy, store.aaHelper, "fetch", u]
        aaProc.running = true
    }
    function aaIsChallenge(html){
        var h = String(html || "")
        if(h.indexOf("DDoS-Guard") !== -1) return true
        if(/check=1/.test(h) && h.length < 800) return true
        return false
    }
    function aaSmartCase(s){
        var t = String(s || "").trim()
        if(t === "" || t !== t.toUpperCase() || !/[A-Z]/.test(t)) return t
        t = t.toLowerCase().replace(/(^|[\s.\-'])([a-z])/g, function(_, p, c){ return p + c.toUpperCase() })
        t = t.replace(/'([A-Z])/g, function(_, c){ return "'" + c.toLowerCase() })
        if(/^[A-Za-z]+\.$/.test(t)) t = t.slice(0, -1)
        return t
    }
    function parseAASearch(html){
        var base = store.aaBase
        var out = []
        var rows = []
        var rr = /<div[^>]*class="[^"]*pt-3[^"]*pb-3[^"]*border-b[^"]*"[^>]*>/g
        var m
        while((m = rr.exec(html)) !== null) rows.push(m.index)
        for(var i=0;i<rows.length;i++){
            var card = html.substring(rows[i], i+1 < rows.length ? rows[i+1] : html.length)
            var hm = card.match(/href="\/md5\/([0-9a-f]{32})"/)
            if(!hm) continue
            var md5 = hm[1]
            var dupe = false
            for(var d=0;d<out.length;d++) if(out[d].aaMd5 === md5){ dupe = true; break }
            if(dupe) continue
            var title = ""
            var tm = card.match(/<a\b([^>]*js-vim-focus[^>]*)>([\s\S]*?)<\/a>/)
            if(tm) title = store.aaStripTags(tm[2])
            if(title === ""){
                var anchors = card.match(/<a\b[^>]*href="\/md5\/[0-9a-f]{32}"[^>]*>[\s\S]*?<\/a>/g) || []
                for(var a=0;a<anchors.length;a++){
                    var t = store.aaStripTags(anchors[a].replace(/^<a\b[^>]*>/, "").replace(/<\/a>$/, ""))
                    if(t !== ""){ title = t; break }
                }
            }
            title = store.aaSmartCase(title)
            if(title === "") continue
            var author = ""
            var ai = card.indexOf("mdi--user-edit")
            if(ai !== -1){
                var a0 = card.lastIndexOf("<a", ai)
                var a1 = card.indexOf("</a>", ai)
                if(a0 !== -1 && a1 > ai) author = store.aaStripTags(card.substring(card.indexOf(">", a0) + 1, a1))
            }
            author = store.aaSmartCase(author)
            var cover = ""
            var ci = card.indexOf("list_cover_aarecord_id__")
            if(ci !== -1){
                var cm = card.substring(ci, ci + 2500).match(/<img[^>]*src="([^"]+)"/)
                if(cm){
                    cover = cm[1]
                    if(cover.indexOf("http") !== 0) cover = base + "/" + cover.replace(/^\//, "")
                }
            }
            var meta = ""
            var mm = card.match(/<div[^>]*class="[^"]*font-semibold[^"]*text-sm[^"]*"[^>]*>([\s\S]*?)<\/div>/)
            if(mm){
                var inner = mm[1]
                var stop = inner.search(/<a\b|<script\b|<button\b/i)
                if(stop !== -1) inner = inner.substring(0, stop)
                meta = store.aaStripTags(inner).replace(/\s*·\s*$/, "")
            }
            var summary = ""
            var sm = card.match(/<div[^>]*class="[^"]*text-gray-600[^"]*mt-2[^"]*mb-2[^"]*"[^>]*>([\s\S]*?)<\/div>/)
            if(sm) summary = store.aaStripTags(sm[1]).slice(0, 800)
            var f = store.extractFormat(meta)
            var sz = meta.match(/([0-9.]+\s*[KMG]B)/i)
            out.push({
                key: "annas:" + md5,
                title: title,
                author: author,
                year: f.year,
                cover: cover,
                epubUrl: "",
                pdfUrl: "",
                iaId: "",
                borrowUrl: "",
                detailsUrl: base + "/md5/" + md5,
                source: "Annas Archive",
                sourceKey: "annasarchive",
                summary: summary,
                aaMd5: md5,
                aaExt: f.ext || "",
                aaSize: sz ? sz[1] : ""
            })
        }
        return out
    }
    function aaHandleSearch(body){
        store.aaRefreshUsed = false
        var found = store.parseAASearch(body)
        if(found.length < 25) store.aaHasMore = false
        for(var i=0;i<found.length;i++) store.addBook(found[i])
        store.finishSource()
    }
    function aaStartRefresh(kind){
        if(kind === "search" && store.source !== "annasarchive"){
            store.notice = "Annas is shielded right now — open the Annas chip to retry"
            store.finishSource()
            return
        }
        if(store.aaRefreshUsed){
            store.aaRefreshing = false
            aaRefreshTimer.stop()
            store.aaHasMore = false
            store.notice = "Annas shield didn't refresh — try again shortly"
            if(kind === "search") store.finishSource()
            else store.failCurrent("Annas is blocking this network — try again shortly")
            return
        }
        store.aaRetryKind = kind
        store.aaRefreshUsed = true
        store.aaRefreshTries = 0
        store.aaRefreshing = true
        var now = Date.now()
        if(now - store.aaLastRefresh > 20000){
            store.aaLastRefresh = now
            var q = store.aaReqQuery !== "" ? store.aaReqQuery : store.query.trim()
            var u = store.aaBase + "/search" + (q !== "" ? ("?q=" + store.enc(q)) : "")
            store.notice = "Refreshing the Annas shield in Zen…"
            Quickshell.execDetached(["sh","-c",
                "command -v zen >/dev/null 2>&1 && zen " + store.shQuote(u) + " >/dev/null 2>&1 || xdg-open " + store.shQuote(u) + " >/dev/null 2>&1"])
        } else {
            store.notice = "Waiting for the Annas shield refresh…"
        }
        aaRefreshTimer.restart()
    }
    function aaRefreshDone(){
        store.aaRefreshing = false
        aaRefreshTimer.stop()
        store.notice = "Shield ready — fetching Annas…"
        if(store.aaRetryKind === "record") store.aaFetchRecord()
        else if(store.aaRetryKind === "ipfs") store.aaFetchUrl(store.aaPendingUrl, "ipfs")
        else store.aaFetchPage(store.aaReqPage)
    }
    Process {
        id: aaProc
        property int reqSeq: 0
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                if(aaProc.reqSeq !== store.aaReqSeq) return
                var raw = text || ""
                var cut = raw.lastIndexOf("__AAF:")
                var mark = cut === -1 ? "" : raw.substring(cut).split("\n")[0].trim()
                var body = cut === -1 ? raw : raw.substring(0, cut)
                if(mark.indexOf("__AAF:OK") === 0){ store.aaHandleSearch(body); return }
                if(mark.indexOf("__AAF:STALE") === 0 || mark.indexOf("__AAF:CHALLENGE") === 0){
                    store.aaStartRefresh("search")
                    return
                }
                if(mark.indexOf("__AAF:NET") === 0 || mark.indexOf("__AAF:HTML") === 0){
                    store.notice = "Annas Archive unreachable — try again shortly"
                    store.finishSource()
                    return
                }
                if(store.aaIsChallenge(body)){ store.aaStartRefresh("search"); return }
                store.notice = "Annas Archive returned no data"
                store.finishSource()
            }
        }
    }
    Timer {
        id: aaRefreshTimer
        interval: 5000
        repeat: true
        onTriggered: {
            if(!store.aaRefreshing){ stop(); return }
            if(store.aaRefreshTries >= 18){
                store.aaRefreshing = false
                stop()
                store.aaHasMore = false
                store.notice = "Annas shield didn't refresh — try again shortly"
                if(store.aaRetryKind === "search") store.finishSource()
                else store.failCurrent("Annas is blocking this network — try again shortly")
                return
            }
            store.aaRefreshTries++
            aaTicketProc.command = [store.aaPy, store.aaHelper, "ticket"]
            aaTicketProc.running = true
        }
    }
    Process {
        id: aaTicketProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                if(!store.aaRefreshing) return
                var m = (text || "").match(/__AAF:TICKET:(\d+)/)
                if(!m) return
                if(parseInt(m[1]) < 700) store.aaRefreshDone()
            }
        }
    }

    Process {
        id: aaLoginProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var ok = text.indexOf("__AAL:1") !== -1
                store.aaLoggedIn = ok
                if(ok){
                    store.notice = "Annas Archive signed in"
                } else if(text.indexOf("__AAL:t") !== -1){
                    store.notice = "Annas Archive did not answer — try again shortly"
                } else {
                    store.notice = "Annas Archive rejected that key — free accounts: Profile → Secret key"
                }
                if(store.aaReloginTried) store.aaReloginTried = false
                if(store.aaLoginDone) store.aaLoginDone(ok)
            }
        }
    }
    function aaLogin(done){
        store.aaLoginDone = done || null
        var k = store.aaKey.trim()
        if(k === ""){
            store.notice = "Add your Annas Archive key first"
            if(store.aaLoginDone) store.aaLoginDone(false)
            return
        }
        aaLoginProc.command = ["sh","-c",
            "mkdir -p ~/.local/state/quickshell; " +
            "curl -sS -m 25 --max-redirs 2 " +
            " -b " + store.shQuote(store.aaJar) + " -c " + store.shQuote(store.aaJar) +
            " -A " + store.shQuote(store.aaUA) +
            " -H 'Content-Type: application/x-www-form-urlencoded' " +
            " --data 'key=" + store.enc(k) + "' " +
            " " + store.shQuote(store.aaBase + "/account/") + " -o /dev/null; " +
            "rc=$?; " +
            "grep -c 'aa_' " + store.shQuote(store.aaJar) + " >/dev/null 2>&1 && echo __AAL:1 || { [ $rc -eq 28 ] && echo __AAL:t || echo __AAL:0; }"]
        aaLoginProc.running = true
    }

    // ── AA key persistence ─────────────────────────────────────────────
    Process {
        id: aaKeyLoad
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                store.aaKey = text.trim()
                if(aaKeyField) aaKeyField.text = store.aaKey
            }
        }
    }
    Component.onCompleted: {
        aaKeyLoad.command = ["sh","-c","cat " + store.shQuote(store.aaKeyPath) + " 2>/dev/null"]
        aaKeyLoad.running = true
    }
    function aaSaveKey(){
        var k = store.aaKey.trim()
        aaKeyWrite.command = ["sh","-c",
            "mkdir -p ~/.local/state/quickshell; " +
            "umask 177; printf '%s' " + store.shQuote(k) + " > " + store.shQuote(store.aaKeyPath)]
        aaKeyWrite.running = true
        if(k === ""){
            aaKeyField.text = ""
            store.aaJarReset(); store.aaLoggedIn = false; store.notice = "Annas key cleared"; return
        }
        store.notice = "Signing in to Annas Archive…"
        store.aaLogin(function(ok){
            if(ok && store.source === "annasarchive" && store.query.trim() !== "") store.startSearch(true)
        })
    }
    function aaJarReset(){
        aaJarResetProc.command = ["sh","-c","rm -f " + store.shQuote(store.aaJar)]
        aaJarResetProc.running = true
    }
    Process {
        id: aaKeyWrite
        stdout: StdioCollector { waitForEnd: true; onStreamFinished: {} }
    }
    Process {
        id: aaJarResetProc
        stdout: StdioCollector { waitForEnd: true; onStreamFinished: {} }
    }

    // ── download queue ─────────────────────────────────────────────────
    function dlSet(key, pct, status){
        var s = Object.assign({}, store.dlState)
        s[key] = {pct: pct, status: status}
        store.dlState = s
    }
    function enqueue(b){
        if(!b || store.isDownloaded(b.key)) return
        for(var i=0;i<store.dlQueue.length;i++) if(store.dlQueue[i].key === b.key) return
        var s = store.dlFor(b.key).status
        if(s === "queued" || s === "resolving" || s === "downloading") return
        if(!b.epubUrl && !b.pdfUrl && !b.iaId && !b.aaMd5) return
        store.dlQueue = store.dlQueue.concat([b])
        store.dlSet(b.key, 0, "queued")
        store.pumpQueue()
    }
    function pumpQueue(){
        if(store.dlCurrentKey !== "" || !store.dlQueue.length) return
        var b = store.dlQueue[0]
        store.dlQueue = store.dlQueue.slice(1)
        if(store.isDownloaded(b.key)){ store.pumpQueue(); return }
        store.dlCurrentKey = b.key
        store.dlCurrentMeta = b
        store.dlSet(b.key, 0, "resolving")
        if(!b.epubUrl && !b.pdfUrl && b.iaId){
            store.iaBook = b
            iaProc.command = ["sh","-c","curl -sSL -m 30 -A 'bookshelf/1.0' " + store.shQuote("https://archive.org/metadata/" + b.iaId) + " 2>/dev/null"]
            iaProc.running = true
            return
        }
        if(!b.epubUrl && !b.pdfUrl && b.aaMd5){
            store.aaBook = b
            store.aaRefreshUsed = false
            store.aaRefreshing = false
            store.aaPendingUrl = ""
            if(store.aaKey.trim() !== ""){
                aaFastProc.command = ["sh","-c",
                    "curl -sS -b " + store.shQuote(store.aaJar) + " -c " + store.shQuote(store.aaJar) +
                    " -A " + store.shQuote(store.aaUA) + " -m 30 " +
                    store.shQuote(store.aaBase + "/dyn/api/fast_download.json?md5=" + b.aaMd5 + "&key=" + store.enc(store.aaKey.trim())) +
                    " 2>/dev/null"]
                aaFastProc.running = true
            } else {
                store.aaFetchRecord()
            }
            return
        }
        var url = b.epubUrl || b.pdfUrl
        var ext = b.epubUrl ? "epub" : "pdf"
        store.startDownload(b, url, ext)
    }
    function aaFetchRecord(){
        var b = store.aaBook
        if(!b){ store.failCurrent("Download resolver lost the book"); return }
        store.aaFetchUrl(b.detailsUrl || (store.aaBase + "/md5/" + b.aaMd5), "record")
    }
    function aaFetchUrl(url, purpose){
        if(!store.aaBook){ store.failCurrent("Download resolver lost the book"); return }
        if(url === ""){ store.failCurrent("No book page to resolve"); return }
        store.aaRetryKind = purpose
        store.aaPendingUrl = url
        if(purpose === "record") store.aaRecordUrl = url
        store.aaPageSeq++
        aaPageProc.reqSeq = store.aaPageSeq
        aaPageProc.purpose = purpose
        aaPageProc.command = [store.aaPy, store.aaHelper, "fetch", url]
        aaPageProc.running = true
    }
    function aaDownloadExt(b, url){
        var e = String(b && b.aaExt || "").toLowerCase()
        if(e === "pdf" || e.indexOf("pdf") !== -1) return "pdf"
        if(/\.pdf(\?|$)/i.test(url || "")) return "pdf"
        return "epub"
    }
    function aaHandleRecord(body){
        var b = store.aaBook
        if(!b){ store.failCurrent("Download resolver lost the book"); return }
        var base = store.aaBase
        var links = []
        var seen = ({})
        var re = /<a\b([^>]*)>([\s\S]*?)<\/a>/g
        var m
        while((m = re.exec(body)) !== null){
            var attrs = m[1]
            if(attrs.indexOf("js-download-link") === -1) continue
            var hm = /href="([^"]+)"/.exec(attrs)
            if(!hm) continue
            var u = store.decodeEntities(hm[1])
            if(u === "" || u.indexOf("javascript:") === 0 || u.charAt(0) === "#") continue
            if(u.indexOf("http") !== 0 && u.charAt(0) === "/") u = base + u
            if(seen[u]) continue
            seen[u] = true
            links.push({url: u, label: store.aaStripTags(m[2])})
        }
        var ipfs = body.match(/https:\/\/[^"'\s<>]+\/ipfs\/[A-Za-z0-9]+[^"'\s<>]*/g) || []
        for(var i=0;i<ipfs.length;i++){
            var iu = ipfs[i].replace(/&amp;/g, "&")
            if(!seen[iu]){ seen[iu] = true; links.push({url: iu, label: "IPFS"}) }
        }
        var direct = ""
        var ads = ""
        var ipfsPage = ""
        for(var j=0;j<links.length;j++){
            var u2 = links[j].url
            if(/\/ipfs\/[A-Za-z0-9]/.test(u2)){ if(direct === "") direct = u2; continue }
            if(/\/ipfs_downloads\//.test(u2)){ if(ipfsPage === "") ipfsPage = u2; continue }
            if(/libgen\.[a-z]+\/ads\.php\?md5=/i.test(u2)){ if(ads === "") ads = u2; continue }
            if(/\.(epub|pdf)(\?|$)/i.test(u2) || /\/get\.php\?/i.test(u2)){ if(direct === "") direct = u2; continue }
        }
        if(direct !== ""){
            var ref = store.aaRecordUrl
            store.startDownload(b, direct, store.aaDownloadExt(b, direct), ref)
            return
        }
        if(ipfsPage !== ""){
            store.aaFetchUrl(ipfsPage, "ipfs")
            return
        }
        if(ads !== ""){ store.aaLibgen(ads); return }
        store.aaLibgen("https://libgen.li/ads.php?md5=" + b.aaMd5)
    }
    function aaHandleIpfs(body){
        var b = store.aaBook
        if(!b){ store.failCurrent("Download resolver lost the book"); return }
        var raw = body.match(/https:\/\/[^"'\s<>]+\/ipfs\/[A-Za-z0-9]+[^"'\s<>]*/g) || []
        var urls = []
        for(var i=0;i<raw.length;i++){
            var u = raw[i].replace(/&amp;/g, "&")
            if(urls.indexOf(u) === -1) urls.push(u)
        }
        if(!urls.length){ store.aaLibgen("https://libgen.li/ads.php?md5=" + b.aaMd5); return }
        var pref = ["ipfs.io", "dweb.link", "cloudflare-ipfs.com", "4everland.io", "ipfs.filebase.io", "gateway.pinata.cloud"]
        var best = urls[0]
        var bestRank = 99
        for(var j=0;j<urls.length;j++){
            var rank = 50
            for(var p=0;p<pref.length;p++) if(urls[j].indexOf(pref[p]) !== -1){ rank = p; break }
            if(rank < bestRank){ bestRank = rank; best = urls[j] }
        }
        store.startDownload(b, best, store.aaDownloadExt(b, best), store.aaPendingUrl)
    }
    function aaLibgen(adsUrl){
        var b = store.aaBook
        if(!b){ store.failCurrent("Download resolver lost the book"); return }
        store.aaPendingUrl = adsUrl
        store.aaRetryKind = "record"
        aaLibgenProc.adsUrl = adsUrl
        aaLibgenProc.command = ["sh","-c",
            "curl -sSL -m 30 -A 'Mozilla/5.0 (X11; Linux x86_64; rv:146.0) Gecko/20100101 Firefox/146.0' -e 'https://libgen.li/' " +
            store.shQuote(adsUrl) + " 2>/dev/null"]
        aaLibgenProc.running = true
    }
    Process {
        id: aaFastProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var b = store.aaBook
                var d = null
                try { d = JSON.parse(text) } catch(e) {}
                if(b && d && d.download_url){
                    store.startDownload(b, d.download_url, (b.aaExt || "epub").toLowerCase() === "pdf" ? "pdf" : "epub")
                    return
                }
                store.aaFetchRecord()
            }
        }
    }
    Process {
        id: aaPageProc
        property int reqSeq: 0
        property string purpose: "record"
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                if(aaPageProc.reqSeq !== store.aaPageSeq) return
                var raw = text || ""
                var cut = raw.lastIndexOf("__AAF:")
                var mark = cut === -1 ? "" : raw.substring(cut).split("\n")[0].trim()
                var body = cut === -1 ? raw : raw.substring(0, cut)
                if(mark.indexOf("__AAF:OK") === 0){
                    if(aaPageProc.purpose === "ipfs") store.aaHandleIpfs(body)
                    else store.aaHandleRecord(body)
                    return
                }
                if(mark.indexOf("__AAF:STALE") === 0 || mark.indexOf("__AAF:CHALLENGE") === 0){
                    store.aaStartRefresh(aaPageProc.purpose)
                    return
                }
                store.failCurrent("Annas Archive didn't return the book page")
            }
        }
    }
    Process {
        id: aaLibgenProc
        property string adsUrl: ""
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var b = store.aaBook
                if(!b){ store.failCurrent("Download resolver lost the book"); return }
                var m = (text || "").match(/(?:https?:\/\/[^"'\s<>]+)?\/?get\.php\?[^"'\s<>]+/)
                if(!m){ store.failCurrent("No direct file for this record — try another edition"); return }
                var u = m[0].replace(/&amp;/g, "&")
                if(u.indexOf("http") !== 0){
                    var origin = aaLibgenProc.adsUrl.replace(/^(https?:\/\/[^\/]+).*$/, "$1")
                    u = origin + "/" + u.replace(/^\//, "")
                }
                store.startDownload(b, u, store.aaDownloadExt(b, u), aaLibgenProc.adsUrl)
            }
        }
    }

    function failCurrent(msg){
        store.aaRefreshing = false
        if(aaRefreshTimer) aaRefreshTimer.stop()
        var b = store.dlCurrentMeta
        if(b) store.dlSet(b.key, 0, "failed")
        store.notice = msg
        store.dlCurrentKey = ""
        store.dlCurrentMeta = null
        store.iaBook = null
        store.aaBook = null
        store.dlPath = ""
        store.dlTmp = ""
        store.dlTotal = 0
        store.pumpQueue()
    }
    function startDownload(b, url, ext, referer){
        var fn = store.safeFilename(b.author, b.title, ext)
        var dir = store.shQuote(store.booksDir)
        var out = store.shQuote(store.booksDir + "/" + fn)
        var ref = referer ? (" -e " + store.shQuote(referer)) : ""
        var ua = referer ? store.aaUA : "bookshelf/1.0"
        var script = [
            "mkdir -p " + dir,
            "out=" + out,
            "ext=" + store.shQuote(ext),
            "base=${out%.*}",
            "n=1",
            "while [ -e \"$out\" ]; do out=\"${base} (${n}).${ext}\"; n=$((n+1)); done",
            "tmp=\"$out.part\"",
            "rm -f \"$tmp\"",
            "curl -fL --retry 2 --connect-timeout 15 -m 600 -A " + store.shQuote(ua) + ref + " " + store.shQuote(url) + " -o \"$tmp\" 2>&1 || { rm -f \"$tmp\"; echo BOOK_FAIL; exit 1; }",
            "mime=$(file -b --mime-type \"$tmp\")",
            "magic=$(head -c 4 \"$tmp\")",
            "case \"$ext:$mime:$magic\" in",
            "  epub:application/epub+zip:*|epub:application/zip:*|epub:application/octet-stream:PK*) ;;",
            "  pdf:application/pdf:*|pdf:application/octet-stream:%PDF*) ;;",
            "  *) rm -f \"$tmp\"; echo BOOK_FAIL; exit 1 ;;",
            "esac",
            "mv \"$tmp\" \"$out\"",
            "echo BOOK_PATH:$out"
        ].join("\n")
        store.dlSet(b.key, 0, "downloading")
        store.dlPath = store.booksDir + "/" + fn
        store.dlTmp = store.dlPath + ".part"
        store.dlTotal = 0
        dlProc.command = ["sh","-c",script]
        dlProc.running = true
        headProc.pendingKey = b.key
        headProc.command = ["sh","-c","curl -sIL -m 20 -A " + store.shQuote(ua) + ref + " " + store.shQuote(url) + " 2>/dev/null | grep -i '^content-length:' | tail -1 | tr -dc '0-9'"]
        headProc.running = true
        pollTimer.restart()
    }
    Process {
        id: iaProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var b = store.iaBook
                if(!b){ store.failCurrent("Download resolver lost the book"); return }
                var d = null
                try { d = JSON.parse(text) } catch(e) {}
                var files = d && d.files ? d.files : []
                var epub = ""
                var pdf = ""
                for(var i=0;i<files.length;i++){
                    var n = files[i].name || ""
                    var low = n.toLowerCase()
                    if(!epub && /\.epub$/i.test(n) && low.indexOf("_encrypted") === -1 && low.indexOf("_lcp") === -1) epub = n
                    if(!pdf && /\.pdf$/i.test(n) && low.indexOf("_encrypted") === -1 && low.indexOf("_lcp") === -1 && low.indexOf("_text.pdf") === -1) pdf = n
                }
                var name = epub || pdf
                if(!name){ store.failCurrent("No downloadable file for “" + (b.title || "this book") + "” — try Borrow"); return }
                var ext = epub ? "epub" : "pdf"
                var segs = name.split("/")
                for(var s=0;s<segs.length;s++) segs[s] = encodeURIComponent(segs[s])
                var url = "https://archive.org/download/" + encodeURIComponent(b.iaId) + "/" + segs.join("/")
                store.startDownload(b, url, ext)
            }
        }
    }
    Process {
        id: headProc
        property string pendingKey: ""
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                if(headProc.pendingKey !== store.dlCurrentKey) return
                var n = parseInt(text.replace(/[^0-9]/g, "")) || 0
                store.dlTotal = n
            }
        }
    }
    Timer {
        id: pollTimer
        interval: 400
        repeat: true
        onTriggered: {
            if(store.dlCurrentKey === ""){ pollTimer.stop(); return }
            if(store.dlTotal > 0){
                szProc.command = ["sh","-c","stat -c%s " + store.shQuote(store.dlTmp) + " 2>/dev/null || echo 0"]
                szProc.running = true
            }
        }
    }
    Process {
        id: szProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                if(store.dlCurrentKey === "" || store.dlTotal <= 0) return
                var got = parseInt(text.trim()) || 0
                store.dlSet(store.dlCurrentKey, Math.min(100, Math.round(got / store.dlTotal * 100)), "downloading")
            }
        }
    }
    Process {
        id: dlProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                pollTimer.stop()
                var b = store.dlCurrentMeta
                var path = ""
                var lines = text.split("\n")
                for(var i=0;i<lines.length;i++){
                    var p = lines[i].trim()
                    if(p.indexOf("BOOK_PATH:") === 0) path = p.slice(10)
                }
                if(b && path !== ""){
                    var s = Object.assign({}, store.downloaded)
                    s[b.key] = path
                    store.downloaded = s
                    store.dlSet(b.key, 100, "done")
                    store.notice = "Saved to ~/Books"
                    var ext = path.split(".").pop().toLowerCase()
                    store.bookDownloaded({
                        path: path,
                        title: b.title || "",
                        author: b.author || "",
                        source: b.source || "",
                        sourceId: b.key || "",
                        cover: b.cover || "",
                        format: ext,
                        year: b.year || "",
                        detailsUrl: b.detailsUrl || ""
                    })
                } else {
                    if(b) store.dlSet(b.key, 0, "failed")
                    store.notice = "Download failed — click Retry"
                }
                store.dlCurrentKey = ""
                store.dlCurrentMeta = null
                store.iaBook = null
                store.aaBook = null
                store.dlPath = ""
                store.dlTmp = ""
                store.dlTotal = 0
                store.pumpQueue()
            }
        }
    }
    function safeFilename(a, t, ext){
        var s = String(a || "").replace(/[\/\\:*?"<>|]/g, "").replace(/\s+/g, " ").trim()
        var n = String(t || "").replace(/[\/\\:*?"<>|]/g, "").replace(/\s+/g, " ").trim()
        var out = s !== "" ? (s + " - " + n) : n
        out = out.replace(/[^A-Za-z0-9 _.,'()&!-]/g, "").replace(/\s+/g, " ").trim().slice(0, 120)
        if(out === "") out = "book"
        return out + "." + ext
    }

    // ── keyboard ───────────────────────────────────────────────────────
    function handleKey(e){
        if(search.activeFocus) return false
        if(e.key === Qt.Key_Slash){ search.forceActiveFocus(); return true }
        if(e.key === Qt.Key_S){ store.shuffle(); return true }
        if(e.key === Qt.Key_D || e.key === Qt.Key_Return || e.key === Qt.Key_Enter){
            store.actionFor(store.selBook)
            return true
        }
        if(e.key === Qt.Key_Right){
            store.gridIndex = Math.min(store.results.length - 1, store.gridIndex + 1)
            grid.positionViewAtIndex(store.gridIndex, GridView.Visible)
            return true
        }
        if(e.key === Qt.Key_Left){
            store.gridIndex = Math.max(0, store.gridIndex - 1)
            grid.positionViewAtIndex(store.gridIndex, GridView.Visible)
            return true
        }
        return false
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        // search + shuffle
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                radius: 9
                color: colors.alpha(colors.surface, 0.85)
                border.width: 1
                border.color: search.activeFocus ? colors.alpha(colors.primary, 0.5) : colors.alpha(colors.outline, 0.14)
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 8
                    spacing: 6
                    Text { text: "󰍉"; color: colors.alpha(colors.outline, 0.6); font.family: colors.fontSans; font.pixelSize: 11 }
                    TextField {
                        id: search
                        Layout.fillWidth: true
                        placeholderText: "Search books… or scroll the random shelf"
                        placeholderTextColor: colors.alpha(colors.outline, 0.45)
                        color: colors.foreground
                        font.family: colors.fontSans
                        font.pixelSize: 10
                        background: null
                        selectByMouse: true
                        onTextChanged: {
                            store.query = text
                            if(text.length === 0){ searchDeb.stop(); store.startSearch(true) }
                            else searchDeb.restart()
                        }
                        onAccepted: grid.forceActiveFocus()
                        Keys.onEscapePressed: function(event){
                            text = ""
                            store.query = ""
                            grid.forceActiveFocus()
                            event.accepted = true
                        }
                    }
                }
            }
            Rectangle {
                width: 82
                height: 34
                radius: 9
                color: shuffleMa.containsMouse ? colors.alpha(colors.primary, 0.22) : colors.alpha(colors.surface, 0.6)
                border.width: 1
                border.color: colors.alpha(colors.primary, 0.3)
                Text { anchors.centerIn: parent; text: "Shuffle"; color: colors.primary; font.family: colors.fontSans; font.pixelSize: 9; font.weight: Font.Bold }
                MouseArea { id: shuffleMa; anchors.fill: parent; hoverEnabled: true; onClicked: store.shuffle() }
            }
        }
        Timer { id: searchDeb; interval: 450; onTriggered: store.startSearch(true) }

        // source chips + status
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: store.sourceChips
                Rectangle {
                    width: sourceTxt.implicitWidth + 18
                    height: 25
                    radius: 12
                    color: store.source === modelData.k ? colors.alpha(colors.primary, 0.2) : (chipMa.containsMouse ? colors.alpha(colors.surfaceVariant, 0.5) : colors.alpha(colors.surface, 0.5))
                    border.width: 1
                    border.color: store.source === modelData.k ? colors.alpha(colors.primary, 0.45) : colors.alpha(colors.outline, 0.12)
                    Text { id: sourceTxt; anchors.centerIn: parent; text: modelData.t; color: store.source === modelData.k ? colors.primary : colors.foreground; font.family: colors.fontSans; font.pixelSize: 7; font.weight: Font.Bold; font.letterSpacing: 0.5 }
                    MouseArea { id: chipMa; anchors.fill: parent; hoverEnabled: true; onClicked: { store.source = modelData.k; store.startSearch(true) } }
                }
            }
            Item { Layout.fillWidth: true }
            Text {
                text: store.aaRefreshing ? "refreshing annas shield…" : (store.loading ? "searching…" : (store.notice !== "" ? store.notice : (store.results.length + " books")))
                color: (store.aaRefreshing || store.notice !== "") ? colors.alpha(colors.primary, 0.8) : colors.alpha(colors.outline, 0.6)
                font.family: colors.fontSans
                font.pixelSize: 8
            }
        }

        // annas archive key row — optional; only the member download API uses it
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            visible: store.source === "annasarchive"
            radius: 9
            color: colors.alpha(colors.surface, 0.55)
            border.width: 1
            border.color: colors.alpha(colors.outline, 0.12)
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 8
                spacing: 8
                Text { text: "󰋻"; color: colors.alpha(colors.outline, 0.6); font.family: colors.fontSans; font.pixelSize: 10 }
                Text { text: "Secret key"; color: colors.alpha(colors.outline, 0.7); font.family: colors.fontSans; font.pixelSize: 8; font.weight: Font.Bold }
                TextField {
                    id: aaKeyField
                    Layout.fillWidth: true
                    echoMode: TextInput.Password
                    placeholderText: "optional — used only by the member download API"
                    placeholderTextColor: colors.alpha(colors.outline, 0.45)
                    color: colors.foreground
                    font.family: colors.fontSans
                    font.pixelSize: 9
                    background: null
                    selectByMouse: true
                    onEditingFinished: store.aaKey = text
                    Keys.onReturnPressed: { store.aaKey = text; store.aaSaveKey(); aaKeyField.focus = false }
                }
                Rectangle {
                    width: aaSaveTxt.implicitWidth + 16; height: 22; radius: 11
                    color: aaSaveMa.containsMouse ? colors.alpha(colors.primary, 0.3) : colors.alpha(colors.primary, 0.16)
                    border.width: 1; border.color: colors.alpha(colors.primary, 0.4)
                    Text { id: aaSaveTxt; anchors.centerIn: parent; text: "Save + connect"; color: colors.primary; font.family: colors.fontSans; font.pixelSize: 8; font.weight: Font.Bold }
                    MouseArea { id: aaSaveMa; anchors.fill: parent; hoverEnabled: true; onClicked: { store.aaKey = aaKeyField.text; store.aaSaveKey() } }
                }
                Text {
                    text: store.aaLoggedIn ? "connected" : (store.aaKey === "" ? "no key yet" : "key saved")
                    color: store.aaLoggedIn ? colors.alpha(colors.primary, 0.9) : colors.alpha(colors.outline, 0.5)
                    font.family: colors.fontSans; font.pixelSize: 7
                }
            }
        }

        // cover grid
        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            cacheBuffer: 320
            cellWidth: Math.max(118, Math.floor(width / Math.max(4, Math.floor(width / 132))))
            cellHeight: Math.floor(cellWidth * 1.46) + 42
            model: store.results
            currentIndex: 0
            keyNavigationWraps: true
            onCurrentIndexChanged: store.gridIndex = currentIndex
            onContentYChanged: { if(store.active && !store.loading && contentY + height > contentHeight - 420) store.loadMore() }
            onCountChanged: if(count && currentIndex < 0) currentIndex = 0
            Keys.onPressed: function(e){
                if(e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_D){
                    store.actionFor(store.selBook)
                    e.accepted = true
                } else if(e.key === Qt.Key_S){
                    store.shuffle()
                    e.accepted = true
                } else if(e.key === Qt.Key_Slash){
                    search.forceActiveFocus()
                    e.accepted = true
                }
            }
            delegate: Rectangle {
                id: card
                width: GridView.view.cellWidth - 10
                height: GridView.view.cellHeight - 8
                radius: 10
                color: hover.containsMouse ? colors.alpha(colors.primary, 0.1) : colors.alpha(colors.surface, 0.45)
                border.width: GridView.view.currentIndex === index ? 2 : 1
                border.color: GridView.view.currentIndex === index ? colors.alpha(colors.primary, 0.65) : colors.alpha(colors.outline, 0.11)
                scale: hover.containsMouse ? 1.035 : 1.0
                // GridView owns each delegate's y. Animate a visual-only
                // transform instead of binding y, or hovering makes cards
                // fight the layout and jump upward.
                transform: Translate {
                    y: hover.containsMouse ? -2 : 0
                    Behavior on y { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                }
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 5
                    spacing: 4
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 7
                        color: colors.alpha(colors.background, 0.6)
                        clip: true
                        Text {
                            anchors.centerIn: parent
                            visible: coverImg.status !== Image.Ready
                            text: String(modelData.title || "?").charAt(0).toUpperCase()
                            color: colors.alpha(colors.outline, 0.45)
                            font.family: colors.fontSans
                            font.pixelSize: 26
                            font.weight: Font.ExtraBold
                        }
                        Image {
                            id: coverImg
                            anchors.fill: parent
                            source: modelData.cover || ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            sourceSize: Qt.size(260, 380)
                            visible: status === Image.Ready
                        }
                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.margins: 5
                            width: srcTxt.implicitWidth + 8
                            height: 15
                            radius: 7
                            color: colors.alpha(colors.background, 0.78)
                            Text { id: srcTxt; anchors.centerIn: parent; text: modelData.sourceKey === "openlibrary" ? "OL" : (modelData.sourceKey === "annasarchive" ? "AA" : (modelData.sourceKey === "standardebooks" ? "SE" : "PG")); color: colors.foreground; font.family: colors.fontSans; font.pixelSize: 6; font.weight: Font.Bold }
                        }
                        Rectangle {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 5
                            width: 19
                            height: 19
                            radius: 10
                            visible: store.isDownloaded(modelData.key)
                            color: colors.alpha(colors.primary, 0.92)
                            Text { anchors.centerIn: parent; text: ""; color: colors.background; font.family: colors.fontSans; font.pixelSize: 9; font.weight: Font.ExtraBold }
                        }
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 30
                            visible: !!store.dlFor(modelData.key).status
                            color: colors.alpha(colors.background, 0.84)
                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.margins: 3
                                radius: 6
                                width: Math.max(0, (parent.width - 6) * (store.dlFor(modelData.key).pct || 0) / 100)
                                color: colors.alpha(colors.primary, 0.65)
                            }
                            Text {
                                anchors.centerIn: parent
                                text: (function(){
                                    var d = store.dlFor(modelData.key)
                                    if(d.status === "queued") return "queued"
                                    if(d.status === "resolving") return "finding file…"
                                    if(d.status === "failed") return "failed — retry"
                                    if(d.status === "done") return "saved"
                                    return store.dlTotal > 0 ? (Math.round(d.pct || 0) + "%  ↓") : "↓"
                                })()
                                color: colors.foreground
                                font.family: colors.fontSans
                                font.pixelSize: 7
                                font.weight: Font.Bold
                            }
                        }
                    }
                    Text { Layout.fillWidth: true; text: modelData.title; color: colors.foreground; font.family: colors.fontSans; font.pixelSize: 8; font.weight: Font.ExtraBold; elide: Text.ElideRight; maximumLineCount: 1 }
                    Text { Layout.fillWidth: true; text: (modelData.author || "Unknown") + (modelData.year ? "  •  " + modelData.year : ""); color: colors.alpha(colors.outline, 0.65); font.family: colors.fontSans; font.pixelSize: 7; elide: Text.ElideRight; maximumLineCount: 1 }
                }
                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: { grid.currentIndex = index; store.gridIndex = index }
                    onDoubleClicked: store.actionFor(modelData)
                }
            }
            Text {
                visible: !store.loading && store.results.length === 0
                anchors.centerIn: parent
                text: store.notice !== "" ? store.notice : "no books — try another search"
                color: colors.alpha(colors.outline, 0.5)
                font.family: colors.fontSans
                font.pixelSize: 9
            }
        }

        // selected book bar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            radius: 10
            color: colors.alpha(colors.surface, 0.6)
            border.width: 1
            border.color: colors.alpha(colors.outline, 0.12)
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 8
                spacing: 8
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text { Layout.fillWidth: true; text: store.selBook ? store.selBook.title : "—"; color: colors.foreground; font.family: colors.fontSans; font.pixelSize: 9; font.weight: Font.Bold; elide: Text.ElideRight }
                    Text { Layout.fillWidth: true; text: store.selBook ? ((store.selBook.author || "Unknown") + "  •  " + store.fmtFormats(store.selBook) + (store.selBook.source ? "  •  " + store.selBook.source : "")) : "scroll the shelf, double-click a cover to download"; color: colors.alpha(colors.outline, 0.65); font.family: colors.fontSans; font.pixelSize: 8; elide: Text.ElideRight }
                }
                Rectangle {
                    width: 34
                    height: 26
                    radius: 8
                    visible: !!store.selBook
                    color: detMa.containsMouse ? colors.alpha(colors.primary, 0.22) : "transparent"
                    Text { anchors.centerIn: parent; text: "󰋼"; color: colors.foreground; font.family: colors.fontSans; font.pixelSize: 11 }
                    MouseArea { id: detMa; anchors.fill: parent; hoverEnabled: true; onClicked: store.openDetails(store.selBook) }
                }
                Rectangle {
                    width: 92
                    height: 26
                    radius: 13
                    color: actMa.containsMouse ? colors.primary : colors.alpha(colors.primary, 0.18)
                    border.width: 1
                    border.color: colors.alpha(colors.primary, 0.4)
                    Text { anchors.centerIn: parent; text: store.actionLabel(store.selBook); color: actMa.containsMouse ? colors.background : colors.primary; font.family: colors.fontSans; font.pixelSize: 9; font.weight: Font.Bold }
                    MouseArea { id: actMa; anchors.fill: parent; hoverEnabled: true; onClicked: store.actionFor(store.selBook) }
                }
            }
        }

    }
}
