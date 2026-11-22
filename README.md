# dotfiles

A standalone Arch Linux desktop built on Hyprland, Quickshell, and Matugen.
The wallpaper produces one Material You palette, and every surface follows:
bar, panels, OSD, notifications, terminals, editors, browser chrome, and the
cursor. No Omarchy packages are required.

![Desktop](assets/screenshots/desktop.png)

Bar island, Zathura and foot over a wallpaper-pulled palette.

> Reinstalling the whole machine? [ARCH-INSTALL.md](ARCH-INSTALL.md) covers the
> backup, archinstall, Limine and bootable snapshots, package restore, and
> first-login sequence. The steps below assume Arch is already installed.

## What you get

| Piece | What it does |
|-------|--------------|
| **Hyprland** | Tiling compositor with a Lua config under `~/.config/hypr` |
| **Quickshell** | The whole desktop shell: bar, launcher, panels, OSD, notification daemon |
| **Matugen** | One image to every app's palette, with matching cursor |
| **Hyprlock / Hypridle** | Lock screen and idle handling |
| **awww** | Wallpaper daemon with animated transitions |
| **Theme files** | Live palette in `~/.config/theme/current`, snapshots in `theme/themes` |

Feature highlights:

* **One palette everywhere.** `getTheme` recolors Hyprland borders, Quickshell,
  foot/kitty, btop, cava, rofi, GTK, Zed, Neovim, Zathura, Zen, and the cursor
  in a single pass.
* **A real shell.** Bar islands, a Spotlight-style launcher, Wi-Fi/Bluetooth,
  battery, package manager, control center, clipboard, PDF library, wallpaper
  store, workspace overview, screen time, drive health, and a searchable
  executable keybind cheatsheet.
* **Touchpad edge motion.** Drags continue past the physical edge of the pad.
* **Screenshot pipeline.** Drag, pretty (rounded + blurred backdrop), full, and
  OCR capture, all on letter chords instead of `Print`.
* **Laptop-aware.** Touchpad and internal-display toggles persist across
  Hyprland reloads; the lid switch is wired to the display helper.
* **Low-battery warnings.** `battery-watch` runs as a user service and warns at
  20%, 10%, and 5%.

## Requirements

* Arch Linux (x86_64) with a working network connection.
* A non-root user with `sudo`.
* Hyprland 0.56 or newer with the Lua config API, and Quickshell 0.3.2 or
  newer. Both are in the official `extra` repository.
* A supported GPU. The shipped blur/gap settings are tuned for an Intel HD 520
  at 1366x768; raise `decoration.blur` values in `looknfeel.lua` on stronger
  hardware.
* Disk encryption, Secure Boot, and the bootloader are outside this repo. The
  full reinstall sequence, including LUKS, Limine, and bootable snapshots, is in
  `ARCH-INSTALL.md`.

## Install on Arch

### 1. Install the base desktop

From a fresh Arch install, as your normal user:

```bash
sudo pacman -S --needed base-devel git sudo hyprland quickshell foot \
     pipewire pipewire-pulse wireplumber networkmanager bluez bluez-utils \
     polkit xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
     noto-fonts noto-fonts-emoji ttf-jetbrains-mono-nerd ttf-firacode-nerd \
     neovim mpv zsh
```

Optional but recommended:

```bash
sudo pacman -S --needed sof-firmware alsa-ucm-conf linux-firmware
```

If you followed `ARCH-INSTALL.md`, the 188-package restore already covers this;
skip to step 2.

`uwsm` is optional. Every launcher in this repo checks for `uwsm-app` and runs
the command directly when it is absent.

### 2. Clone at `~/dotfiles`

The repo ships relative theme symlinks that resolve from `~/dotfiles` into
`~/.config/theme`, so use this exact path:

```bash
git clone --branch arch-ready https://github.com/DevJustinTech/uthman_dotfiles.git ~/dotfiles
cd ~/dotfiles
```

### 3. Run the installer

```bash
./install.sh
```

It is safe to re-run. Existing files that are not owned by Stow are copied to
`~/.config-backup-<timestamp>` before being replaced.

The installer:

1. Checks every required package and offers one `pacman -S` command for what is
   missing.
2. Creates `~/.config/theme/current` and `~/.config/theme/themes/snow_black`,
   and copies the static fallback palette so the first login works before any
   wallpaper has been processed.
