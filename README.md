# dotfiles

Omarchy, Hyprland, Quickshell, Matugen. Wallpaper sets the palette, everything else follows.

![Desktop](assets/screenshots/desktop.png)

Bar island, Zathura and foot over a wallpaper-pulled palette. Every surface you see here (bar, OSD, toasts, terminals, editors) is recolored from that one image.

## This fork replaces the Omarchy shell

Omarchy ships its own Quickshell shell (`omarchy-shell`) that owns the bar,
notifications bus, OSD, panels, launcher, and idle/lock. This repo ships its
own shell with the same ambitions. **Only one can run** — they both claim
`org.freedesktop.Notifications` and the same layer surfaces, and whichever
loses the race takes the toasts down with it.

So the Omarchy shell is switched off and this repo's takes over. That is done
by shadowing one packaged file, not by editing anything under
`/usr/share/omarchy`:

```
~/.config/default/hypr/autostart.lua   # shadows $OMARCHY_PATH's, minus one line
```

Hyprland resolves `require("default.hypr.autostart")` against `~/.config`
before `$OMARCHY_PATH`, so the packaged default is never touched and an
`omarchy update` cannot clobber it.

The tradeoff is that when an update ships a *changed* `autostart.lua`, the new
content lands in `/usr/share` while this desktop keeps using the old copy — so
upstream startup work would silently never run. That is handled for you:

```bash
omarchy-shadow-check     # exit 0 = in sync; run it by hand any time
```

It is wired into `~/.config/omarchy/hooks/post-update.d/`, so every
`omarchy update` checks itself and stays silent unless you have actually
drifted — then it logs to the journal and sends a notification naming the
missing lines.

> A raw `diff` against the shadow is misleading: it *always* shows the same
> three cosmetic hunks (the explanatory header, the commented-out
> `omarchy-launch-shell` line, and a trailing-newline marker), and `diff` exits
> 0 whether or not anything changed. `omarchy-shadow-check` canonicalises both
> sides first — drops blank lines and trailing whitespace, normalises both
> spellings of "we removed this" — so the only output you ever get is a real
> difference.

Everything else in that file (monitor watch, udiskie, power profiles,
post-boot hooks) still runs. The hook lives in `~/.config/omarchy/` rather
than this repo on purpose: that directory is Omarchy's own (`shell.json`,
themes, hooks) and is machine state, not portable config.

Consequences of the swap, all deliberate:

