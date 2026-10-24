import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

// Keybinds — static, no dynamic loading, just text. Enter executes.
PanelWindow {
    id: root
    property var colors
    property bool open: false
    property string filter: ""

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: root.open || closeAnim.running
    focusable: true
    // NOTE: no IpcHandler here — Bar.qml owns target "keybinds" and lazy-loads this.

    onOpenChanged: {
        if (open) { filter=""; searchField.text=""; searchField.forceActiveFocus(); list.currentIndex = firstRowIndex(); openAnim.restart() }
        else closeAnim.restart()
    }

    property var binds: [
        {key:"SUPER + Return", desc:"Terminal", cat:"Apps", disp:"exec", arg:"omarchy-launch-terminal"},
        {key:"SUPER + Space", desc:"Launch apps", cat:"Apps", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call launcher toggle"},
        {key:"SUPER Shift + B", desc:"Browser", cat:"Apps", disp:"exec", arg:"uwsm-app -- zen"},
        {key:"SUPER Alt Shift + B", desc:"Browser (private)", cat:"Apps", disp:"exec", arg:"uwsm-app -- zen --private-window"},
        {key:"SUPER Shift + N", desc:"Editor (Zed)", cat:"Apps", disp:"exec", arg:"uwsm-app -- zed"},
        {key:"SUPER Shift + M", desc:"Music (Spotify)", cat:"Apps", disp:"exec", arg:"uwsm-app -- music"},
        {key:"SUPER Shift + O", desc:"Obsidian", cat:"Apps", disp:"exec", arg:"uwsm-app -- obsidian -disable-gpu --enable-wayland-ime"},
        // Web apps — chromeless via zenapp; focus the same window as the
        // app-menu rows. These replaced Omarchy's chromium --app binds.
        {key:"SUPER Shift + A", desc:"ChatGPT", cat:"Apps", disp:"exec", arg:"zenapp chatgpt https://chatgpt.com ChatGPT"},
        {key:"SUPER Alt Shift + A", desc:"Grok", cat:"Apps", disp:"exec", arg:"zenapp grok https://grok.com Grok"},
        {key:"SUPER Shift + C", desc:"Calendar", cat:"Apps", disp:"exec", arg:"zenapp heycal https://app.hey.com/calendar/weeks/ Calendar"},
        {key:"SUPER Shift + E", desc:"Email", cat:"Apps", disp:"exec", arg:"zenapp heymail https://hey.com \"IMBOX|HEY\""},
        {key:"SUPER Shift + Y", desc:"YouTube", cat:"Apps", disp:"exec", arg:"zenapp youtube https://youtube.com/ YouTube"},
        {key:"SUPER Ctrl Shift + G", desc:"Google Messages", cat:"Apps", disp:"exec", arg:"zenapp gmessages https://messages.google.com/web/conversations Messages"},
        {key:"SUPER Shift + P", desc:"Google Photos", cat:"Apps", disp:"exec", arg:"zenapp gphotos https://photos.google.com/ \"Google Photos\""},
        {key:"SUPER Shift + X", desc:"X", cat:"Apps", disp:"exec", arg:"zenapp x https://x.com/ \"/ X\""},
        {key:"SUPER Alt Shift + X", desc:"X Post", cat:"Apps", disp:"exec", arg:"zenapp x https://x.com/compose/post \"/ X\""},
        {key:"SUPER + H", desc:"WiFi manager", cat:"System", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call wifi toggle"},
        {key:"SUPER + U", desc:"System monitor", cat:"System", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call sysmon toggle"},
        {key:"SUPER + K", desc:"Show key bindings", cat:"System", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call keybinds toggle"},
        {key:"SUPER Ctrl + K", desc:"Herdr keybindings", cat:"System", disp:"exec", arg:"uwsm-app -- herdr-keys"},
        {key:"SUPER Alt + K", desc:"Tmux keybindings", cat:"System", disp:"exec", arg:"uwsm-app -- tmux-keys"},
        {key:"SUPER + N", desc:"System info", cat:"System", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call fastfetch toggle"},
        {key:"SUPER Alt + C", desc:"Pomodoro timer", cat:"System", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call pomodoro toggle"},
        {key:"SUPER + E", desc:"Theme selector", cat:"System", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call theme toggle"},
        {key:"SUPER Ctrl + V", desc:"Clipboard manager", cat:"System", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call clipboard toggle"},
        {key:"SUPER Ctrl + E", desc:"Emoji picker", cat:"System", disp:"exec", arg:"uwsm-app -- ~/.config/rofi/emoji.sh"},
        {key:"SUPER Alt + B", desc:"Battery", cat:"System", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call battery toggle"},
        {key:"SUPER Ctrl + B", desc:"Bluetooth panel", cat:"System", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call bluetooth toggle"},
        {key:"SUPER Ctrl + D", desc:"Display panel", cat:"System", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call monitors toggle"},
        {key:"SUPER Ctrl + W", desc:"Wi-Fi panel", cat:"System", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call wifi toggle"},
        {key:"SUPER Ctrl + Alt + D", desc:"Calendar (clock)", cat:"System", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call clockwin toggle"},
        {key:"SUPER Alt + L", desc:"Lyrics", cat:"System", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call lyrics toggle"},
        {key:"SUPER Alt + E", desc:"Earbuds", cat:"System", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call earbuds toggle"},
        {key:"SUPER + Esc", desc:"Power menu", cat:"System", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call power toggle"},
        {key:"SUPER Ctrl + P", desc:"Power menu (alt chord)", cat:"System", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call power toggle"},
        {key:"Power button", desc:"Power menu (physical button)", cat:"System", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call power toggle"},
        {key:"SUPER Shift + Q", desc:"Shut down", cat:"System", disp:"exec", arg:"systemctl poweroff"},
        {key:"SUPER Alt + P", desc:"Control center", cat:"System", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call controlcenter toggle"},
        {key:"SUPER + I", desc:"Package manager", cat:"System", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call pkgman toggle"},
        {key:"SUPER Ctrl + Space", desc:"Wallpaper store", cat:"System", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call wallshelf toggle"},
        {key:"SUPER Alt + N", desc:"PDF library", cat:"System", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call pdfviewer toggle"},
        {key:"SUPER Shift + Space", desc:"Toggle bar sides", cat:"System", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call bar toggle"},
        {key:"SUPER Alt + Space", desc:"Island style", cat:"System", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call bar toggleIsland"},
        {key:"SUPER Alt + T", desc:"Screen time", cat:"System", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call screentime toggle"},
        {key:"SUPER Alt + D", desc:"Hardware health", cat:"System", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call drives toggle"},
        {key:"SUPER + ,", desc:"Notification center", cat:"System", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call notifications toggle"},
        {key:"SUPER Shift + ,", desc:"Do not disturb", cat:"System", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call notifications toggleDnd"},
        {key:"SUPER Ctrl + ,", desc:"Do not disturb (alt chord)", cat:"System", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call notifications toggleDnd"},
        {key:"SUPER + R", desc:"Screen record toggle", cat:"System", disp:"exec", arg:"uwsm-app -- record"},
        {key:"SUPER Ctrl + T", desc:"System activity (btop)", cat:"System", disp:"exec", arg:"omarchy-launch-tui btop"},
        {key:"SUPER Ctrl + J", desc:"Pin clipboard to sticky shelf", cat:"System", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call sticky pin"},
        {key:"SUPER Alt + H", desc:"Theme editor", cat:"System", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call themeedit toggle"},
        {key:"SUPER Shift + S", desc:"Pretty screenshot", cat:"System", disp:"exec", arg:"shot pretty"},
        {key:"SUPER Shift + D", desc:"Screenshot (drag area)", cat:"System", disp:"exec", arg:"shot"},
        {key:"SUPER Shift + F", desc:"Full screenshot", cat:"System", disp:"exec", arg:"shot full"},
        {key:"SUPER Ctrl + C", desc:"Capture menu (all tools)", cat:"System", disp:"exec", arg:"uwsm-app -- capture-menu"},
        {key:"SUPER Alt + Y", desc:"WatchCat (data watchdog)", cat:"System", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call watchcat toggle"},
        {key:"SUPER Shift + H", desc:"Hornet pet (on/off)", cat:"System", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call pet toggle"},
        {key:"SUPER Shift + T", desc:"OCR from screenshot", cat:"System", disp:"exec", arg:"shot ocr"},
        {key:"SUPER Alt + O", desc:"Workspace manager", cat:"System", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call wsview toggle"},
        {key:"SUPER + Home", desc:"Restart shell", cat:"System", disp:"exec", arg:"hyprctl reload >/dev/null 2>&1; pkill -x quickshell; sleep 0.3; setsid quickshell -p ~/.config/quickshell >/dev/null 2>&1 &"},
        {key:"Volume Up", desc:"Volume up", cat:"System", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call media volup"},
        {key:"Volume Down", desc:"Volume down", cat:"System", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call media voldown"},
        {key:"Mute", desc:"Mute toggle", cat:"System", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call media volmute"},
        {key:"Mic Mute", desc:"Mic mute toggle", cat:"System", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call media micmute"},
        {key:"Brightness Up", desc:"Brightness up", cat:"System", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call media briup"},
        {key:"Brightness Down", desc:"Brightness down", cat:"System", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call media bridown"},
        {key:"Shift + Brightness Up", desc:"Brightness maximum", cat:"System", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call media brimax"},
        {key:"Shift + Brightness Down", desc:"Brightness minimum", cat:"System", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call media brimin"},
        {key:"Alt + Volume Up", desc:"Volume up (precise)", cat:"System", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call media volup"},
        {key:"Alt + Volume Down", desc:"Volume down (precise)", cat:"System", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call media voldown"},
        {key:"SUPER + W", desc:"Close window", cat:"Windows", disp:"killactive", arg:""},
        {key:"SUPER + T", desc:"Float / tile window", cat:"Windows", disp:"togglefloating", arg:""},
        {key:"SUPER + F", desc:"Full screen", cat:"Windows", disp:"fullscreen", arg:"0"},
        {key:"SUPER Alt + S", desc:"Minimize window to scratchpad", cat:"Windows", disp:"movetoworkspacesilent", arg:"special:scratchpad"},
        {key:"SUPER + S", desc:"Toggle scratchpad", cat:"Windows", disp:"togglespecialworkspace", arg:"scratchpad"},
        {key:"SUPER + Left", desc:"Focus left", cat:"Windows", disp:"movefocus", arg:"l"},
        {key:"SUPER + Right", desc:"Focus right", cat:"Windows", disp:"movefocus", arg:"r"},
        {key:"SUPER + Up", desc:"Focus up", cat:"Windows", disp:"movefocus", arg:"u"},
        {key:"SUPER + Down", desc:"Focus down", cat:"Windows", disp:"movefocus", arg:"d"},
        {key:"SUPER Shift + Left", desc:"Swap window left", cat:"Windows", disp:"swapwindow", arg:"l"},
        {key:"SUPER Shift + Right", desc:"Swap window right", cat:"Windows", disp:"swapwindow", arg:"r"},
        {key:"SUPER Shift + Up", desc:"Swap window up", cat:"Windows", disp:"swapwindow", arg:"u"},
        {key:"SUPER Shift + Down", desc:"Swap window down", cat:"Windows", disp:"swapwindow", arg:"d"},
        {key:"SUPER + L", desc:"Lock screen", cat:"Windows", disp:"exec", arg:"pidof hyprlock || hyprlock"},
        {key:"SUPER + 1", desc:"Workspace 1", cat:"Workspaces", disp:"workspace", arg:"1"},
        {key:"SUPER + 2", desc:"Workspace 2", cat:"Workspaces", disp:"workspace", arg:"2"},
        {key:"SUPER + 3", desc:"Workspace 3", cat:"Workspaces", disp:"workspace", arg:"3"},
        {key:"SUPER + 4", desc:"Workspace 4", cat:"Workspaces", disp:"workspace", arg:"4"},
        {key:"SUPER + 5", desc:"Workspace 5", cat:"Workspaces", disp:"workspace", arg:"5"},
        {key:"SUPER + 6", desc:"Workspace 6", cat:"Workspaces", disp:"workspace", arg:"6"},
        {key:"SUPER + 7", desc:"Workspace 7", cat:"Workspaces", disp:"workspace", arg:"7"},
        {key:"SUPER + 8", desc:"Workspace 8", cat:"Workspaces", disp:"workspace", arg:"8"},
        {key:"SUPER + 9", desc:"Workspace 9", cat:"Workspaces", disp:"workspace", arg:"9"},
        {key:"SUPER + 10", desc:"Workspace 10", cat:"Workspaces", disp:"workspace", arg:"10"},
        {key:"SUPER Shift + 1", desc:"Move to workspace 1", cat:"Workspaces", disp:"movetoworkspace", arg:"1"},
        {key:"SUPER Shift + 2", desc:"Move to workspace 2", cat:"Workspaces", disp:"movetoworkspace", arg:"2"},
        {key:"SUPER Shift + 3", desc:"Move to workspace 3", cat:"Workspaces", disp:"movetoworkspace", arg:"3"},
        {key:"SUPER Shift + 4", desc:"Move to workspace 4", cat:"Workspaces", disp:"movetoworkspace", arg:"4"},
        {key:"SUPER Shift + 5", desc:"Move to workspace 5", cat:"Workspaces", disp:"movetoworkspace", arg:"5"},
        {key:"SUPER Shift + 6", desc:"Move to workspace 6", cat:"Workspaces", disp:"movetoworkspace", arg:"6"},
        {key:"SUPER Shift + 7", desc:"Move to workspace 7", cat:"Workspaces", disp:"movetoworkspace", arg:"7"},
        {key:"SUPER Shift + 8", desc:"Move to workspace 8", cat:"Workspaces", disp:"movetoworkspace", arg:"8"},
        {key:"SUPER Shift + 9", desc:"Move to workspace 9", cat:"Workspaces", disp:"movetoworkspace", arg:"9"},
        {key:"SUPER Shift + 10", desc:"Move to workspace 10", cat:"Workspaces", disp:"movetoworkspace", arg:"10"},
        {key:"SUPER + Tab", desc:"Next workspace", cat:"Workspaces", disp:"workspace", arg:"e+1"},
        {key:"SUPER Shift + Tab", desc:"Prev workspace", cat:"Workspaces", disp:"workspace", arg:"e-1"},
        {key:"Ctrl + T / W / R", desc:"New / close / reload tab", cat:"Zen"},
        {key:"Ctrl + L", desc:"Address bar", cat:"Zen"},
        {key:"Ctrl + H / B", desc:"History / bookmarks sidebar", cat:"Zen"},
        {key:"Ctrl + Alt + Left / Right", desc:"Prev / next workspace", cat:"Zen"},
        {key:"Ctrl + Alt + G / V / H", desc:"Split grid / vertical / horizontal", cat:"Zen"},
        {key:"Ctrl + Alt + U", desc:"Unsplit", cat:"Zen"},
        {key:"Ctrl + S", desc:"Compact mode (auto-hide sidebar)", cat:"Zen"},
        {key:"Ctrl + Alt + S", desc:"Peek sidebar in compact mode", cat:"Zen"},
        {key:"Ctrl + O", desc:"Glance (peek link)", cat:"Zen"},
        {key:"Ctrl + Shift + D", desc:"Pin tab (essential)", cat:"Zen"},
        {key:"Ctrl + T / W / R", desc:"New / close / reload tab", cat:"Firefox"},
        {key:"Ctrl + L", desc:"Address bar", cat:"Firefox"},
        {key:"Ctrl + K", desc:"Search", cat:"Firefox"},
        {key:"Ctrl + F", desc:"Find in page", cat:"Firefox"},
        {key:"Ctrl + H / J", desc:"History / downloads", cat:"Firefox"},
        {key:"Ctrl + B", desc:"Bookmarks sidebar", cat:"Firefox"},
        {key:"Ctrl + D", desc:"Bookmark this page", cat:"Firefox"},
        {key:"Ctrl + Shift + T", desc:"Reopen closed tab", cat:"Firefox"},
        {key:"Space Space", desc:"Find files", cat:"Neovim"},
        {key:"Space /", desc:"Grep project", cat:"Neovim"},
        {key:"Space E", desc:"File explorer", cat:"Neovim"},
        {key:"Space B D", desc:"Delete buffer", cat:"Neovim"},
        {key:"Shift + H / L", desc:"Prev / next buffer", cat:"Neovim"},
        {key:"Ctrl + H / J / K / L", desc:"Move between splits", cat:"Neovim"},
        {key:"Space - / |", desc:"Split below / right", cat:"Neovim"},
        {key:"Space W M", desc:"Zoom split", cat:"Neovim"},
        {key:"Space G G", desc:"Lazygit", cat:"Neovim"},
        {key:"Space Q Q", desc:"Quit all", cat:"Neovim"},
        {key:"Ctrl + P", desc:"Command palette", cat:"Obsidian"},
        {key:"Ctrl + O", desc:"Quick switcher (open note)", cat:"Obsidian"},
        {key:"Ctrl + N", desc:"New note", cat:"Obsidian"},
        {key:"Ctrl + Shift + F", desc:"Search vault", cat:"Obsidian"},
        {key:"Ctrl + E", desc:"Toggle edit / preview", cat:"Obsidian"},
        {key:"Ctrl + F", desc:"Find in note", cat:"Obsidian"},
        {key:"Ctrl + P", desc:"File finder", cat:"Zed"},
        {key:"Ctrl + Shift + P", desc:"Command palette", cat:"Zed"},
        {key:"Ctrl + `", desc:"Terminal", cat:"Zed"},
        {key:"Ctrl + Shift + F", desc:"Project search", cat:"Zed"},
        {key:"Ctrl + ,", desc:"Settings", cat:"Zed"},
        {key:"Ctrl + W", desc:"Close tab", cat:"Zed"},
        {key:"Ctrl + Tab", desc:"Next tab", cat:"Zed"},
        {key:"Ctrl Shift + C / V", desc:"Copy / paste", cat:"foot"},
        {key:"Ctrl / Shift + Insert", desc:"Copy / paste (alternate)", cat:"foot"},
        {key:"Shift + PageUp / PageDown", desc:"Scrollback", cat:"foot"},
        {key:"Ctrl Shift + R", desc:"Search scrollback", cat:"foot"},
        {key:"Ctrl Shift + N", desc:"New window (same directory)", cat:"foot"},
        {key:"Ctrl Shift + O", desc:"Open URL", cat:"foot"},
        {key:"Ctrl + + / - / 0", desc:"Font size", cat:"foot"},
        {key:"Space", desc:"Play / pause", cat:"mpv"},
        {key:"Left / Right", desc:"Seek back / forward", cat:"mpv"},
        {key:"Up / Down", desc:"Long seek", cat:"mpv"},
        {key:"F", desc:"Fullscreen", cat:"mpv"},
        {key:"M", desc:"Mute", cat:"mpv"},
        {key:"9 / 0", desc:"Volume down / up", cat:"mpv"},
        {key:"S", desc:"Screenshot", cat:"mpv"},
        {key:"Wheel / + / -", desc:"Zoom (images)", cat:"mpv"},
        {key:"R", desc:"Reset view (images)", cat:"mpv"},
        {key:"Q", desc:"Quit", cat:"mpv"},
        {key:"Ctrl + T / N", desc:"New tab / window", cat:"Thunar"},
        {key:"Ctrl + L", desc:"Location bar", cat:"Thunar"},
        {key:"Alt + Up", desc:"Parent folder", cat:"Thunar"},
        {key:"Ctrl + H", desc:"Hidden files", cat:"Thunar"},
        {key:"F2", desc:"Rename", cat:"Thunar"},
        {key:"Right-click", desc:"Terminal here / Neovim / Copy path / Wallpaper", cat:"Thunar"},
        {key:"Space", desc:"Play / pause", cat:"Spotify"},
        {key:"Ctrl + Left / Right", desc:"Prev / next track", cat:"Spotify"},
        {key:"Ctrl + Up / Down", desc:"Volume up / down", cat:"Spotify"},
        {key:"?", desc:"Help overlay", cat:"btop"},
        {key:"Q / Esc", desc:"Quit / back", cat:"btop"},
        {key:"Arrows + Enter", desc:"Select process", cat:"btop"},
        {key:"F2", desc:"Setup", cat:"btop"},
        // Stock + repo binds synced from the live config (70 rows, generated
        // 2026-10-17). Chords below were all acting without a row here; every
        // row is executable: exec runs the bind's own command, rawlua replays
        // its Lua dispatcher through hyprctl.
        {key:"ALT + Tab", desc:"Reveal active window on top", cat:"Windows", disp:"rawlua", arg:"hl.dsp.window.bring_to_top()"},
        {key:"CTRL + ALT + Delete", desc:"Close all windows", cat:"Windows", disp:"exec", arg:"omarchy-hyprland-window-close-all"},
        {key:"CTRL + ALT + Tab", desc:"Focus on next monitor", cat:"Workspaces", disp:"rawlua", arg:"hl.dsp.focus({ monitor = \"+1\" })"},
        {key:"Print", desc:"Screenshot", cat:"System", disp:"exec", arg:"omarchy-capture-screenshot"},
        {key:"SHIFT + ALT + Tab", desc:"Reveal active window on top", cat:"Windows", disp:"rawlua", arg:"hl.dsp.window.bring_to_top()"},
        {key:"SHIFT + CTRL + ALT + Tab", desc:"Focus on previous monitor", cat:"Workspaces", disp:"rawlua", arg:"hl.dsp.focus({ monitor = \"-1\" })"},
        {key:"SHIFT + Media Pause", desc:"Switch media source", cat:"System", disp:"exec", arg:"omarchy-audio-source-switch"},
        {key:"SHIFT + Media Play", desc:"Switch media source", cat:"System", disp:"exec", arg:"omarchy-audio-source-switch"},
        {key:"SUPER + ALT + Down", desc:"Move window to group on bottom", cat:"Windows", disp:"rawlua", arg:"hl.dsp.window.move({ into_group = \"d\" })"},
        {key:"SUPER + ALT + F", desc:"Full width", cat:"Windows", disp:"rawlua", arg:"hl.dsp.window.fullscreen({ mode = \"maximized\" })"},
        {key:"SUPER + ALT + G", desc:"Move active window out of group", cat:"Windows", disp:"rawlua", arg:"hl.dsp.window.move({ out_of_group = true })"},
        {key:"SUPER + ALT + Home", desc:"Save window width", cat:"Windows", disp:"exec", arg:"omarchy-hyprland-window-width save"},
        {key:"SUPER + ALT + Left", desc:"Move window to group on left", cat:"Windows", disp:"rawlua", arg:"hl.dsp.window.move({ into_group = \"l\" })"},
        {key:"SUPER + ALT + Wheel down", desc:"Next window in group", cat:"Windows", disp:"rawlua", arg:"hl.dsp.group.next()"},
        {key:"SUPER + ALT + Wheel up", desc:"Previous window in group", cat:"Windows", disp:"rawlua", arg:"hl.dsp.group.prev()"},
        {key:"SUPER + ALT + Return", desc:"Tmux", cat:"Apps", disp:"exec", arg:"omarchy-launch-terminal-tmux"},
        {key:"SUPER + ALT + Right", desc:"Move window to group on right", cat:"Windows", disp:"rawlua", arg:"hl.dsp.window.move({ into_group = \"r\" })"},
        {key:"SUPER + ALT + Slash", desc:"Monitor scaling down", cat:"Workspaces", disp:"exec", arg:"omarchy-hyprland-monitor-scaling down"},
        {key:"SUPER + ALT + Tab", desc:"Next window in group", cat:"Windows", disp:"rawlua", arg:"hl.dsp.group.next()"},
        {key:"SUPER + ALT + Up", desc:"Move window to group on top", cat:"Windows", disp:"rawlua", arg:"hl.dsp.window.move({ into_group = \"u\" })"},
        {key:"SUPER + Backspace", desc:"Toggle window transparency", cat:"Windows", disp:"exec", arg:"omarchy-hyprland-window-transparency-toggle"},
        {key:"SUPER + C", desc:"Universal copy", cat:"Windows", disp:"rawlua", arg:"function() local w = hl.get_active_window(); local term = false; if w then for _, tag in ipairs(w.tags or {}) do if tag:gsub(\"%*$\", \"\") == \"terminal\" then term = true end end end; local mods, key = \"CTRL\", \"C\"; if term then mods, key = \"CTRL\", \"Insert\" end; hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = \"down\" })); hl.timer(function() hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = \"up\" })) end, { timeout = 50, type = \"oneshot\" }) end"},
        {key:"SUPER + CTRL + ALT + B", desc:"Show battery remaining", cat:"System", disp:"exec", arg:"omarchy-notification-battery"},
        {key:"SUPER + CTRL + ALT + Delete", desc:"Toggle laptop display mirroring", cat:"System", disp:"exec", arg:"omarchy-hyprland-monitor-internal-mirror toggle"},
        {key:"SUPER + CTRL + ALT + T", desc:"Show time", cat:"System", disp:"exec", arg:"omarchy-notification-time"},
        {key:"SUPER + CTRL + ALT + W", desc:"Toggle weather", cat:"System", disp:"exec", arg:"omarchy-notification-weather"},
        {key:"SUPER + CTRL + Backspace", desc:"Toggle single-window square aspect", cat:"Windows", disp:"exec", arg:"omarchy-hyprland-window-single-square-aspect-toggle"},
        {key:"SUPER + CTRL + Delete", desc:"Toggle laptop display", cat:"System", disp:"exec", arg:"omarchy-hyprland-monitor-internal toggle"},
        {key:"SUPER + CTRL + F", desc:"Tiled full screen", cat:"Windows", disp:"exec", arg:"omarchy-hyprland-window-tiled-fullscreen-toggle"},
        {key:"SUPER + CTRL + Left", desc:"Move grouped window focus left", cat:"Windows", disp:"rawlua", arg:"hl.dsp.group.prev()"},
        {key:"SUPER + CTRL + Period", desc:"Transcode", cat:"System", disp:"exec", arg:"omarchy-transcode"},
        {key:"SUPER + CTRL + Print", desc:"Extract text (OCR) from screenshot", cat:"System", disp:"exec", arg:"omarchy-capture-text"},
        {key:"SUPER + CTRL + Q", desc:"Calculator", cat:"System", disp:"exec", arg:"omacalc"},
        {key:"SUPER + CTRL + Return", desc:"Herdr", cat:"Apps", disp:"exec", arg:"omarchy-launch-terminal-herdr"},
        {key:"SUPER + CTRL + Right", desc:"Move grouped window focus right", cat:"Windows", disp:"rawlua", arg:"hl.dsp.group.next()"},
        {key:"SUPER + CTRL + Tab", desc:"Former workspace", cat:"Workspaces", disp:"rawlua", arg:"hl.dsp.focus({ workspace = \"previous\" })"},
        {key:"SUPER + G", desc:"Toggle window grouping", cat:"Windows", disp:"rawlua", arg:"hl.dsp.group.toggle()"},
        {key:"SUPER + J", desc:"Toggle window split", cat:"Windows", disp:"rawlua", arg:"hl.dsp.layout(\"togglesplit\")"},
        {key:"SUPER + Mouse drag", desc:"Move window", cat:"Windows", disp:"rawlua", arg:"hl.dsp.window.drag()"},
        {key:"SUPER + Right-drag", desc:"Resize window", cat:"Windows", disp:"rawlua", arg:"hl.dsp.window.resize()"},
        {key:"SUPER + Wheel down", desc:"Scroll active workspace forward", cat:"Workspaces", disp:"rawlua", arg:"hl.dsp.focus({ workspace = \"e+1\" })"},
        {key:"SUPER + Wheel up", desc:"Scroll active workspace backward", cat:"Workspaces", disp:"rawlua", arg:"hl.dsp.focus({ workspace = \"e-1\" })"},
        {key:"SUPER + O", desc:"Pop window out (float & pin)", cat:"Windows", disp:"exec", arg:"omarchy-hyprland-window-pop"},
        {key:"SUPER + P", desc:"Pseudo window", cat:"Windows", disp:"rawlua", arg:"hl.dsp.window.pseudo()"},
        {key:"SUPER + SHIFT + ALT + Down", desc:"Move workspace to down monitor", cat:"Workspaces", disp:"rawlua", arg:"hl.dsp.workspace.move({ monitor = \"d\" })"},
        {key:"SUPER + SHIFT + ALT + E", desc:"New email", cat:"Apps", disp:"exec", arg:"omarchy-launch-webapp 'https://app.hey.com/messages/new?display=standalone&new_window=true'"},
        {key:"SUPER + SHIFT + ALT + F", desc:"File manager (cwd)", cat:"Apps", disp:"exec", arg:"omarchy-launch-nautilus-cwd"},
        {key:"SUPER + SHIFT + ALT + G", desc:"WhatsApp", cat:"Apps", disp:"exec", arg:"omarchy-launch-webapp 'https://web.whatsapp.com/'"},
        {key:"SUPER + SHIFT + ALT + Left", desc:"Move workspace to left monitor", cat:"Workspaces", disp:"rawlua", arg:"hl.dsp.workspace.move({ monitor = \"l\" })"},
        {key:"SUPER + SHIFT + ALT + M", desc:"Music TUI", cat:"Apps", disp:"exec", arg:"omarchy-launch-or-focus-tui cliamp"},
        {key:"SUPER + SHIFT + ALT + Right", desc:"Move workspace to right monitor", cat:"Workspaces", disp:"rawlua", arg:"hl.dsp.workspace.move({ monitor = \"r\" })"},
        {key:"SUPER + SHIFT + ALT + Tab", desc:"Previous window in group", cat:"Windows", disp:"rawlua", arg:"hl.dsp.group.prev()"},
        {key:"SUPER + SHIFT + ALT + Up", desc:"Move workspace to up monitor", cat:"Workspaces", disp:"rawlua", arg:"hl.dsp.workspace.move({ monitor = \"u\" })"},
        {key:"SUPER + SHIFT + Backspace", desc:"Toggle window gaps", cat:"Windows", disp:"exec", arg:"omarchy-hyprland-window-gaps-toggle"},
        {key:"SUPER + SHIFT + CTRL + A", desc:"Agent", cat:"Apps", disp:"exec", arg:"omarchy-agent --pick"},
        {key:"SUPER + SHIFT + CTRL + R", desc:"Clear reminders", cat:"System", disp:"exec", arg:"omarchy-reminder clear"},
        {key:"SUPER + SHIFT + G", desc:"Signal", cat:"Apps", disp:"exec", arg:"omarchy-launch-signal"},
        {key:"SUPER + SHIFT + Return", desc:"Browser", cat:"Apps", disp:"exec", arg:"omarchy-launch-browser"},
        {key:"SUPER + SHIFT + Slash", desc:"Passwords", cat:"Apps", disp:"exec", arg:"omarchy-launch-1password"},
        {key:"SUPER + SHIFT + W", desc:"Omawrite", cat:"Apps", disp:"exec", arg:"uwsm-app -- omawrite"},
        {key:"SUPER + Slash", desc:"Monitor scaling up", cat:"Workspaces", disp:"exec", arg:"omarchy-hyprland-monitor-scaling up"},
        {key:"SUPER + V", desc:"Universal paste", cat:"Windows", disp:"rawlua", arg:"function() local w = hl.get_active_window(); local term = false; if w then for _, tag in ipairs(w.tags or {}) do if tag:gsub(\"%*$\", \"\") == \"terminal\" then term = true end end end; local mods, key = \"CTRL\", \"V\"; if term then mods, key = \"SHIFT\", \"Insert\" end; hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = \"down\" })); hl.timer(function() hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = \"up\" })) end, { timeout = 50, type = \"oneshot\" }) end"},
        {key:"SUPER + X", desc:"Universal cut", cat:"Windows", disp:"rawlua", arg:"function() hl.dispatch(hl.dsp.send_key_state({ mods = \"CTRL\", key = \"X\", state = \"down\" })); hl.timer(function() hl.dispatch(hl.dsp.send_key_state({ mods = \"CTRL\", key = \"X\", state = \"up\" })) end, { timeout = 50, type = \"oneshot\" }) end"},
        {key:"Calculator key", desc:"Calculator", cat:"System", disp:"exec", arg:"omacalc"},
        {key:"Eject media", desc:"Eject media", cat:"System", disp:"exec", arg:"eject"},
        {key:"Kbd brightness down", desc:"Keyboard brightness down", cat:"System", disp:"exec", arg:"omarchy-brightness-keyboard down"},
        {key:"Kbd brightness up", desc:"Keyboard brightness up", cat:"System", disp:"exec", arg:"omarchy-brightness-keyboard up"},
        {key:"Kbd backlight", desc:"Keyboard backlight cycle", cat:"System", disp:"exec", arg:"omarchy-brightness-keyboard cycle"},
        {key:"Touchpad off", desc:"Disable touchpad", cat:"System", disp:"exec", arg:"omarchy-toggle-touchpad off"},
        {key:"Touchpad on", desc:"Enable touchpad", cat:"System", disp:"exec", arg:"omarchy-toggle-touchpad on"},
        {key:"SUPER + CTRL + I", desc:"Toggle locking on idle", cat:"System", disp:"exec", arg:"omarchy-toggle-idle"},
        {key:"SUPER + CTRL + N", desc:"Toggle nightlight", cat:"System", disp:"exec", arg:"omarchy-toggle-nightlight"},
        {key:"SUPER + CTRL + ,", desc:"Toggle silencing notifications", cat:"System", disp:"exec", arg:"omarchy-toggle-notification-silencing"},
        {key:"SUPER + SHIFT + Space", desc:"Toggle top bar", cat:"System", disp:"exec", arg:"omarchy-toggle-bar"},
        {key:"Touchpad toggle", desc:"Toggle touchpad", cat:"System", disp:"exec", arg:"omarchy-toggle-touchpad"},
        {key:"SUPER + ALT + 1", desc:"Sticky slot 1", cat:"Windows", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call sticky copy 1"},
        {key:"SUPER + ALT + 2", desc:"Sticky slot 2", cat:"Windows", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call sticky copy 2"},
        {key:"SUPER + ALT + 3", desc:"Sticky slot 3", cat:"Windows", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call sticky copy 3"},
        {key:"SUPER + ALT + 4", desc:"Sticky slot 4", cat:"Windows", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call sticky copy 4"},
        {key:"SUPER + ALT + 5", desc:"Sticky slot 5", cat:"Windows", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call sticky copy 5"},
        {key:"SUPER + ALT + 6", desc:"Sticky slot 6", cat:"Windows", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call sticky copy 6"},
        {key:"SUPER + ALT + 7", desc:"Sticky slot 7", cat:"Windows", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call sticky copy 7"},
        {key:"SUPER + ALT + 8", desc:"Sticky slot 8", cat:"Windows", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call sticky copy 8"},
        {key:"SUPER + ALT + 9", desc:"Sticky slot 9", cat:"Windows", disp:"exec", arg:"quickshell -p ~/.config/quickshell ipc call sticky copy 9"},
        {key:"SUPER Ctrl + Z", desc:"Zoom in", cat:"System", disp:"exec", arg:"hyprctl eval 'local zoom = hl.get_config(\"cursor.zoom_factor\") or 1; hl.config({ cursor = { zoom_factor = zoom + 1 } })'"},
        {key:"SUPER Ctrl + Alt + Z", desc:"Reset zoom", cat:"System", disp:"exec", arg:"hyprctl eval 'hl.config({ cursor = { zoom_factor = 1 } })'"},
        {key:"SUPER Ctrl + L", desc:"Lock system", cat:"System", disp:"exec", arg:"omarchy-system-lock"},
    ]

    property var filtered: {
        if(filter.trim()==="") return binds
        // token-AND: every word must match somewhere (key, desc, cat, arg).
        // "zen split" finds split rows; "super shift" narrows to chords.
        var toks = filter.trim().toLowerCase().split(/\s+/)
        return binds.filter(function(b){
            var hay = (b.key + " " + b.desc + " " + b.cat + " " + (b.arg || "")).toLowerCase()
            for (var i = 0; i < toks.length; i++) if (!hay.includes(toks[i])) return false
            return true
        })
    }
    // grouped model — category header rows interleaved with binds so the
    // list reads as sections, not a dumb flat dump. Headers carry only
    // {header}, rows carry the bind.
    property var grouped: {
        var out = [], last = ""
        for (var i = 0; i < filtered.length; i++) {
            if (filtered[i].cat !== last) { last = filtered[i].cat; out.push({header: last}) }
            out.push(filtered[i])
        }
        return out
    }
    function firstRowIndex(){ for (var i=0;i<grouped.length;i++) if(grouped[i].header===undefined) return i; return -1 }
    function moveSelection(d){
        var i=list.currentIndex
        while (true) {
            i+=d
            if (i<0) { i=0; break }
            if (i>=grouped.length) { i=grouped.length-1; break }
            if (grouped[i].header===undefined) break
        }
        list.currentIndex=i; list.positionViewAtIndex(i,ListView.Contain)
    }
    // Translate a .conf-era dispatch/arg pair into the Lua dispatcher
    // expression Hyprland 0.56 now evaluates.
    //
    // hyprctl wraps whatever you hand it as `hl.dispatch(<arg>)` and then
    // evaluates that as Lua, so the old flat strings ("workspace 3",
    // "movefocus l") are syntax errors — "')' expected near '3'". Every
    // non-exec row in the binds table below was failing silently for that
    // reason: the cheatsheet opened and looked right, and activating an entry
    // did nothing.
    //
    // Keeping the table in the readable "workspace"/"movefocus" form and
    // translating here means the data stays greppable and there is exactly one
    // place to get the mapping right.
    function toLuaDispatch(disp: string, arg: string): string {
        // Workspaces are strings, not numbers: hl.dsp.focus({workspace=3})
        // parses but does not move. "e+1"/"e-1"/"previous" stay as-is.
        var ws = 'hl.dsp.focus({workspace="' + arg + '"})'
        switch (disp) {
        case "workspace":        return ws
        case "movetoworkspace":  return 'hl.dsp.window.move({workspace="' + arg + '"})'
        case "movefocus":        return 'hl.dsp.focus({direction="' + arg + '"})'
        case "swapwindow":       return 'hl.dsp.window.swap({direction="' + arg + '"})'
        case "killactive":       return 'hl.dsp.window.close()'
        // Rows generated from the bind sources carry the dispatcher exactly as
        // the bind defines it (hl.dsp.window.pseudo(), hl.dsp.focus({...}) …);
        // replay them verbatim instead of translating each shape.
        case "rawlua":           return arg
        case "fullscreen":       return 'hl.dsp.window.fullscreen({mode="fullscreen"})'
        case "togglefloating":   return 'hl.dsp.window.float({action="toggle"})'
        default:                 return ""
        }
    }

    function executeSelected(){
        var idx=list.currentIndex
        if(idx<0 || idx>=grouped.length) return
        var b=grouped[idx]
        if(b.header!==undefined) return
        root.open=false
        if(b.disp==="exec" && b.arg) Quickshell.execDetached(["sh","-c", b.arg])
        else if(b.disp) {
            var lua=toLuaDispatch(b.disp, b.arg===undefined ? "" : b.arg)
            if(lua!=="") Quickshell.execDetached(["hyprctl","dispatch",lua])
            else console.warn("KeybindsPanel: no Lua mapping for dispatcher '"+b.disp+"'")
        }
    }
    onFilteredChanged: list.currentIndex = firstRowIndex()

    // click-outside catcher (invisible — no dim backdrop, card floats over desktop)
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        MouseArea { anchors.fill: parent; onClicked: root.open=false }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 640
        height: 520
        radius: 18
        color: colors.alpha(colors.surface, 0.52)
        border.width:1; border.color: colors.alpha(colors.outline, 0.15)
        focus: root.open
        Keys.onEscapePressed: root.open=false
        Keys.onReturnPressed: root.executeSelected()
        Keys.onEnterPressed: root.executeSelected()
        // type-to-search — keystrokes landing on the card (field not focused)
        // route straight into the search field
        Keys.onPressed: function(e){
            if (searchField.activeFocus) return
            if (e.text !== "" && e.text.length === 1 && (e.modifiers === Qt.NoModifier || e.modifiers === Qt.ShiftModifier)
                && e.key !== Qt.Key_Escape && e.key !== Qt.Key_Return && e.key !== Qt.Key_Enter) {
                searchField.text += e.text
                searchField.forceActiveFocus()
                e.accepted = true
            }
        }
        Keys.onDownPressed: root.moveSelection(1)
        Keys.onUpPressed: root.moveSelection(-1)
        transform: Translate { id: slide }
        Component.onCompleted: slide.y=20
        // bezier pair — rise settles with overshoot bounce on open, hurries
        // out plain on close. Card is centered so scale uses the card
        // property (transformOrigin center) instead of an edge Scale.
        ParallelAnimation {
            id: openAnim
            NumberAnimation { target: slide; property: "y"; from: 20; to: 0; duration: 280; easing.type: Easing.Bezier; easing.bezierCurve: [0.34, 1.35, 0.64, 1] }
            NumberAnimation { target: card; property: "opacity"; from: 0; to: 1; duration: 220; easing.type: Easing.Bezier; easing.bezierCurve: [0.32, 0.72, 0, 1] }
            NumberAnimation { target: card; property: "scale"; from: 0.96; to: 1; duration: 280; easing.type: Easing.Bezier; easing.bezierCurve: [0.34, 1.35, 0.64, 1] }
        }
        ParallelAnimation {
            id: closeAnim
            NumberAnimation { target: slide; property: "y"; to: 20; duration: 220; easing.type: Easing.Bezier; easing.bezierCurve: [0.32, 0.72, 0, 1] }
            NumberAnimation { target: card; property: "opacity"; to: 0; duration: 180; easing.type: Easing.Bezier; easing.bezierCurve: [0.32, 0.72, 0, 1] }
            NumberAnimation { target: card; property: "scale"; to: 0.96; duration: 220; easing.type: Easing.Bezier; easing.bezierCurve: [0.32, 0.72, 0, 1] }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Text { text: "Keybindings"; color: colors.foreground; font.family: colors.fontSans; font.pixelSize: 14; font.weight: Font.ExtraBold; Layout.fillWidth:true }
                Text { text: filtered.length+" / "+binds.length; color: colors.alpha(colors.outline,0.6); font.family: colors.fontSans; font.pixelSize: 9 }
                Rectangle {
                    width: 28; height: 28; radius: 14
                    color: closeMa.containsMouse?colors.alpha(colors.error,0.12):"transparent"
                    Text { anchors.centerIn: parent; text: "󰅖"; color: closeMa.containsMouse?colors.error:colors.alpha(colors.outline,0.7); font.family: colors.fontSans; font.pixelSize: 13 }
                    MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled:true; onClicked: root.open=false }
                }
            }

            TextField {
                id: searchField
                Layout.fillWidth: true
                implicitHeight: 36
                leftPadding: 14; rightPadding: 14
                placeholderText: "Search keybindings… (try 'window' or 'super')"
                placeholderTextColor: colors.alpha(colors.outline,0.5)
                color: colors.foreground
                font.family: colors.fontSans; font.pixelSize: 11
                background: Rectangle {
                    radius: 12
                    color: colors.alpha(colors.surface,0.6)
                    border.width:1; border.color: searchField.activeFocus?colors.alpha(colors.primary,0.5):colors.alpha(colors.outline,0.15)
                }
                onTextChanged: root.filter=text
                Keys.onReturnPressed: root.executeSelected()
                Keys.onEnterPressed: root.executeSelected()
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: root.grouped
                currentIndex: 0
                spacing: 4
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                delegate: Item {
                    required property var modelData
                    required property int index
                    readonly property bool isHeader: modelData.header !== undefined
                    width: list.width
                    height: isHeader ? 26 : 44

                    // section header — house micro-type
                    Text {
                        visible: isHeader
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 12 }
                        text: isHeader ? modelData.header.toUpperCase() : ""
                        color: colors.alpha(colors.outline, 0.6)
                        font.family: colors.fontSans; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.5
                    }

                    Rectangle {
                        visible: !isHeader
                        anchors.fill: parent
                        radius: 10
                        color: list.currentIndex===index ? colors.alpha(colors.primary,0.10) : ma.containsMouse ? colors.alpha(colors.primary,0.08) : "transparent"
                        border.width: list.currentIndex===index ? 1 : 0
                        border.color: colors.alpha(colors.primary,0.2)
                        // one hover language: tint + slight scale, no lift (same as plugins)
                        scale: (list.currentIndex===index || ma.containsMouse) ? 1.01 : 1
                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12; anchors.rightMargin: 12
                            spacing: 12
                            Rectangle {
                                Layout.preferredWidth: keyText.implicitWidth+16
                                Layout.preferredHeight: 22
                                radius: 7
                                color: colors.alpha(colors.primary,0.12)
                                border.width:1; border.color: colors.alpha(colors.primary,0.25)
                                Text {
                                    id: keyText
                                    anchors.centerIn: parent
                                    text: isHeader ? "" : modelData.key
                                    color: colors.primary
                                    font.family: colors.fontSans; font.pixelSize: 9; font.weight: Font.Bold
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text {
                                    text: isHeader ? "" : modelData.desc
                                    color: colors.foreground
                                    font.family: colors.fontSans; font.pixelSize: 11; font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: isHeader ? "" : modelData.cat
                                    color: colors.alpha(colors.outline,0.6)
                                    font.family: colors.fontSans; font.pixelSize: 8
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: ma; anchors.fill: parent; hoverEnabled:true
                        visible: !isHeader
                        onClicked: list.currentIndex=index
                        onDoubleClicked: root.executeSelected()
                    }
                }
            }

            Text {
                visible: root.filtered.length===0
                text: "No matches"
                color: colors.alpha(colors.outline,0.6)
                font.family: colors.fontSans; font.pixelSize: 11
                Layout.alignment: Qt.AlignHCenter
            }

            // footer — kbd hints, same language as plugins
            Row {
                spacing: 12
                Layout.alignment: Qt.AlignHCenter
                Repeater {
                    model: [ { k: "↑↓", a: "move" }, { k: "↵", a: "run" }, { k: "esc", a: "close" } ]
                    delegate: Row {
                        required property var modelData
                        spacing: 4
                        Rectangle {
                            width: Math.max(22, kbdTxt.implicitWidth + 10)
                            height: 16
                            radius: 4
                            color: colors.alpha(colors.surfaceVariant, 0.5)
                            border.width: 1; border.color: colors.alpha(colors.outline, 0.12)
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                id: kbdTxt
                                anchors.centerIn: parent
                                text: modelData.k
                                color: colors.secondary
                                font.family: colors.fontSans; font.pixelSize: 7; font.weight: Font.Bold
                            }
                        }
                        Text {
                            text: modelData.a
                            color: colors.alpha(colors.outline, 0.45)
                            font.family: colors.fontSans; font.pixelSize: 7; font.weight: Font.Bold; font.letterSpacing: 1.3
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }
    }
}