3. Stows every tracked dotfile into `$HOME`, backing up conflicts first, and
   offers to make zsh your login shell.
4. Optionally runs `getTheme` on a wallpaper you choose.
5. Links the bundled Bibata cursor base, installs the Inter font used by the UI
   and SDDM, and installs the optional `sddm/elarun-custom` login theme.
6. Offers one-time system setup for touchpad edge motion and WatchCat.
7. Enables `battery-watch`, `failwatch`, `bt-agent`, and any of
   `edge-motion` / `watchcat` whose prerequisites were installed.

### 4. Start the session

Log out and log back in, or start Hyprland from a TTY:

```bash
Hyprland
```

If you use a display manager, pick the Hyprland session. SDDM is optional; the
installer configures the bundled theme when `/usr/share/sddm` exists.

### 5. Apply a wallpaper

```bash
getTheme ~/Pictures/your-wallpaper.jpg
```

or pick one from the bundled store:

```bash
set-wallpaper ~/Pictures/your-wallpaper.jpg
```

`SUPER+E` opens the wallpaper/theme panel, and `SUPER+CTRL+SPACE` opens the
Wallhaven storefront (needs a free API key in `~/.config/quickshell/wallshelf.ini`).

### Optional applications

These are wired into keybinds but not required for the desktop to start:

```bash
# Official repos
sudo pacman -S --needed tmux zathura zathura-pdf-poppler obsidian zed \
     tesseract pacman-contrib hyprpicker gpu-screen-recorder nethogs \
     smartmontools imv kitty foliate sushi

# AUR (install an AUR helper first, e.g. yay)
yay -S zen-browser-bin spotify herdr python-terminaltexteffects \
       python-curl-cffi-git ttfx
```

* `zen` — browser used by the app keybinds and web apps.
* `spotify` — `SUPER+SHIFT+M`.
* `zed` — `SUPER+SHIFT+N`. `getTheme` writes its palette; Zed only reads theme
  files at startup, so re-select Matugen after a wallpaper change.
* `herdr` — TUI used by `SUPER+CTRL+RETURN` and the Herdr keybind list. It is
  not in the official Arch repos; the desktop works without it.
* `zathura` — opened by the PDF library.
* `tesseract` — required for OCR capture (`SUPER+SHIFT+T`).
* `hyprpicker` — colour picker in the capture menu (`SUPER+CTRL+C`).
* `gpu-screen-recorder` or `wf-recorder` — `SUPER+R` screen recording.
* `nethogs` — required by the optional WatchCat watchdog; the installer can
  add the scoped sudo rule for you.
* `python-terminaltexteffects` (AUR, provides `tte`) — terminal-art idle
  screensaver after 10 minutes. Without it, `launch-screensaver` exits
  quietly and only the lock listener runs.
* `smartmontools` — full SMART attributes in the drive-health panel.
* `imv` — dedicated image viewer for notification previews.
* `kitty` — alternative terminal; the repo ships its config and tab bar, but
  foot is the default.
* `foliate` — opens books from the PDF library; it falls back to `xdg-open`.
* `python-curl-cffi-git` (AUR) — BookStore's Anna's Archive fetcher; the rest
  of the panel works without it.
* `sushi` — Nautilus-style file previewer in the app menu.
* `ttfx` (AUR) — ASCII text-effects toy in the app menu.

## Paths that matter

| Path | Purpose |
|------|---------|
| `~/.config/hypr/hyprland.lua` | Entry point: vendor defaults, then personal overrides |
| `~/.config/hypr/vendor/` | Standalone copies of the compositor defaults (no `/usr/share` dependency) |
| `~/.config/theme/current/` | Live generated theme files |
| `~/.config/theme/colors.lua` | Palette consumed by Hyprland |
| `~/.config/theme/themes/snow_black/` | Snapshot of the last generated theme |
| `~/.config/quickshell/colors.css` | Palette polled by the shell |
| `~/.local/state/hypr/` | Persisted touchpad and internal-display state |

Everything Matugen writes lives under `~/.config` on purpose. Matugen aborts
the whole run when any output is unwritable, so a root-owned destination would
make every wallpaper change look like a total failure. SDDM is the one static
exception; see below.

## Login screen

SDDM is optional. The bundled `sddm/elarun-custom` theme is installed by
`install.sh` when `/usr/share/sddm` exists, and pointed at through
`/etc/sddm.conf.d/10-theme.conf`.