| Omarchy's shell used to | Now handled by |
|---|---|
| notifications bus | this shell (`quickshell -p ~/.config/quickshell`) |
| bar, panels, OSD, launcher | this shell |
| idle + lock (`shell.json` `idle.lock`) | `hypridle` + `hyprlock`, launched from `hypr/autostart.lua` |
| background switcher | `awww` + `set-wallpaper` |
| **polkit authentication dialog** | `lxqt-policykit-agent` (Omarchy's lived inside the shell) |
| login screen | Omarchy's SDDM theme (see *Login screen*) |

`omarchy restart shell` does nothing here — that targets the shell you just
disabled. Reload the desktop with `SUPER+HOME` instead (reloads Hyprland, then
restarts Quickshell).

> [!NOTE]
> Omarchy's shell ships an `omarchy.polkit` plugin that draws the password
> prompt, and stopping that shell takes the agent with it — polkit would have
> no way to ask for a password (disk mounting, `udiskie`, `pkexec` from a GUI
> app). This desktop runs **`lxqt-policykit`** instead, which autostarts via
> `/etc/xdg/autostart/lxqt-policykit-agent.desktop`, so it comes up at login
> without any wiring here. Verify with:
>
> ```bash
> pgrep -a lxqt-policykit-agent
> ```
>
> `polkit-gnome` or `yad` would work equally well. `sudo` in a terminal never
> needed this, and this repo's own rofi-based `SUDO_ASKPASS`
> (`~/.local/bin/askpass`, wired in `hypr/envs.lua`) still works for anything
> that honours it.

## Fresh machine

The machine needs Omarchy installed first; this repo is a config layer on top.

```bash
sudo pacman -S --needed foot matugen zsh lsd cava hyprlock hypridle \
     cliphist rofi thunar tumbler thunar-archive-plugin thunar-volman \
     file-roller catfish poppler-glib awww zathura chafa \
     ttf-firacode-nerd ttf-jetbrains-mono-nerd inter-font

# if you are replacing the Omarchy shell (see above), also:
sudo pacman -S lxqt-policykit

git clone https://github.com/codetesla51/uthman_dotfiles.git ~/dotfiles
cd ~/dotfiles && chmod +x install.sh && ./install.sh
```

Then log out and back in so the new autostart runs. `SUPER+K` is the keybind
cheatsheet.

> `ttf-jetbrains-mono-nerd` and `ttf-jetbrains-mono-nerd-basic` conflict. Keep
> whichever one is installed; the configs only need the family name
> `JetBrainsMono Nerd Font`, which both provide.

### Login screen

SDDM still uses Omarchy's `omarchy` theme. The repo's `sddm/elarun-custom`
theme is shipped but **not installed by default**: `install.sh` would have to
write to `/usr/share/sddm/themes/`, and matugen would have to write there again
on *every wallpaper change*, which means a root prompt each time. The login
screen is the one surface the wallpaper does not reach.

To switch anyway, by hand:

```bash
sudo cp -r ~/dotfiles/sddm/elarun-custom /usr/share/sddm/themes/
printf '[Theme]\nCurrent=elarun-custom\n' | sudo tee /etc/sddm.conf.d/99-zz-elarun.conf
```

`99-zz-` sorts after Omarchy's `99-omarchy-login.conf`, which also sets
`Current` and would otherwise win.


## How the whole thing fits together

Four pieces, and each one only knows about the one below it.

```
Hyprland         window manager, keybinds, layer rules, compositor
  └── quickshell bar, panels, OSD, notification daemon  (all QML)
        └── Matugen   one image -> every app's colors
              └── wallpaper   the only input
```

Hyprland owns windows and keys. It never draws the bar itself. Quickshell owns everything you see drawn by this repo, in one QML process. Matugen owns color, and knows nothing about QML. The wallpaper is the single input that flows upward through the other three.

A wallpaper change is the clearest way to see the whole chain move:

```bash
set-wallpaper ~/Pictures/new.jpg
```

That one command does five things in order:

1. Symlinks the image to `~/.config/theme/current/background`, which is what everything else treats as "current wallpaper".
2. Hands it to `awww` (or `swww`) for a 0.7s wave transition, so the change is visible before any color moves.
3. Calls `getTheme`, which runs `matugen image` to build a Material You palette.
4. Regenerates the cursor theme through `matugen-cursor`, round-tripping it so Hyprland drops its cache and no logout is needed.
5. Writes the basename to `~/.local/state/omarchy/current/theme.name` as a nudge for the file manager to hot-reload.

Matugen then writes 37 output files from 19 templates, one file per app per destination. Nothing is copied or converted afterward. The shell notices on its own within a second.

### How one image becomes every app's colors

Each template is a file with `{{ colors... }}` placeholders. Matugen renders it and writes the result. The config is a flat list of template-to-output pairs, and several templates are rendered more than once because they need to land in two places:

```toml
[templates.hyprland-colors]
input_path  = "~/.config/matugen/templates/hyprland-colors.lua"
output_path = "~/.config/theme/colors.lua"
```

Hyprland's palette is generated as **Lua**, not `.conf`. The old config did
`source = ~/.config/theme/current/colors.conf`, and `source` is gone under
Hyprland's Lua config, so a `.conf` palette has nowhere to hook in. Instead
`~/.config/hypr/theme.lua` does `require("theme.colors")`, which resolves
`theme.colors` to exactly `~/.config/theme/colors.lua` on `package.path`.

> The require has to be preceded by `package.loaded["theme.colors"] = nil`.
> Hyprland's bootstrap clears its own module cache on reload but not this one,
> so without it a reload re-applies the palette from the very first load and
> wallpaper changes look like they did nothing to the borders.

### Where the generated files land

| Destination | Who reads it |
|-------------|--------------|
| `~/.config/quickshell/colors.css` | the shell, polled every second |
| `~/.config/theme/colors.lua` | `hyprland/theme.lua` via `require("theme.colors")` |
| `~/.config/theme/current/` | live config for every other app, rewritten each wallpaper change |
| `~/.config/theme/themes/snow_black/` | named snapshot; grows over time and is safe to delete |
| `~/.config/omarchy/current/theme/` | read by Omarchy's own app configs (kitty, foot, ghostty, chromium, the preview share picker) |
| `~/.config/{cava,rofi,zathura}/` | audio visualizer, launcher, PDF reader |

`theme/current/` is what most apps read at runtime.

**Every output is inside `~/.config`, and that is load-bearing.** Matugen aborts
the entire run on the first output it cannot write. A single root-owned or
nonexistent path in the default set makes *every* wallpaper change look like a
total failure — and `getTheme` would then skip its cursor and reload steps. The
outputs that used to live outside `~/.config` were removed rather than left to
fail:

- **SDDM** → `/usr/share/sddm/themes/`, root-owned. Removed; see *Login screen*.
- **Obsidian** → a personal notes vault that does not exist here. Removed.
- **Cavasik** → not installed on this desktop. Removed; plain `cava` is used.

### Why the shell picks the trickiest path

The shell's palette comes from `waybar-colors.css`, named for Waybar even though no Waybar runs here. It is a plain list of 29 Material color roles:

```css
@define-color primary   #adc6ff;
@define-color surface   #1c110f;
@define-color tertiary  #ffb780;
```

The template is still called `waybar` because it predates the rewrite and `config.toml` maps it, but the file it produces is quickshell's `colors.css`. The shell does not use any reload signal — it polls the file instead, because Matugen replaces the file rather than editing it. A replaced file gets a new inode, which silently breaks `FileView` watchers, so `Colors.qml` re-reads on a 1s timer instead. (The vestigial `reload_apps.waybar = true` setting that used to send a signal has been removed; nothing here consumes it.)

> [!TIP]
> `set-wallpaper` backgrounds `getTheme` and waits on it, so the transition starts immediately while colors are still being computed. Total time from press to fully restyled desktop is about 3 seconds, of which matugen is 2.1 and the cursor is 0.9. They run in parallel, so adding more templates costs nothing to perceived speed.

### Where each concern lives

| Concern | Owner | Notes |
|---------|-------|-------|
| Windows, keys, blur, gaps | `~/.config/hypr/*.lua` | Lua, loaded after Omarchy's defaults; `bindings.lua` unbinds the chords it replaces |
| Everything drawn | `~/.config/quickshell/` | 55 modules, one palette object shared by all of them |
| Colors for everything | `~/.config/matugen/` | `config.toml` maps templates to outputs |
| Idle + lock | `hypridle` + `hyprlock` | external Wayland clients; the shell's own idle/lock is not used |
| Wallpaper | `~/Pictures/` | git-ignored, never committed |
| Terminal, prompt, history | `.zshrc` + starship/atuin | unrelated to the shell process |

The separation is deliberate: if a theme breaks, only Matugen's templates are involved. If a panel misbehaves, only QML is involved. There is no config file that mixes the two.

## How theming works

Matugen reads the wallpaper, builds a Material You palette, and fills variables in each template. One command recolors everything with no restarts:

```bash
matugen image ~/Pictures/your-wallpaper.jpg
```

Normally you call `set-wallpaper` instead, since that also swaps the image itself and regenerates the cursor.

`~/.config/matugen/config.toml` maps each template to its outputs. The main ones:

| Template | Output |
|----------|--------|
| `waybar` | `~/.config/quickshell/colors.css` (the file the live shell polls) |
| `hyprland-colors` | `~/.config/theme/colors.lua` + `snow_black/colors.lua` |
| `hyprlock-standalone`, `kitty-*`, `foot-*`, `gtk`, `btop` | matching live files under `theme/current` |
| `cava` | `snow_black/cava_theme` + `~/.config/cava/config` (rewritten directly) |
| `firefox` | `theme/current/firefox{,-usercontent}.css`, symlinked as `userChrome.css`/`userContent.css` |
| `rofi`, `neovim`, `swayosd`, `zed`, `zathura` | per-app live outputs |

Active colors live in `~/.config/theme/current/` and are rewritten on every run. `snow_black/` keeps saved snapshots, `theme-fallback/` ships the static seed.

> [!TIP]
> `Colors.qml` polls `~/.config/quickshell/colors.css` every second. Matugen replaces the file (new inode) instead of editing it, so the poller re-reads rather than watching. Palette swaps propagate with no restart.

> [!WARNING]
> Always run full `matugen image` with the same wallpaper source when you mean "refresh". Running it against a different image silently re-palettes all outputs at once. After any regen, `git diff --stat` in `~/dotfiles` should show only what you expect.

## Quickshell desktop shell

The shell replaces Waybar and SwayNC with one QML codebase. Entry is `shell.qml`, which instantiates the bar plus standalone windows sharing one `Colors` palette object. The bar window sits at `y=0 h=54`. The center tab is a trapezoid in classic mode, and `SUPER ALT SPACE` flips it into a floating black capsule. Clock, NowPlaying (album art, title/artist, live visualizer, hover transport), and the bell live flat inside it. System pills (CPU, memory, temp, network, battery, WatchCat) ride left and right as glass pills.

Heavy panels load on first use, then stay compiled in memory. `shell.qml` holds the IPC target and drives `item.open` in both directions, so a reopened panel is a flag flip instead of a fresh QML compile. Presses that arrive mid-compile are ignored rather than cancelling the open.

Hyprland binds and scripts talk to the shell over IPC, always with the identical path string:

```bash
quickshell -p ~/.config/quickshell                 # run. Never -p . or a realpath.
quickshell -p ~/.config/quickshell ipc show        # list every target
quickshell -p ~/.config/quickshell ipc call wifi toggle
quickshell -p ~/.config/quickshell ipc call notifications toggleDnd
```

> [!WARNING]
> This quickshell daemon owns `org.freedesktop.Notifications`. `swaync` must stay
> masked, and so must `omarchy-shell` — but that one is already handled: the
> shadowed `autostart.lua` never launches it. To confirm which process holds the
> bus:
>
> ```bash
> busctl --user status org.freedesktop.Notifications | grep PID
> ```

> [!NOTE]
> Mismatched `-p` strings fail with `Target not found` even while a shell is clearly running. Autostart, binds, and manual calls must all use `~/.config/quickshell` verbatim.

### Bar pills

Thin widgets. They display state and delegate detail to panels.

| Module | Role |
|--------|------|
| `ArchLogo` | Distro pill, brand accent |
| `Workspaces` | Live Hyprland workspaces, segmented control |
| `Clock` | Center time, click opens the clock card, right-click toggles long format |
| `Cpu`, `Memory`, `Temp` | Usage pills, click opens the system monitor |
| `Network` | Wi-Fi/Ethernet pill, click opens the wifi panel |
| `Battery` | Charge pill with warning/critical states, click opens the battery panel |
| `WatchCat` | Hotspot down-rate pill, click opens the watchdog panel |
| `Tray` | System tray container |
| `StatusPill` | One pill consolidating idle, DND, recording, and tray transient states |
| `BellButton` | Notification bell with unread badge |
| `NowPlaying` | Track art, title/artist, live cava spectrum, hover transport |

### Panels and windows

Overlays are `PanelWindow` layer-shell popups. Larger tools are regular Hyprland `FloatingWindow`s with matching float/center/size rules. Every panel closes on `Esc`.

| Module | Role | How it opens |
|--------|------|--------------|
| `WifiPanel` | Network manager, known networks, live throughput graph, Cloudflare speedtest | `SUPER+H`, network pill |
| `SystemMonitor` | Per-core CPU, RAM, network, process list with kill | `SUPER+U`, cpu/memory pills |
| `BatteryPanel` | Charge curve, power profile, time estimates | `SUPER ALT+B`, battery pill |
| `NotificationCenter` | Notification drawer, history, DND toggle | `SUPER+,` |
| `ControlCenter` | Bento grid: Now Playing, weather, quick toggles, network, activity, live cava visualizer | `SUPER ALT+P` |
| `AppLauncher` | Spotlight-style launcher, wheel scroll | `SUPER+Space` |
| `PkgManager` | pacman + AUR search, queue, install progress, updates | `SUPER+I` |
| `PdfViewer` | PDF/EPUB library: recents, favorites, full-text search, Zathura handoff | `SUPER ALT+N`, `utpdf <file>` |
| `Wallshelf` | Wallhaven storefront: browse, bulk download, set-as-wallpaper | `SUPER CTRL+Space` |
| `ThemePanel` | Wallpaper slideshow with preview, applies via `set-wallpaper` | `SUPER+E` |
| `PowerMenu` | Lock, logout, suspend, reboot, shutdown | `SUPER+Escape` |
| `ClipboardPanel` | Clipboard manager (Hyprland window): history with image previews (cliphist backend) plus a Sticky shelf of pinned snippets in LocalStorage, fired with `SUPER ALT 1-9` | `SUPER CTRL+V` (window), `SUPER CTRL+P` (pin current clipboard from anywhere) |
| `KeybindsPanel` | Searchable, executable keybind cheatsheet | `SUPER+K` |
| `FastFetchWindow` | System info card | `SUPER+N` |
| `ScreenTime` | App-usage heatmap and top apps, Go daemon backend | `SUPER ALT+T`, launcher |
| `DriveHealth` | SMART health, disk space, throughput, speed test | `SUPER ALT+D`, launcher |
| `WorkspaceViewer` | Fullscreen overview of every workspace with live windows | `SUPER ALT+O` |
| `MonitorSettings` | Scale/orientation picker, whole-pixel warnings, persistent apply | launcher |
| `Earbuds` | Headset battery rings from bluetoothctl and UPower | `SUPER ALT+E` |
| `Bluetooth` | Adapter power, scan, pair/connect/disconnect | launcher |
| `Pomodoro` | Focus timer: phases, durations, session stats | `SUPER ALT+C`, launcher |
| `GitHubDash` | Heatmap, inbox, PRs, running actions | launcher |
| `Dictionary` | Definitions, IPA, audio, Datamuse related words | launcher |
| `Grap` | Instant ripgrep search across the home dir | launcher |
| `FailWatch` | Failed units, OOM/segfault alerts, `pacman -Qkk` | launcher |
| `ClockWindow` | Detached clock card | bar clock click |
| `MediaOsd` | Volume/brightness/mic overlay | Fn keys |
| `PassPrompt` | System password prompt (`SUDO_ASKPASS` backend) | privileged panel actions |

Unwired but still on disk: `QuickNotes` (scratch idea capture; nothing instantiates it, so its `notes` target is never served and the panel never opens) . `NetRate` and `WeatherIcon` are shared helpers, not surfaces. If you rewire an unwired file, update `PLUGINS.md` and the cheatsheet entry with it.

`PLUGINS.md` is the registry of every module, its IPC target, and its bind. Keep both current when you change a module.

## Notifications

The shell is its own notification daemon. Toasts carry action buttons, screenshot notifications carry a Save button that files the image into `~/Pictures/Screenshots`, and everything lands in the history drawer. When an app ships no icon, the row falls back to a per-app Phosphor glyph (40+ apps mapped, from Firefox down to `brightnessctl` and `grim`), so rows never show bare initial letters. `notify-send -a <AppName>` is all a sender needs for a correct icon.

## Screen time

The `screentime` Go daemon (separate checkout at `~/projects/screentime`, also runs as a user service) samples the focused window every 10 seconds into SQLite. `ScreenTime.qml` renders the heatmap and top apps from `screentime --export all`, and the control center activity bars read the same export. One source, both views agree.

## Companion repos

These live outside this repo but plug into the shell:

| Repo | What it is |
|------|------------|
| `~/projects/screentime` | Screen time Go daemon + SQLite store |
| `github.com/codetesla51/qemu-launch` | Bubble Tea QEMU launcher: ISOs from `~/Downloads`, per-VM store in `~/VMs` |

## WatchCat

Hotspot data watchdog for tethered laptops. Tracks every byte against a daily 1 GB cap. Notify-only: it never pauses or blocks traffic.

```bash
# daemon: nethogs per-process rates into sqlite plus live.json, 24/7
systemctl --user enable --now watchcat.service

# dashboard: static HTML regenerated from the database (auto-reloads every 30s)
python3 ~/.config/quickshell/scripts/watchcat-dash.py <out.html> 1024
```

The daemon samples in 12s chunks, flags "hot" processes (over 500 KB/s for 10s+), and warns at 500 MB and 1 GB via `notify-send`. History prunes to 7 days. Sudo is scoped to exactly one command in `/etc/sudoers.d/watchcat` (passwordless `nethogs`, nothing else).

## FailWatch

Silent-failure watchdog: failed systemd units (system + user scope) and high-signal journal events (OOM kills, segfaults, kernel oops, failed starts). Notify-only — alerts land in the notification center; the panel adds an on-demand `pacman -Qkk` package-integrity check.

```bash
systemctl --user enable --now failwatch.service
```

The daemon seeds its journal cursor on first run (no backlog spam), dedupes repeat events, and keeps a rolling 7-day history in `~/.local/share/failwatch/events.db`. The bar pill shows live state (`FW ok` / `FW n` / `FW ?`); the panel (launcher → FailWatch, no chord) gives every row its log id — failed units via `journalctl -u`, journal events via `--after-cursor=…`.

## Keybinds

`SUPER+K` opens the searchable cheatsheet. The same list is executable from there. Essentials:

| Keys | Action |
|------|--------|
| `SUPER+Space` / `SUPER+K` | Launcher / keybind cheatsheet |
| `SUPER+Return`, `SUPER SHIFT+F` | Terminal, file manager |
| `SUPER+H` / `SUPER+U` / `SUPER ALT+B` | Wi-Fi panel / system monitor / battery panel |
| `SUPER+E` / `SUPER+I` / `SUPER ALT+N` | Theme / packages / PDF library |
| `SUPER CTRL+Space` | Wallpaper store |
| `SUPER ALT+P` / `T` / `K` / `D` / `Y` | Control center / screen time / phone / drives / WatchCat |
| `SUPER ALT+C` / `E` | Pomodoro / earbuds |
| `SUPER ALT+O` / `SUPER+,` | Workspace overview / notification center |
| `SUPER+,` / `SUPER SHIFT+,` | Notifications / do-not-disturb |
| `SUPER CTRL+V` / `SUPER CTRL+P` / `SUPER+N` | Clipboard window / pin clipboard to sticky shelf / system info |
| `SUPER ALT+Space` / `SUPER SHIFT+Space` | Island style / bar sides |
| `SUPER+Escape` / `SUPER SHIFT+Q` | Power menu / shutdown (reboot lives in the power menu) |
| `SUPER+arrows`, `SUPER+1-0` | Focus, workspaces |
| Fn row | Volume/brightness/mic via the quickshell OSD |

The full list lives in `.config/hypr/bindings.lua`. Every panel also closes on `Esc`.

> In the Lua API every modifier needs its own `+` — `"SUPER + SHIFT + F"`, not
> the old `.conf` `"SUPER SHIFT, F"`. `hl.bind` rejects the space-separated form
> with `Unknown keysym: "SUPER SHIFT", did you forget a +?`, and it fails loudly
> at every chord rather than once, so a ported file is usually a wall of that
> same line until every modifier is fixed.

## Helper scripts

`~/.local/bin/` (stowed from this repo) holds the CLI surface: `set-wallpaper`, `getTheme`, `shot`, `record`, `utpdf`, `vol`, `bright`, `nightlight`, `lock`, `qemu-launch`, and more. These are what binds, panels, and muscle memory call.

## Tools

What runs the desktop day to day, and where each piece lives:

| Tool | Job | Wiring |
|------|-----|--------|
| `awww` | Wallpaper daemon + transitions | `autostart.conf` launches the daemon; `set-wallpaper` switches with a 0.7s `wave` (instant `none` at login) |
| `matugen` + `matugen-cursor` | Theme colors + matching cursor | `getTheme` regenerates on wallpaper switch; cursor round-trips through Bibata so Hyprland drops its cache — no logout needed |
| `atuin` | Shell history (SQLite, per-directory smart) | `eval "$(atuin init zsh)"` last in `.zshrc`, owns `Ctrl+R`; fully offline, `atuin register` for sync |
| `shell-splash` | 技 terminal greeting | `.zshrc` runs it for the outermost shell only; braille art dissolves in with a rice gradient re-read from `colors.conf` every launch |
| `fastfetch` | System info with the 技 logo | `config.jsonc` points at `kanji.txt` (gradient baked from the current rice) |
| `chafa` + PIL | Art pipeline behind the splash/logo | 技 rendered from Noto CJK → alpha-mask → braille; Hollow Knight mask baked solid-white for the launcher rail |
| `hyprlock` | Screen lock | `hypridle` + `SUPER+L`; fade entrance, pill input, mask art configurable in `hyprlock.conf` |
| `quickshell` | Bar, island, all panels | `shell.qml` root; bar popups lazy-load (battery stays resident); registry in `PLUGINS.md`, rules in `AGENTS.md` |

## Structure

```
~/dotfiles/
├── .config/
│   ├── default/hypr/
│   │   └── autostart.lua     # shadows Omarchy's, minus omarchy-launch-shell
│   ├── hypr/                 # Hyprland: personal overrides, all Lua
│   │   ├── hyprland.lua      # bootstrap + require order
│   │   ├── bindings.lua      # every keybind (cheatsheet reads this)
│   │   ├── windows.lua       # float/center/size for each quickshell window
│   │   ├── looknfeel.lua     # gaps, blur, shadows, animations, layer rules
│   │   ├── theme.lua         # matugen palette -> border colours
│   │   ├── monitors.lua / input.lua / autostart.lua / envs.lua
│   │   └── hypridle.conf / hyprlock.conf / hyprsunset.conf   # separate apps, still .conf
│   │   (no vendor/ — Omarchy ships its defaults as Lua under
│   │    $OMARCHY_PATH and they are loaded, not frozen copies)
│   ├── quickshell/           # desktop shell (see module tables above)
│   │   ├── shell.qml         # root: bar + standalone windows + shared palette
│   │   ├── components/       # Bar.qml, Colors.qml
│   │   ├── modules/          # 55 feature files
│   │   ├── scripts/          # temperature.sh, watchcat daemon + dashboard, idle helpers
│   │   ├── colors.css        # generated by matugen, polled live, do not hand-edit
│   │   ├── PLUGINS.md        # module registry: IPC target + bind per module
│   │   └── AGENTS.md         # contributor rules for this codebase (read before editing)
│   ├── matugen/              # config.toml + templates (btop, gtk, rofi, nvim, zed, zathura, …)
│   ├── foot/foot.ini         # sources theme/current/foot.ini
│   ├── systemd/user/         # helper services
├── .local/bin/             # set-wallpaper, getTheme, record, shot, …
├── sddm/elarun-custom/     # optional login theme; NOT installed by default
├── zen/app-userChrome.css  # chromeless window CSS for zenapp web apps
├── wallpapers/             # local only, git-ignored, never committed
├── assets/                 # vendored blobs + README screenshots (stow-ignored)
├── theme-fallback/         # static snow_black seed
├── .zshrc                  # zsh + lsd/zoxide/fzf/starship/mise
├── .stow-local-ignore
└── install.sh
```

`AGENTS.md` inside `.config/quickshell/` is the contributor contract for the shell: canonical IPC path, panel vs pill vs card patterns, the Amber Bento style tokens, and the verification loop. Read it before touching any `.qml` file.

## Customizing

* Keybinds: `.config/hypr/bindings.lua` (panel Binds page edits this file, Hyprland reloads it)
* Look and feel: `.config/hypr/looknfeel.lua`. Border colours are not set there — they come from the wallpaper via `theme.lua`, and the palette is regenerated, not edited
* Bar and modules: `.config/quickshell/modules/*.qml`, then restart quickshell (never trust hot reload for verdicts)
* New theme template: add it under `.config/matugen/templates/`, map it in `config.toml`, run `matugen image` once
* Terminal: `.config/foot/foot.ini` for font and behavior. Colors always come from the generated files

## Gotchas

* **`xdph.conf` is gone and cannot come back as-is.** It set
  `screencopy { allow_token_by_default = true, custom_picker_binary = ... }`.
  Under Lua there is no `source`, nothing loads a stray `xdph.conf`, `hl.config`
  rejects both keys, and there is no `hl.eval` or `hl.keyword` to set them at
  runtime. Omarchy does not set them either, so the interactive share picker is
  simply unavailable. Everything else in that file was the default anyway.
* **`loginctl lock-session` is a no-op without a session-lock client.** It only
  forwards a request to whichever process holds the session lock, and nothing
  does when the session goes idle. `hypridle.conf` launches `hyprlock` directly
  instead — including for `before_sleep_cmd`, which had the same latent bug.
* The Quickshell owns the notification bus. If toasts stop appearing, something grabbed `org.freedesktop.Notifications` first — usually `swaync`, or a stray `omarchy-shell` that was started before the shadow took effect. Check with `busctl --user status org.freedesktop.Notifications | grep PID`.
* Generated files are not source. `colors.css`, `zathurarc`, `cava/config`, `theme/colors.lua`, and everything under `theme/current/` get overwritten by matugen. Edit the template, never the output.
* `getTheme` verifies its own output rather than trusting matugen's exit code, because matugen exits non-zero if *any* output is unwritable. Keep every template output inside `~/.config`.
* Nerd Font codepoints drift between font builds. A glyph that exists can still render as the wrong symbol. Verify by glyph name with fontTools, not by codepoint presence. Same goes for Phosphor icons: this repo's build is ligature-mapped, so codepoints were resolved through its GSUB table.
* `wallshelf.ini` holds the Wallhaven API key and is gitignored on purpose. Never move the key into `wallshelf.json` (tracked).
* The tree is usually dirty. Theme outputs regenerate on every wallpaper change, so `git status` almost always shows modifications. That is normal. Commit only your own files.
* No boot-menu snapshot entries. Snapper timelines run hourly, but recovery is manual (see below), not a Limine menu.

## Disaster recovery (snapper)

Omarchy's own recovery layout, for the record:

- `nvme0n1p1` → `/boot` (vfat), `nvme0n1p2` → LUKS → btrfs. **Root is encrypted.**
- Subvolumes: `@` (`/`), `@home`, `@log` (`/var/log`), `@pkg` (`/var/cache/pacman/pkg`).
- Snapper config `root`: `SUBVOLUME="/"`, **5 snapshots, no timeline** — Omarchy
  only snapshots for pre-update recovery, it does not run hourly. `snapper list`
  will usually be nearly empty; that is expected, not a fault.

Most breakages (bad update, nuked `/etc` file, dead Hypr config) still reach a TTY. Log in as root there and roll back. No USB needed:

```bash
snapper list                          # pick a number from before the breakage
snapper rollback 80
reboot
```

A USB stick with an Arch ISO is only needed when nothing boots at all: kernel
panic, no login prompt. On this setup that means a bad kernel + initramfs after
an interrupted update, a broken `mkinitcpio.conf` (check HOOKS before every
`mkinitcpio -P`), a full `/` partition (snapshots live on it too), a bad
`/etc/fstab` line, or a damaged `/boot`. Because root is LUKS, the ISO needs
the passphrase before anything else:

```bash
# from the ISO:
cryptsetup open /dev/nvme0n1p2 root
mount -o subvol=@ /dev/mapper/root /mnt
arch-chroot /mnt
snapper list
snapper rollback 80
reboot
```

`@home`/`@log`/`@pkg` are separate subvolumes, so rollback never touches your
files, logs, or package cache. Snapper keeps the broken `@` as a backup, so a
bad rollback is itself reversible.

Day-to-day (no reboot involved):

```bash
snapper create -d "before i break things"
snapper undochange 82..0 /etc          # un-break one directory
snapper status 82..0                  # preview what changed first
```

## Locked out (passwords, login, screen lock)

Three ladders, in order. `nvme0n1p2` **is LUKS-encrypted**, so this needs
updating: a forgotten password is no longer merely an inconvenience, because
booting an ISO now also requires the disk passphrase. Keep it somewhere you can
reach. If you have the passphrase, there is no scenario where snapshots can't
reach your files.

**Ladder 1: a TTY.** `CTRL ALT F3` through `F6` (SDDM owns `tty1`, so do not fight it there). Log in as your user or as root and fix it directly:

```bash
passwd justin                  # forgotten user password (as root)
pkill -x hyprlock              # stuck at the hyprlock screen
snapper rollback 80            # broke it with an update, see above
```

SDDM login-looping but the TTY works almost always means the Hyprland session dies on start: check `~/.config/hypr/` for the last edit and `journalctl --user -xe` for the crash line before rolling anything back.

**Ladder 2: no TTY at all, or both passwords lost.** Boot an Arch ISO. `sudo` on this machine requires a password (no `NOPASSWD` backdoor outside the scoped `nethogs` rule), so if no password works anywhere, the ISO is the backstop, not a trick:

```bash
# from the ISO. LUKS first -- nothing below works until this is done.
cryptsetup open /dev/nvme0n1p2 root
mount -o subvol=@  /dev/mapper/root /mnt
mount -o subvol=@home /dev/mapper/root /mnt/home
arch-chroot /mnt
passwd justin                  # or: snapper list + snapper rollback 80
reboot
```

`@home` is a separate subvolume, so even a full `@` rollback never touches your files. If you only need one file back, mount `@home` and copy it to a USB stick without chrooting at all.

If the passphrase is the thing you lost, none of the ladders help — that is the
one failure mode LUKS introduces, and it is why the passphrase needs to live
outside this machine.

**Know before it happens.** Root TTY login needs the root password; if root was never given one (locked `!` account), Ladder 1's `passwd` path doesn't exist and you go straight to Ladder 2. Worth verifying now, while nothing is broken: `sudo passwd -S root` should not report `L`.
