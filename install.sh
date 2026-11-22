#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# dotfiles install.sh
# Arch Linux · Hyprland · Matugen dynamic theming
#
# No Omarchy packages are required. Everything the desktop runs comes from the
# official Arch repositories plus this repository; optional extras (Herdr,
# Spotify, Zen) are called out where they are used.
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME_CURRENT="$HOME/.config/theme/current"
THEME_THEMES="$HOME/.config/theme/themes"

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${CYAN}  ${RESET} $*"; }
success() { echo -e "${GREEN}  ${RESET} $*"; }
warn()    { echo -e "${YELLOW}  ${RESET} $*"; }
die()     { echo -e "${RED}  ${RESET} $*" >&2; exit 1; }
header()  { echo -e "\n${BOLD}$*${RESET}"; }

# ── Step 0: Sanity checks ─────────────────────────────────────────────────────
header "Checking the environment..."

[[ -f /etc/arch-release ]] || die "This installer targets Arch Linux (no /etc/arch-release found)."
command -v pacman >/dev/null 2>&1 || die "pacman not found."

# Stow is needed before the dependency sweep can do anything useful, so install
# it up front rather than aborting on a clean system.
if ! command -v stow >/dev/null 2>&1; then
    info "GNU Stow is required; installing it..."
    sudo pacman -S --needed --noconfirm stow || die "Could not install stow."
fi

# The repo ships relative symlinks for btop/cava/gtk that resolve from
# ~/dotfiles into ~/.config/theme. Stow folds those directories, so the repo
# must live at ~/dotfiles for the links to point at the live theme directory.
if [[ "$DOTFILES_DIR" != "$HOME/dotfiles" ]]; then
    die "Clone the repo at ~/dotfiles (found: $DOTFILES_DIR).
       mv \"$DOTFILES_DIR\" ~/dotfiles && cd ~/dotfiles && ./install.sh"
fi

# ── Step 1: Check dependencies ────────────────────────────────────────────────
header "Checking dependencies..."

# package -> binary to probe. Packages without a matching binary use pacman -Q.
# Notifications are owned by the Quickshell shell, and the app launcher is the
# local rofi shim ~/.local/bin/walker-dmenu, so neither walker, mako nor swaync
# is needed.
declare -A PROBE=(
    [hyprland]=hyprctl
    [quickshell]=quickshell
    [foot]=foot
    [matugen]=matugen
    [starship]=starship
    [zsh]=zsh
    [eza]=eza
    [zoxide]=zoxide
    [fzf]=fzf
    [atuin]=atuin
    [mise]=mise
    [cava]=cava
    [btop]=btop
    [stow]=stow
    [hyprlock]=hyprlock
    [hypridle]=hypridle
    [hyprsunset]=hyprsunset
    [wl-clipboard]=wl-copy
    [cliphist]=cliphist
    [rofi]=rofi
    [thunar]=thunar
    [thunar-archive-plugin]=""
    [thunar-volman]=""
    [tumbler]=""
    [file-roller]=file-roller
    [catfish]=catfish
    [ffmpegthumbnailer]=ffmpegthumbnailer
    [poppler-glib]=""
    [grim]=grim
    [slurp]=slurp
    [jq]=jq
    [curl]=curl
    [neovim]=""
    [mpv]=""
    [fastfetch]=fastfetch
    [upower]=upower
    [xdg-utils]=xdg-open
    [playerctl]=playerctl
    [brightnessctl]=brightnessctl
    [libpulse]=pactl
    [python]=python3
    [udiskie]=udiskie
    [polkit-gnome]=""
    [fcitx5]=fcitx5
    [fcitx5-gtk]=""
    [fcitx5-qt]=""
    [libnotify]=notify-send
    [imagemagick]=magick
    [libvips]=vipsthumbnail
    [python-pillow]=""
    [tesseract]=tesseract
    [awww]=awww
    [inter-font]=""
    [ttf-jetbrains-mono-nerd]=""
    [ttf-firacode-nerd]=""
    [noto-fonts]=""
    [noto-fonts-emoji]=""
    [papirus-icon-theme]=""
    [pipewire]=pipewire
    [pipewire-pulse]=pipewire-pulse
    [wireplumber]=wireplumber
    [networkmanager]=nmcli
    [bluez]=""
    [bluez-utils]=bluetoothctl
    [bluez-tools]=bt-agent
    [polkit]=""
    [xdg-desktop-portal-hyprland]=""
    [xdg-desktop-portal-gtk]=""
)