The login palette is static (`Palette.qml`), because `/usr/share` is root-owned
and updating it on every wallpaper change would prompt for a password each
time. Edit that file if you want a different login accent.

## Coming from Omarchy

The desktop no longer reads `/usr/share/omarchy`, `~/.config/omarchy`, or any
`omarchy-*` command. The old compatibility paths have been removed:

* Hyprland defaults are vendored under `~/.config/hypr/vendor` instead of being
  required from `/usr/share/omarchy/default/hypr`.
* The shell is launched directly with `quickshell -p ~/.config/quickshell`.
* Theme outputs go only to `~/.config/theme`.
* `omarchy-shell`, `omarchy-shadow-check`, and the `omarchy-sleep-lock`
  drop-in are gone.
* Touchpad, monitor, keybind-list, and window helpers are local scripts under
  `~/.local/bin`.

If you migrate an existing Omarchy install, run the installer once and log out;
Stow backs up any conflicting files rather than deleting them.

## Updating

```bash
cd ~/dotfiles
git pull
./install.sh
```

The installer is idempotent. Restart the shell after QML changes with
`SUPER+HOME`; Hyprland config changes reload with the same chord.

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

That one command does four things in order:

1. Symlinks the image to `~/.config/theme/current/background`, which is what everything else treats as "current wallpaper".
2. Keeps a static copy at `background-static.jpg` for `hyprlock`, which cannot animate a GIF.
3. Hands it to `awww` (or `swww`) for a 0.7s wave transition, so the change is visible before any color moves.
4. Calls `getTheme`, which runs `matugen image` to build a Material You palette and regenerates the cursor theme through `matugen-cursor`.

Matugen then writes 33 output files from 20 templates, one file per app per destination. Nothing is copied or converted afterward. The shell notices on its own within a second.

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
`~/.config/hypr/theme.lua` reads `~/.config/theme/colors.lua` with `dofile()`
and applies the returned table to border colours.

> The file is read fresh on every Hyprland reload. A missing file is not fatal:
> `theme.lua` falls back to neutral border colours, so the first login works
> before any wallpaper has been processed.

### Where the generated files land

| Destination | Who reads it |
|-------------|--------------|
| `~/.config/quickshell/colors.css` | the shell, polled every second |
| `~/.config/theme/colors.lua` | `hyprland/theme.lua` via `dofile()` |
| `~/.config/theme/current/colors.conf` | shell helpers (`matugen-cursor`, `shell-splash`) |
| `~/.config/theme/current/` | live config for every other app, rewritten each wallpaper change |
| `~/.config/theme/themes/snow_black/` | named snapshot; grows over time and is safe to delete |
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
| Windows, keys, blur, gaps | `~/.config/hypr/*.lua` | Lua; vendored defaults load first, personal overrides after; `bindings.lua` unbinds the chords it replaces |
| Everything drawn | `~/.config/quickshell/` | 56 modules, one palette object shared by all of them |
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
| `firefox` | `theme/current/firefox.css` and `zen.css`, concatenated into Zen's `userChrome.css`; `zen-usercontent.css` becomes `userContent.css` |
| `rofi`, `neovim`, `zed`, `zathura` | per-app live outputs (`zed` goes through `theme/current/matugen-base.json`) |

Active colors live in `~/.config/theme/current/` and are rewritten on every run. `snow_black/` keeps saved snapshots, `theme-fallback/` ships the static seed.

> [!TIP]
> `Colors.qml` polls `~/.config/quickshell/colors.css` every second. Matugen replaces the file (new inode) instead of editing it, so the poller re-reads rather than watching. Palette swaps propagate with no restart.

> [!WARNING]
> Always run full `matugen image` with the same wallpaper source when you mean "refresh". Running it against a different image silently re-palettes all outputs at once. Generated outputs are gitignored, so `git status` in `~/dotfiles` should stay clean after a regen.

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
> This quickshell daemon owns `org.freedesktop.Notifications`. Any other
> notification daemon (`swaync`, `mako`, `dunst`) must stay masked, and only one
> copy of this shell may run. To confirm which process holds the bus:
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
| `ClipboardPanel` | Clipboard manager (Hyprland window): history with image previews (cliphist backend) plus a Sticky shelf of pinned snippets in LocalStorage, fired with `SUPER ALT 1-9` | `SUPER CTRL+V` (window), `SUPER CTRL+J` (pin current clipboard from anywhere) |
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

### Liquid glass mode

An optional material for the surfaces that float over the wallpaper. Off by default — the warm classic fills are untouched, and flipping it either way is instant.

* Toggle: `SUPER ALT J`, the **Liquid glass** tile in Control Center, or the pill in the Theme editor (`SUPER ALT+H`).
* The Theme editor's **SURFACE** row carries two tint sliders: **L** for light themes, **D** for dark. `1.0` is the designed tint; below it the fill and the compositor's brightness lift thin together, above it they deepen. Each theme remembers its own value.
* `~/.local/bin/glass-apply` swaps the Hyprland blur recipe (`passes`/`size` stay pinned for the HD 520; only brightness/vibrancy/contrast move). `getTheme` re-runs it after every wallpaper or theme change.
* Density and ink come from `scripts/glass-sample.py`. It covers the monitor with the wallpaper, samples a 5×3 grid under each surface, drops the extremes, and writes `~/.cache/quickshell/glass-sample.json`; density rises until the chosen ink clears 4.5:1. Light themes flip to light ink only on surfaces whose text is fully wired (currently toasts); everything else keeps theme ink on white glass rather than risking dark-on-dark.
* `glass-check` prints what the sampler decided and flags any surface under 4.5:1.
* Left solid on purpose: ThemePanel (it paints its own blurred wallpaper inside the card), the Now Playing hover card (album art is the tint), bar pills and menus (they sit on the glass island, not the wallpaper), the pet, GTK apps, SDDM and hyprlock.

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

The daemon seeds its journal cursor on first run (no backlog spam), dedupes repeat events, and keeps a rolling 7-day history in `~/.local/share/failwatch/events.db`. The panel (launcher → FailWatch, no chord) gives every row its log id — failed units via `journalctl -u`, journal events via `--after-cursor=…`.

## Keybinds

`SUPER+K` opens the searchable cheatsheet. The same list is executable from there. Essentials:

| Keys | Action |
|------|--------|
| `SUPER+Space` / `SUPER+K` | Launcher / keybind cheatsheet |
| `SUPER+Return`, `SUPER ALT SHIFT+F` | Terminal, file manager |
| `SUPER+H` / `SUPER+U` / `SUPER ALT+B` | Wi-Fi panel / system monitor / battery panel |
| `SUPER+E` / `SUPER+I` / `SUPER ALT+N` | Theme / packages / PDF library |
| `SUPER CTRL+Space` | Wallpaper store |
| `SUPER ALT+P` / `T` / `K` / `D` / `Y` | Control center / screen time / tmux keys / drives / WatchCat |
| `SUPER ALT+C` / `E` | Pomodoro / earbuds |
| `SUPER ALT+O` | Workspace overview |
| `SUPER+,` / `SUPER SHIFT+,` | Notifications / do-not-disturb |
| `SUPER CTRL+V` / `SUPER CTRL+J` / `SUPER+N` | Clipboard window / pin clipboard to sticky shelf / system info |
| `SUPER ALT+Space` / `SUPER SHIFT+Space` | Island style / bar sides |
| `SUPER ALT+J` | Liquid glass on/off |
| `SUPER+Escape` / `SUPER SHIFT+Q` | Power menu / shutdown (reboot lives in the power menu) |
| `SUPER+arrows`, `SUPER+1-0` | Focus, workspaces |
| Fn row | Volume/brightness/mic via the quickshell OSD |

The full list lives in `.config/hypr/bindings.lua` plus the vendored defaults in `.config/hypr/vendor/bindings/`. Every panel also closes on `Esc`.

> In the Lua API every modifier needs its own `+` — `"SUPER + SHIFT + F"`, not
> the old `.conf` `"SUPER SHIFT, F"`. `hl.bind` rejects the space-separated form
> with `Unknown keysym: "SUPER SHIFT", did you forget a +?`, and it fails loudly
> at every chord rather than once, so a ported file is usually a wall of that
> same line until every modifier is fixed.

## Helper scripts

`~/.local/bin/` (stowed from this repo) holds the CLI surface: `set-wallpaper`, `getTheme`, `shot`, `record`, `utpdf`, `vol`, `bright`, `nightlight`, `lock`, `glass-apply`, `glass-check`, and more. These are what binds, panels, and muscle memory call. The companion QEMU launcher lives in its own repo (see below).