# Optional programs: bindings exist, but the desktop still starts without them.
declare -A OPTIONAL=(
    [pacman-contrib]=checkupdates
    [tmux]=tmux
    [herdr]=herdr
    [zen-browser]=zen
    [spotify]=spotify
    [obsidian]=obsidian
    [zed]=zed
    [zathura]=zathura
    [zathura-pdf-poppler]=""
    [swaybg]=swaybg
    [gpu-screen-recorder]=""
    [wf-recorder]=""
    [hyprpicker]=hyprpicker
    [nethogs]=nethogs
    [python-terminaltexteffects]=tte
    [smartmontools]=smartctl
    [imv]=imv
    [kitty]=kitty
    [foliate]=foliate
    [sushi]=sushi
    [ttfx]=ttfx
)

MISSING=()
for pkg in "${!PROBE[@]}"; do
    probe=${PROBE[$pkg]}
    if [[ -n $probe ]]; then
        command -v "$probe" >/dev/null 2>&1 || MISSING+=("$pkg")
    else
        pacman -Q "$pkg" >/dev/null 2>&1 || MISSING+=("$pkg")
    fi
done

if ((${#MISSING[@]})); then
    mapfile -t MISSING < <(printf '%s\n' "${MISSING[@]}" | sort)
    warn "Missing packages: ${MISSING[*]}"
    echo ""
    echo "  Install them with:"
    echo -e "    ${BOLD}sudo pacman -S --needed ${MISSING[*]}${RESET}"
    echo ""
    read -rp "  Run that now? [Y/n] " install_deps
    if [[ ! ${install_deps:-Y} =~ ^[Nn]$ ]]; then
        sudo pacman -S --needed "${MISSING[@]}" || warn "Some packages failed to install; continuing."
    fi
else
    success "All required packages present"
fi

for pkg in "${!OPTIONAL[@]}"; do
    probe=${OPTIONAL[$pkg]}
    if [[ -n $probe ]]; then
        command -v "$probe" >/dev/null 2>&1 || warn "Optional: $pkg not installed"
    else
        pacman -Q "$pkg" >/dev/null 2>&1 || warn "Optional: $pkg not installed"
    fi
done

# ── Step 2: Create theme directories ──────────────────────────────────────────
header "Creating theme directories..."

mkdir -p "$THEME_CURRENT" "$THEME_THEMES/snow_black"
success "Created $THEME_CURRENT"

# ~/.local must already exist as a real dir before stow runs: if it does not,
# stow folds the whole tree into one symlink and ~/.local/share (Zed, mise,
# pip and node data) would be redirected into this repo. Same reasoning as the
# theme dirs above, which stop stow from folding .config.
mkdir -p "$HOME/.local/bin" "$HOME/.local/share"

# Matugen writes zathurarc here, but zathura is optional and the directory is
# not in the repo. Without it matugen aborts the whole run, so create it even
# when zathura is not installed.
mkdir -p "$HOME/.config/zathura"

# ── Step 3: Copy static fallback theme ────────────────────────────────────────
header "Installing fallback theme files..."

FALLBACK_DIR="$DOTFILES_DIR/theme-fallback"

if [[ -d $FALLBACK_DIR ]]; then
    cp -r "$FALLBACK_DIR"/. "$THEME_CURRENT/"
    # Seed the named snapshot too, so a first login without matugen still has
    # a complete theme.
    cp -r "$FALLBACK_DIR"/. "$THEME_THEMES/snow_black/"
    success "Copied fallback theme to $THEME_CURRENT"
else
    warn "No fallback theme found at $FALLBACK_DIR — run matugen after install."
fi

# ── Step 4: Stow dotfiles ─────────────────────────────────────────────────────
header "Stowing dotfiles..."

# Ask stow where it would collide (dry run) and back those paths up first.
# Deriving the list from stow itself — not re-implementing stow's ignore
# rules — keeps this in lockstep with .stow-local-ignore, so a fresh install
# can never abort mid-stow. Foreign symlinks stow wouldn't own (e.g. service
# files) are preserved in the backup and re-created by stow in canonical form.
BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
readarray -t CONFLICTS < <(stow --dir="$DOTFILES_DIR" --target="$HOME" --no --verbose=2 . 2>&1 \
    | sed -n -e 's/.*existing target is not owned by stow: *//p' \
             -e 's/.*cannot stow .* over existing target \([^ ]*\).*/\1/p' \
    | sort -u)

# Legacy installs left .config/btop and .config/cava as real directories with
# absolute wiring links. Moving them aside (preserved in the backup) lets
# stow fold them, so fresh and upgraded machines end up byte-identical.
for d in btop cava; do
    t="$HOME/.config/$d"
    if [[ -d $t && ! -L $t ]]; then
        mkdir -p "$BACKUP_DIR"
        mv "$t" "$BACKUP_DIR/$d"
        warn "  Normalized legacy real dir .config/$d into a stow fold (backup: $BACKUP_DIR/$d)"
    fi
done

if ((${#CONFLICTS[@]})); then
    mkdir -p "$BACKUP_DIR"
    warn "Backing up ${#CONFLICTS[@]} conflicting path(s) to $BACKUP_DIR"
    for rel in "${CONFLICTS[@]}"; do
        target="$HOME/$rel"
        if [[ -L $target ]]; then
            mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
            cp -P "$target" "$BACKUP_DIR/$rel" && rm -f "$target"
        elif [[ -e $target ]]; then
            mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
            mv "$target" "$BACKUP_DIR/$rel"
        else
            continue
        fi
        info "  Backed up: $target"
    done
    success "Backup complete"
fi

# ~/.config already exists as a real directory (Step 2), so stow descends
# into it and links each subtree — it never folds .config into one symlink.
stow --dir="$DOTFILES_DIR" --target="$HOME" --restow .
success "Stow complete — all configs symlinked to \$HOME"

# Quickshell polls ~/.config/quickshell/colors.css, which normally only exists
# after the first matugen run. Seed the static palette so the first login is
# already themed. ~/.config/quickshell is a stow symlink at this point, so the
# write lands in the repo's gitignored generated-file slot, exactly like matugen.
if [[ ! -s "$HOME/.config/quickshell/colors.css" && -f "$FALLBACK_DIR/colors.css" ]]; then
    cp "$FALLBACK_DIR/colors.css" "$HOME/.config/quickshell/colors.css"
    success "Seeded Quickshell palette from the fallback theme"
fi

# Rofi and cava read generated files straight out of ~/.config, not through
# theme/current. Seed their first-login copies too, or rofi's mandatory
# colors.rasi import fails before the first wallpaper is processed.
if [[ ! -s "$HOME/.config/rofi/colors.rasi" && -f "$FALLBACK_DIR/colors.rasi" ]]; then
    cp "$FALLBACK_DIR/colors.rasi" "$HOME/.config/rofi/colors.rasi"
    success "Seeded rofi palette from the fallback theme"
fi
if [[ ! -s "$HOME/.config/cava/config" && -f "$FALLBACK_DIR/cava_theme" ]]; then
    cp "$FALLBACK_DIR/cava_theme" "$HOME/.config/cava/config"
    success "Seeded cava config from the fallback theme"
fi

# The shell config is .zshrc, but a fresh Arch user still logs into bash. Offer
# to switch once; the new shell takes effect at the next login.
if [[ ${SHELL:-} != */zsh ]]; then
    echo ""
    read -rp "  Make zsh your login shell now? [Y/n] " set_zsh
    if [[ ! ${set_zsh:-Y} =~ ^[Nn]$ ]]; then
        chsh -s /usr/bin/zsh "$USER" && \
            success "Login shell set to zsh (takes effect at next login)" || \
            warn "Could not change the shell; run: chsh -s /usr/bin/zsh"
    else
        info "Login shell left as-is. Run later: chsh -s /usr/bin/zsh"
    fi
fi

# ── Step 5: Matugen (optional) ────────────────────────────────────────────────
header "Matugen dynamic theming (optional)"

echo ""
read -rp "  Generate colors from a wallpaper now? [y/N] " run_matugen

if [[ $run_matugen =~ ^[Yy]$ ]]; then
    read -rp "  Wallpaper path: " wallpaper_path
    wallpaper_path="${wallpaper_path/#\~/$HOME}"

    if [[ -f $wallpaper_path ]]; then
        # getTheme only treats absolute paths as the wallpaper argument; a
        # relative path would be ignored and it would fall back to the current
        # background, so resolve it here.
        wallpaper_path="$(realpath "$wallpaper_path")"
        info "Running: getTheme $wallpaper_path"
        if [[ -x $DOTFILES_DIR/.local/bin/getTheme ]]; then
            "$DOTFILES_DIR/.local/bin/getTheme" "$wallpaper_path" || \
                matugen image "$wallpaper_path" --mode dark --type scheme-fidelity --contrast 0.2 --source-color-index 0
        else
            matugen image "$wallpaper_path" --mode dark --type scheme-fidelity --contrast 0.2 --source-color-index 0
        fi
        mkdir -p "$THEME_CURRENT"
        ln -sfn "$wallpaper_path" "$THEME_CURRENT/background"
        success "Theme generated — colors updated!"
    else
        warn "File not found: $wallpaper_path"
        warn "Run later: getTheme ~/your-wallpaper.jpg"
    fi
else
    info "Skipped. Run later: getTheme ~/your-wallpaper.jpg"
fi

# ── Step 6: System-level extras (fonts, cursor base, SDDM, fastfetch art) ───
header "System extras (needs sudo for fonts/SDDM)..."

# ── Cursor base ────────────────────────────────────────────────────────────
# matugen-cursor recolours the stock Bibata Modern Ice theme, so the BASE theme
# must exist at ~/.local/share/icons/Bibata-Modern-Ice before it can run. With
# the base missing it prints "cursor base missing" and skips the cursor
# entirely, leaving the pointer stuck on whatever theme was there before.
#
# It ships as cursor-theme/.local/share/icons/Bibata-Modern-Ice, but stow maps
# top-level entries one-for-one onto $HOME, so that path would land at
# ~/cursor-theme -- somewhere nothing reads. cursor-theme is stow-ignored and
# linked into place here instead.
CURSOR_BASE_SRC="$DOTFILES_DIR/cursor-theme/.local/share/icons/Bibata-Modern-Ice"
CURSOR_BASE_DST="$HOME/.local/share/icons/Bibata-Modern-Ice"

if [[ -d $CURSOR_BASE_SRC ]]; then
    # A real dir here (from a previous manual copy) blocks the symlink.
    if [[ -e $CURSOR_BASE_DST && ! -L $CURSOR_BASE_DST ]]; then
        info "Normalizing existing real dir $CURSOR_BASE_DST into a symlink..."
        rm -rf "$CURSOR_BASE_DST"
    fi
    mkdir -p "$HOME/.local/share/icons"
    ln -sfn "$CURSOR_BASE_SRC" "$CURSOR_BASE_DST"
    success "Cursor base linked: $CURSOR_BASE_DST"
else
    warn "Cursor base not found at $CURSOR_BASE_SRC - matugen-cursor will skip the pointer theme."
fi

# Inter from repos: the SDDM theme's display font. SDDM runs as its own user
# and cannot read $HOME fonts, so it must live in /usr/share/fonts.
if fc-list | grep -qi " inter"; then
    success "Inter already installed"
else
    info "Installing inter-font (sudo)..."
    sudo pacman -S --needed --noconfirm inter-font && success "Inter installed" || warn "inter-font install failed"
fi

# SDDM theme (source: sddm/elarun-custom/). The palette in Palette.qml is a
# static file regenerated by hand when the login look changes. SDDM is optional:
# if it is not installed, skip this rather than creating config for a display
# manager that will never read it.
if [[ ! -d /usr/share/sddm ]]; then
    info "SDDM not installed; skipping the optional login theme."
elif [[ -d /usr/share/sddm/themes/elarun-custom ]]; then
    success "SDDM theme already installed"
else
    info "Installing elarun-custom SDDM theme (sudo)..."
    sudo cp -r "$DOTFILES_DIR/sddm/elarun-custom" /usr/share/sddm/themes/ && \
        sudo chown -R "$USER:$USER" /usr/share/sddm/themes/elarun-custom && \
        success "SDDM theme installed" || warn "SDDM install failed"
fi
if [[ -d /usr/share/sddm ]]; then
    if grep -q "Current=elarun-custom" /etc/sddm.conf.d/10-theme.conf 2>/dev/null; then
        success "SDDM already points at elarun-custom"
    else
        info "Pointing SDDM at elarun-custom (sudo)..."
        sudo mkdir -p /etc/sddm.conf.d && \
            printf '[Theme]\nCurrent=elarun-custom\n' | sudo tee /etc/sddm.conf.d/10-theme.conf >/dev/null && \
            success "SDDM configured" || warn "SDDM config failed"
    fi
fi

# ── systemd drop-ins ──────────────────────────────────────────────────────────
# etc/ is stow-ignored (stow maps top-level entries onto $HOME one-for-one), so
# these fixes have to be copied into place explicitly. They are small, but each
# one prevents a real failure:
#   keyd.service            clean shutdown exits 15, which systemd records as
#                           failed unless that code is whitelisted
#   user@.service           give the user manager room for Hermes to drain
#   archlinux-keyring-wkd   wait for DNS after resume instead of failing 101
if [[ -d $DOTFILES_DIR/etc/systemd/system ]]; then
    info "Installing systemd drop-ins (sudo)..."
    while IFS= read -r -d '' src; do
        rel="${src#"$DOTFILES_DIR/etc/systemd/system/"}"
        # The repo names the user-manager drop-in after UID 1000. Map it to the
        # actual UID so the fix still applies if the fresh install picks another.
        rel="${rel/#user@1000.service.d/user@$(id -u).service.d}"
        if sudo install -Dm644 "$src" "/etc/systemd/system/$rel"; then
            info "  $rel"
        else
            warn "  Could not install $rel"
        fi
    done < <(find "$DOTFILES_DIR/etc/systemd/system" -type f -print0)
    sudo systemctl daemon-reload || warn "systemd daemon-reload failed"
    success "systemd drop-ins installed"
fi

# fastfetch art (absolute path referenced by fastfetch config + quickshell)
mkdir -p "$HOME/fastfetchImages"
if [[ -f "$HOME/fastfetchImages/The_Knight__Hollow_Knight_-removebg-preview.png" ]]; then
    success "fastfetch art already present"
else
    cp "$DOTFILES_DIR/assets/fastfetch/The_Knight__Hollow_Knight_-removebg-preview.png" "$HOME/fastfetchImages/" && \
        success "fastfetch art installed"
fi

# ── Touchpad edge motion ─────────────────────────────────────────────────────
# The daemon reads the raw touchpad stream and writes to /dev/uinput, so it
# needs a udev rule before the systemd unit can work. The setup script is
# idempotent and scopes access with uaccess ACLs (no group changes).
EDGE_READY=0
if [[ -f /etc/udev/rules.d/66-edge-motion.rules && -w /dev/uinput ]]; then
    success "edge-motion device access already configured"
    EDGE_READY=1
else
    echo ""
    read -rp "  Enable touchpad edge motion (one-time udev + uinput setup)? [Y/n] " setup_edge
    if [[ ! ${setup_edge:-Y} =~ ^[Nn]$ ]]; then
        if sudo "$DOTFILES_DIR/.local/bin/edge-motion-install"; then
            EDGE_READY=1
        else
            warn "edge-motion setup failed; the service will stay disabled."
        fi
    else
        info "Skipped edge-motion setup; the service will stay disabled."
    fi
fi

# ── WatchCat ─────────────────────────────────────────────────────────────────
# The hotspot watchdog shells out to nethogs. It needs one passwordless sudo
# rule, scoped to that binary only, so a background service can sample traffic.
WATCHCAT_READY=0
if command -v nethogs >/dev/null 2>&1 && [[ -f /etc/sudoers.d/watchcat ]]; then
    success "WatchCat dependencies already configured"
    WATCHCAT_READY=1
else
    echo ""
    read -rp "  Set up WatchCat (nethogs + scoped sudo rule)? [y/N] " setup_watchcat
    if [[ ${setup_watchcat:-N} =~ ^[Yy]$ ]]; then
        sudo pacman -S --needed --noconfirm nethogs || warn "nethogs install failed"
        if command -v nethogs >/dev/null 2>&1; then
            rule=$(mktemp)
            printf 'Defaults!/usr/bin/nethogs !requiretty\n%s ALL=(root) NOPASSWD: /usr/bin/nethogs\n' "$USER" >"$rule"
            if sudo visudo -cf "$rule" >/dev/null 2>&1; then
                if sudo install -m 0440 "$rule" /etc/sudoers.d/watchcat; then
                    WATCHCAT_READY=1
                else
                    warn "Could not install /etc/sudoers.d/watchcat; WatchCat left disabled."
                fi
            else
                warn "Generated sudoers rule failed validation; WatchCat left disabled."
            fi
            rm -f "$rule"
        fi
    else
        info "Skipped WatchCat setup; the service will stay disabled."
    fi
fi

# ── Step 7: User services ─────────────────────────────────────────────────────
header "User services..."

systemctl --user daemon-reload 2>/dev/null || true

if compgen -G "/sys/class/power_supply/BAT*" >/dev/null; then
    systemctl --user enable --now battery-watch.service 2>/dev/null && \
        success "battery-watch enabled (low-battery notifications)" || \
        warn "Could not enable battery-watch.service"
else
    info "No battery found; battery-watch left disabled."
fi

systemctl --user enable --now failwatch.service 2>/dev/null && \
    success "failwatch enabled (failed units + journal alerts)" || \
    warn "Could not enable failwatch.service"

if command -v bt-agent >/dev/null 2>&1; then
    systemctl --user enable --now bt-agent.service 2>/dev/null && \
        success "bt-agent enabled (Bluetooth pairing agent)" || \
        warn "Could not enable bt-agent.service"
else
    info "bluez-tools not installed; bt-agent left disabled."
fi

if ((EDGE_READY)); then
    systemctl --user enable --now edge-motion.service 2>/dev/null && \
        success "edge-motion enabled (touchpad edge drag)" || \
        warn "Could not enable edge-motion.service"
else
    info "edge-motion left disabled; run edge-motion-install, then enable the service."
fi

if ((WATCHCAT_READY)); then
    systemctl --user enable --now watchcat.service 2>/dev/null && \
        success "watchcat enabled (hotspot data watchdog)" || \
        warn "Could not enable watchcat.service"
else
    info "watchcat left disabled; see the WatchCat section of the README."
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}  Installation complete!${RESET}"
echo ""
echo -e "  Next steps:"
echo -e "  ${CYAN}1.${RESET} Log out and back in (or restart Hyprland)"
echo -e "  ${CYAN}2.${RESET} Apply a wallpaper:  ${BOLD}getTheme ~/your-wallpaper.jpg${RESET}"
echo -e "  ${CYAN}3.${RESET} Colors live in:     ${BOLD}~/.config/theme/current/${RESET}"
echo -e "  ${CYAN}4.${RESET} Saved themes in:    ${BOLD}~/.config/theme/themes/${RESET}"
echo -e "  ${CYAN}5.${RESET} SDDM theme, fonts + fetch art handled by Step 6 (needs sudo)"
echo ""