## Tools

What runs the desktop day to day, and where each piece lives:

| Tool | Job | Wiring |
|------|-----|--------|
| `awww` | Wallpaper daemon + transitions | `autostart.lua` launches the daemon; `set-wallpaper` switches with a 0.7s `wave` (instant `none` at login) |
| `matugen` + `matugen-cursor` | Theme colors + matching cursor | `getTheme` regenerates on wallpaper switch; cursor round-trips through Bibata so Hyprland drops its cache — no logout needed |
| `atuin` | Shell history (SQLite, per-directory smart) | `eval "$(atuin init zsh)"` last in `.zshrc`, owns `Ctrl+R`; fully offline, `atuin register` for sync |
| `shell-splash` | 技 terminal greeting | `.zshrc` runs it for the outermost shell only; braille art dissolves in with a rice gradient re-read from `colors.lua` every launch |
| `fastfetch` | System info with the 技 logo | `config.jsonc` points at `kanji.txt` (gradient baked from the current rice) |
| `chafa` + PIL | Art pipeline behind the splash/logo | 技 rendered from Noto CJK → alpha-mask → braille; Hollow Knight mask baked solid-white for the launcher rail |
| `hyprlock` | Screen lock | `hypridle` + `SUPER+L`; fade entrance, pill input, mask art configurable in `hyprlock.conf` |
| `quickshell` | Bar, island, all panels | `shell.qml` root; bar popups lazy-load (battery stays resident); registry in `PLUGINS.md`, rules in `AGENTS.md` |

## Structure

```
~/dotfiles/
├── .config/
│   ├── hypr/                 # Hyprland: personal overrides, all Lua
│   │   ├── hyprland.lua      # entry point: vendor defaults, then overrides
│   │   ├── helpers.lua       # launch/bind helpers shared by config files
│   │   ├── bindings.lua      # every keybind (cheatsheet reads this)
│   │   ├── windows.lua       # float/center/size for each quickshell window
│   │   ├── looknfeel.lua     # gaps, blur, shadows, animations, layer rules
│   │   ├── theme.lua         # matugen palette -> border colours
│   │   ├── monitors.lua / input.lua / autostart.lua / envs.lua
│   │   ├── vendor/           # compositor defaults, vendored so nothing under
│   │   │                     # /usr/share is required at runtime
│   │   └── hypridle.conf / hyprlock.conf / hyprsunset.conf   # separate apps, still .conf
│   ├── quickshell/           # desktop shell (see module tables above)
│   │   ├── shell.qml         # root: bar + standalone windows + shared palette
│   │   ├── components/       # Bar.qml, Colors.qml
│   │   ├── modules/          # 56 feature files
│   │   ├── scripts/          # temperature.sh, watchcat daemon + dashboard, idle helpers
│   │   ├── colors.css        # generated by matugen, polled live, do not hand-edit
│   │   ├── PLUGINS.md        # module registry: IPC target + bind per module
│   │   └── AGENTS.md         # contributor rules for this codebase (read before editing)
│   ├── matugen/              # config.toml + templates (btop, gtk, rofi, nvim, zed, zathura, …)
│   ├── foot/foot.ini         # sources theme/current/foot.ini
│   ├── systemd/user/         # helper services
├── .local/bin/             # set-wallpaper, getTheme, record, shot, …
├── cursor-theme/           # Bibata base linked into ~/.local/share/icons
├── etc/
│   ├── systemd/system/     # drop-ins installed by install.sh (UID remapped)
│   └── udev/rules.d/       # touchpad rule installed by edge-motion-install
├── arch-packages/          # reinstall package lists (stow-ignored)
├── sddm/elarun-custom/     # login theme; installed when SDDM is present
├── zen/app-userChrome.css  # chromeless window CSS for zenapp web apps
├── wallpapers/             # local only, git-ignored, never committed
├── assets/                 # vendored blobs + README screenshots (stow-ignored)
├── theme-fallback/         # static snow_black seed
├── .zshrc                  # zsh + eza/zoxide/fzf/starship/atuin/mise
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
* The Quickshell owns the notification bus. If toasts stop appearing, something grabbed `org.freedesktop.Notifications` first — usually `swaync`, `mako`, `dunst`, or a stale copy of this shell. Check with `busctl --user status org.freedesktop.Notifications | grep PID`.
* Generated files are not source. `colors.css`, `zathurarc`, `cava/config`, `theme/colors.lua`, and everything under `theme/current/` get overwritten by matugen. Edit the template, never the output.
* `getTheme` verifies its own output rather than trusting matugen's exit code, because matugen exits non-zero if *any* output is unwritable. Keep every template output inside `~/.config`.
* Nerd Font codepoints drift between font builds. A glyph that exists can still render as the wrong symbol. Verify by glyph name with fontTools, not by codepoint presence. Same goes for Phosphor icons: this repo's build is ligature-mapped, so codepoints were resolved through its GSUB table.
* `wallshelf.ini` holds the Wallhaven API key and is gitignored on purpose. `wallshelf.json` is machine-local browse state (absolute paths, last category) and is gitignored too. Never put the key in either file.
* Generated files are gitignored. Theme outputs regenerate on every wallpaper change, so `git status` should stay clean; if it does not, you edited a generated file instead of its template.
* **Snapshots are bootable from the Limine menu** once `limine-snapper-sync` is
  wired up (see `ARCH-INSTALL.md`). `snap-pac` creates a pre/post snapshot on
  every pacman transaction. Snapshots cover `@`, not `@home`, and they do not
  replace backups.

## Disaster recovery (snapper)

The reinstall in `ARCH-INSTALL.md` produces this layout:

- `nvme0n1p1` → `/boot` (vfat), `nvme0n1p2` → LUKS → btrfs. **Root is encrypted.**
- Subvolumes: `@` (`/`), `@home`, `@log` (`/var/log`), `@pkg` (`/var/cache/pacman/pkg`).
- Snapper config `root`: `SUBVOLUME="/"`, no timeline, **5 snapshots**. `snap-pac`
  creates a pre/post pair on every pacman transaction, so `snapper list` should
  show the last few updates. Raise `NUMBER_LIMIT` for more history.

### Boot-menu recovery (first choice)

After a bad update, reboot. At Limine choose **Snapshots**, then the entry from
before the update. The snapshot boots read-only with a writable overlay; the
desktop offers **Restore now**, or run:

```bash
sudo limine-snapper-restore
```

Reboot into the restored system.

### TTY recovery (fallback)

If the Limine menu is intact but the snapshot entry will not boot, or you would
rather roll back manually, log in as root on a TTY. No USB needed:

```bash
snapper list                          # pick a number from before the breakage
snapper rollback <number>
reboot
```

### Rescue USB (last resort)

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
snapper rollback <number>
reboot
```

`@home`/`@log`/`@pkg` are separate subvolumes, so rollback never touches your
files, logs, or package cache. Snapper keeps the broken `@` as a backup, so a
bad rollback is itself reversible.

Day-to-day (no reboot involved):

```bash
snapper create -d "before i break things"
snapper undochange <number>..0 /etc    # un-break one directory
snapper status <number>..0            # preview what changed first
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
snapper rollback <number>      # broke it with an update, see above
```

SDDM login-looping but the TTY works almost always means the Hyprland session dies on start: check `~/.config/hypr/` for the last edit and `journalctl --user -xe` for the crash line before rolling anything back.

**Ladder 2: no TTY at all, or both passwords lost.** Boot an Arch ISO. `sudo` on this machine requires a password (no `NOPASSWD` backdoor outside the scoped `nethogs` rule), so if no password works anywhere, the ISO is the backstop, not a trick:

```bash
# from the ISO. LUKS first -- nothing below works until this is done.
cryptsetup open /dev/nvme0n1p2 root
mount -o subvol=@  /dev/mapper/root /mnt
mount -o subvol=@home /dev/mapper/root /mnt/home
arch-chroot /mnt
passwd justin                  # or: snapper list + snapper rollback <number>
reboot
```

`@home` is a separate subvolume, so even a full `@` rollback never touches your files. If you only need one file back, mount `@home` and copy it to a USB stick without chrooting at all.

If the passphrase is the thing you lost, none of the ladders help — that is the
one failure mode LUKS introduces, and it is why the passphrase needs to live
outside this machine.

**Know before it happens.** Root TTY login needs the root password; if root was never given one (locked `!` account), Ladder 1's `passwd` path doesn't exist and you go straight to Ladder 2. Worth verifying now, while nothing is broken: `sudo passwd -S root` should not report `L`.
