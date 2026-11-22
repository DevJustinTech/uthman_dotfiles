# Reinstalling from scratch

This is the full path from the current Omarchy install to plain Arch Linux
running this repo. It merges the earlier migration plan (backup, archinstall,
Limine, snapshots, package restore) with the standalone `arch-ready` dotfiles.

**This wipes the disk.** Read the whole document once before running anything.
The commands are written for the HP EliteBook 840 G3 (`nvme0n1`), but the only
machine-specific values are the disk name, the LUKS PARTUUID, and the timezone.

The result is:

- Plain Arch, no Omarchy repository or packages.
- BTRFS on LUKS, Limine with UKI disabled, zram.
- `snap-pac` pre/post snapshots on every pacman transaction, and those
  snapshots are bootable from the Limine menu.
- The 188-package restore from `~/arch-packages`, then the AUR keepers.
- This desktop, installed by `install.sh` from the `arch-ready` branch.

Niri is **not** part of this plan. The repo is Hyprland-only; see the last
section if you still want to try it.

Letting an AI agent run the long middle? [`AGENT-INSTALL.md`](AGENT-INSTALL.md)
has the scope, guardrails, and a paste-ready prompt. The backup, archinstall,
`install.sh`, and first login stay human.

---

## 0. Before you wipe

### 0.1 Refresh the package lists

The lists in `~/arch-packages` were generated on 2026-11-21. If packages have
changed since then, regenerate them while the old system is still intact:

```bash
mkdir -p ~/arch-packages && cd ~/arch-packages
pacman -Qqe > explicit.txt
pacman -Qqen > native-explicit.txt
pacman -Qqem > aur-explicit.txt
pacman -Qm > aur-all.txt
pacman -Q > all-versions.txt
for repo in core extra multilib; do
    pacman -Sl "$repo"
done | awk '{print $2}' | sort -u > official-repo.txt
comm -12 <(sort native-explicit.txt) official-repo.txt > official.txt
comm -23 <(sort native-explicit.txt) official-repo.txt > omarchy-only.txt
```

The `comm` lines ask which explicit packages exist in the official repos, not
which ones are absent from the Omarchy repo. The subtraction method drops
`quickshell`, because it exists in both repos and pacman does not record which
one a package came from.

`aur-keep.txt` and `aur-optional.txt` are curated by hand. Do not overwrite
them. The repo also carries a copy of the four curated lists in
`~/dotfiles/arch-packages/` once the `arch-ready` branch is cloned, in case the
backup drive is lost.

### 0.2 Bundle the `/etc` files that matter

```bash
sudo tar czf ~/arch-packages/etc-configs.tar.gz --ignore-failed-read -C / \
  etc/nbfc/nbfc.json \
  etc/keyd/default.conf \
  etc/docker/daemon.json \
  etc/ufw \
  etc/NetworkManager/system-connections \
  etc/systemd/system/docker.service.d/no-block-boot.conf \
  etc/systemd/system/plocate-updatedb.service.d/ac-only.conf \
  etc/systemd/system/user@.service.d/10-faster-shutdown.conf
sudo chown "$USER:" ~/arch-packages/etc-configs.tar.gz
```

This deliberately excludes:

- `/etc/fstab`, `/etc/kernel/cmdline`, `/etc/default/limine` — new UUIDs and
  PARTUUIDs after the wipe.
- `/etc/mkinitcpio.conf.d/omarchy_*` — Omarchy hooks (Plymouth, overlayfs,
  resume) that are rebuilt below.
- `/etc/pacman.conf` — contains the `[omarchy]` repo.
- `/etc/sddm.conf.d` — the current files point at the `omarchy` theme,
  `start-hyprland --config /usr/share/sddm/hyprland.lua`, and an
  `omarchy.desktop` autologin session. None of those exist on plain Arch. The
  installer writes a clean `10-theme.conf`; create autologin fresh if you want
  it.

### 0.3 Copy everything to the backup drive

Mount the drive first:

```bash
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT
BACKUP=/mnt/backup
sudo mkdir -p "$BACKUP"
sudo mount /dev/sdX1 "$BACKUP"
sudo chown "$USER:" "$BACKUP"
```

Copy the package folder **including `prebuilt/`**, plus the repo and the
personal files that cannot be re-downloaded:

```bash
rsync -a --info=progress2 ~/arch-packages ~/dotfiles "$BACKUP"/
rsync -a --info=progress2 \
  ~/Documents ~/Pictures ~/Books ~/Wallpapers ~/Videos/Recordings \
  ~/Downloads/Documents ~/.ssh ~/.gnupg "$BACKUP"/
```

Add these if you use them:

```bash
rsync -a --info=progress2 ~/.config/zen ~/.local/zen.app "$BACKUP"/
rsync -a --info=progress2 ~/.hermes "$BACKUP"/
rsync -a --info=progress2 ~/.cache/yay "$BACKUP"/
```

- `~/arch-packages/prebuilt/` is 16 MB of Limine helper packages. If you lose
  it, you have to build GraalVM native images from the AUR on a 7.6 GB laptop.
- `~/.config/zen` is the browser profile (4.1 GB) and `~/.local/zen.app` is the
  browser binary (139 MB). Zen is not a package.
- `~/.hermes` is 5.5 GB. Keep it if you use Hermes.
- `~/.cache/yay` (798 MB) lets `yay` reuse AUR builds.

Some real files under `~/.config` are not in the dotfiles repo. Copy the small
ones:

```bash
mkdir -p "$BACKUP/config-extras"
rsync -a --ignore-missing-args \
  ~/.config/git ~/.config/autostart \
  ~/.local/share/keyrings \
  "$BACKUP/config-extras/"
cp -a ~/.config/systemd/user/hermes-gateway.service \
      ~/.config/systemd/user/screentime.service \
      "$BACKUP/config-extras/" 2>/dev/null || true
```

- `~/.config/git/config` — git identity, aliases, signing setup.
- `~/.config/autostart/` — fcitx5, the print applet, the Limine snapshot
  notifier.
- `~/.local/share/keyrings/` — saved logins. They only unlock with the same
  login password.
- `hermes-gateway.service` and `screentime.service` — external user units. The
  repo's own units come back with the clone; do not restore the whole
  `~/.config/systemd/user` directory, or its symlinks will collide with Stow.
- Browser profiles keep saved logins. They are large; copy them only if you
  want the sessions.

Push code, or copy `~/Projects`, `~/projects`, `~/sanctum`, and `~/backups`
without `node_modules` and build output.

Not worth copying: `node_modules`, toolchain caches, `/var/cache/pacman/pkg`,
and the old Omarchy packages.

Verify the archive and the prebuilt folder:

```bash
tar tzf ~/arch-packages/etc-configs.tar.gz | head
ls -lh ~/arch-packages/prebuilt/
sync
sudo umount "$BACKUP"
```

Snapper snapshots cover `@`, not `@home`. They are not a backup of your files.

### 0.4 Download and verify the ISO

Use the current ISO name; this example is `2026.11.01`:

```bash
cd ~/Downloads
base=https://geo.mirror.pkgbuild.com/iso/latest
curl -LO "$base/archlinux-2026.11.01-x86_64.iso"
curl -LO "$base/archlinux-2026.11.01-x86_64.iso.sha256"
sha256sum -c archlinux-2026.11.01-x86_64.iso.sha256
```

---

## 1. Write the USB

```bash
lsblk -o NAME,SIZE,MODEL,TRAN
```

Find the stick with `TRAN=usb`. Confirm the size and model. Then:

```bash
sudo umount /dev/sdX* 2>/dev/null
sudo dd if=archlinux-2026.11.01-x86_64.iso of=/dev/sdX bs=4M status=progress oflag=sync
sync
sudo eject /dev/sdX
```

`sdX` is the **whole USB device** (`/dev/sdb`), never a partition (`/dev/sdb1`).
This erases the target.

On the EliteBook: **F10** for BIOS, **F9** for the boot menu.

- Disable **Secure Boot** (Security → Secure Boot → Disabled).
- Boot mode: **UEFI**, not Legacy/CSM.
- If the USB does not appear, disable Fast Boot.

---

## 2. Boot the ISO and get online

Verify UEFI:

```bash
cat /sys/firmware/efi/fw_platform_size
# 64
```

Connect Wi-Fi:

```bash
iwctl
station list
station wlan0 scan
station wlan0 get-networks
station wlan0 connect "YOUR-SSID"
exit
ping -c 3 archlinux.org
```

If the interface is not `wlan0`, use what `station list` shows. If no networks
appear, try `rfkill unblock wifi`.

If the network has a captive portal, `lynx https://example.com` is the ISO's
only browser. For a JavaScript-heavy portal, USB tether the phone instead.

---

## 3. Run archinstall

```bash
archinstall
```

Menu labels move between archinstall releases. The choices for this machine:

| Menu | Choose |
|---|---|
| Mirrors | Your region, or Worldwide |
| Locales | `en_US.UTF-8`, keyboard `us` |
| Disk configuration | `nvme0n1` → best-effort default layout → **btrfs** → compression **yes / zstd** |
| Disk encryption | Enable → select the **root** partition → LUKS passphrase |
| Swap | **zram** → zstd |
| Bootloader | **Limine**, UKI **disabled**, removable **no**, Plymouth **no** |
| Hostname | `justin` |
| Authentication | Root password; user `justin`; wheel **yes**; sudo **yes** |
| Profile | **Minimal** |
| Audio | **PipeWire** |
| Network | **NetworkManager** |
| Timezone | `Africa/Lagos`; NTP **yes** |
| Kernels | **`linux` only** |
| Additional packages | `git base-devel zsh linux-headers intel-ucode` |
| Install | Review → Proceed |

### Disk layout notes

- The default layout creates a **1 GiB FAT32 ESP at `/boot`** and btrfs
  subvolumes `@` (root), `@home`, `@log`, `@pkg`. That is what this plan
  expects.
- Limine with UKI disabled needs the ESP at `/boot`. The default satisfies it.
- If you want more snapshot history, use manual partitioning: **2 GiB** FAT32
  ESP at `/boot`, rest btrfs + LUKS with the same four subvolumes.
  `limine-snapper-sync` deduplicates kernel files and prunes at 85%.
- **Do not add `linux-lts`.** Fan control (`acpi_call`, pulled by
  `nbfc-linux`) is built for the `linux` kernel. One kernel avoids breakage.
- `intel-ucode` is not installed automatically. Add it.
- LUKS has no recovery key by default. Write the passphrase down somewhere
  outside this machine before you continue.

At the summary screen, confirm the disk says **Wipe: true** and encryption says
**LUKS**. Then install. The download is roughly 1 GB.

---

## 4. First boot

Remove the USB, reboot, and enter the LUKS passphrase at the Limine prompt.
Log in as `justin`.

```bash
sudo pacman -Syu
uname -r
pacman -Q linux
```

If the kernel version changed, reboot before continuing:

```bash
sudo reboot
```

Connect Wi-Fi if it did not carry over:

```bash
nmtui
```

Set zsh as your shell:

```bash
chsh -s /usr/bin/zsh
```

Mount the backup drive and restore the package folder:

```bash
lsblk
sudo mkdir -p /mnt/backup
sudo mount /dev/sdX1 /mnt/backup
mkdir -p ~/arch-packages
cp -a /mnt/backup/arch-packages/. ~/arch-packages/
ls ~/arch-packages/prebuilt/
```

If the backup is gone, clone the repo now and use its copy of the lists. You
will have to build the Limine helpers from the AUR instead of using the
prebuilt packages:

```bash
git clone --branch arch-ready https://github.com/DevJustinTech/uthman_dotfiles.git ~/dotfiles
mkdir -p ~/arch-packages
cp -a ~/dotfiles/arch-packages/. ~/arch-packages/
```

---

## 5. Limine and bootable snapshots

Do this **before** the 188-package restore, so the big transaction is
snapshotted.

### 5.1 Install the snapshot stack

```bash
sudo pacman -S --needed snapper snap-pac libnotify inotify-tools
cd ~/arch-packages
sudo pacman -U prebuilt/limine-mkinitcpio-hook-*.pkg.tar.zst \
               prebuilt/limine-snapper-sync-*.pkg.tar.zst
```

Pacman warns that the local packages are unsigned. Accept. They depend only on
official-repo packages.

Verify:

```bash
pacman -Q limine limine-mkinitcpio-hook limine-snapper-sync
```

If `prebuilt/` is missing, skip this section until after section 7 (AUR), then:

```bash
yay -S --needed limine-mkinitcpio-hook limine-snapper-sync
```

The AUR builds are slow and memory-hungry on this laptop. The prebuilt copies
are the reason the folder is on the backup drive.

### 5.2 Configure `/etc/default/limine`

Read the kernel command line archinstall actually used:

```bash
cat /proc/cmdline
```

Copy the `cryptdevice=...`, `root=...`, and `rootflags=...` parts. Then create
the config, replacing `PASTE_HERE` with the **LUKS partition's** PARTUUID (not
the filesystem UUID):

```bash
sudo tee /etc/default/limine >/dev/null <<'EOF'
ESP_PATH="/boot"
ENABLE_UKI=no
KERNEL_CMDLINE[default]+="cryptdevice=PARTUUID=PASTE_HERE:root root=/dev/mapper/root zswap.enabled=0 rootflags=subvol=@ rw rootfstype=btrfs"
EOF
```

If `/proc/cmdline` uses `root=UUID=...`, keep that form instead of
`root=/dev/mapper/root`. If it uses `rd.luks.name=<UUID>=root` instead of
`cryptdevice=PARTUUID=...`, keep that form too — it means the initramfs uses
`sd-encrypt`. The important parts are the LUKS identifier, `rootflags=subvol=@`,
`rootfstype=btrfs`, and `zswap.enabled=0`.

Install and generate the entries:

```bash
sudo limine-install
sudo limine-update
limine-list
```

`limine-list` should show `Arch Linux` with a `linux` entry.

### 5.3 Add the snapshot initramfs hook

Check the current hooks:

```bash
grep -R '^HOOKS=' /etc/mkinitcpio.conf /etc/mkinitcpio.conf.d/ 2>/dev/null
```

Archinstall normally produces one of these:

```text
base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck
base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck
```

If it uses `encrypt`, append `btrfs-overlayfs`. If it uses `sd-encrypt`, append
`sd-btrfs-overlayfs`. A drop-in keeps the main file untouched and sorts after
the archinstall config:

```bash
sudo mkdir -p /etc/mkinitcpio.conf.d
echo 'HOOKS+=(btrfs-overlayfs)' | sudo tee /etc/mkinitcpio.conf.d/99-snapshots.conf
```

Use `HOOKS+=(sd-btrfs-overlayfs)` instead when the hooks use `sd-encrypt`.

Rebuild and confirm the hook ran:

```bash
sudo mkinitcpio -P
sudo limine-update
```

The output must include:

```text
==> Running build hook: [btrfs-overlayfs]
```

### 5.4 Configure Snapper

```bash
sudo snapper -c root create-config /
sudo snapper -c root set-config TIMELINE_CREATE=no
sudo systemctl disable --now snapper-timeline.timer 2>/dev/null || true
sudo snapper -c root set-config NUMBER_LIMIT=5 NUMBER_LIMIT_IMPORTANT=5
sudo systemctl enable --now snapper-cleanup.timer
sudo systemctl enable --now limine-snapper-sync.service
```

`snap-pac` creates a pre/post pair on every pacman transaction. Five snapshots
is the old policy; raise `NUMBER_LIMIT` if you want more than a couple of
transactions of history.

Create a baseline and check the menu:

```bash
sudo snapper -c root create --description "clean base"
sudo snapper list
limine-list
```

`limine-list` should now show a **Snapshots** submenu containing the baseline.

If it does not:

```bash
systemctl status limine-snapper-sync.service --no-pager
limine-list                       # note the exact OS entry name
sudoedit /etc/limine-snapper-sync.conf
# set: TARGET_OS_NAME="Arch Linux"
sudo systemctl restart limine-snapper-sync.service
```

Reboot once and confirm the Limine menu shows **Snapshots** before continuing.

---

## 6. Restore the official packages

```bash
cd ~/arch-packages
sudo pacman -S --needed $(cat official.txt) \
  linux linux-headers neovim zram-generator \
  curl libnotify mise papirus-icon-theme playerctl polkit polkit-gnome \
  poppler-glib python python-pillow ttf-jetbrains-mono-nerd upower xdg-utils
```

- `official.txt` has 188 explicit packages that exist in `core`/`extra`/
  `multilib`. It contains no Omarchy-repo packages.
- The extra names were dependencies or handled by archinstall. Most are not in
  `official.txt`; `zram-generator` is, and `--needed` makes the overlap
  harmless. They are the packages `install.sh` checks for, so installing them
  here means the installer's dependency sweep has nothing to do.
- Do **not** install `omarchy-only.txt`. It contains the `omarchy` meta package,
  the `linux-omarchy` kernel, and Omarchy-repo builds of `spotify`, `yay`,
  `visual-studio-code-bin`, and others that do not exist on a vanilla Arch
  mirror.
- Watch for provider/conflict prompts. Choose the defaults unless you know
  otherwise. If pacman says a target was not found, remove that name and retry;
  package renames happen.
- This is one large transaction, so `snap-pac` creates pre/post snapshots
  automatically. Check with `sudo snapper list`.
- If the kernel updated, reboot again before installing AUR kernel modules.

The installer's dependency check is a safety net, not the primary restore.

---

## 7. AUR packages

Bootstrap `yay`:

```bash
sudo pacman -S --needed git base-devel
git clone https://aur.archlinux.org/yay.git
cd yay && makepkg -si
cd ~ && rm -rf yay
```

Install the three keepers:

```bash
yay -S --needed $(cat ~/arch-packages/aur-keep.txt)
```

That is:

- `nbfc-linux` — fan control. `/etc/nbfc/nbfc.json` is restored in section 8.
  This is the critical one.
- `opencode-desktop-bin`
- `ttf-lxgw-wenkai-screen`

`nbfc-linux` builds `acpi_call` for the running kernel. If the kernel changed
in section 6, reboot first or the build will target the wrong version.

Optional extras:

```bash
sudo pacman -S --needed mise ttf-jetbrains-mono-nerd spotify-launcher
yay -S --needed $(cat ~/arch-packages/aur-optional.txt)
```

`aur-optional.txt` includes `visual-studio-code-bin`, `localsend-bin`,
`ttf-ia-writer`, `yaru-icon-theme`, `ufw-docker`,
`hyprland-preview-share-picker-git`, and `tzupdate`. Pick what you use. VS Code
is here, not in `aur-keep.txt`; the earlier "four keepers" note counted it as
required, but the curated list treats it as optional.

If you restored `~/.cache/yay` from the backup, put it back before this step so
`yay` reuses the existing builds.

If you use the Omarchy app replacements:

```bash
yay -S --needed aether cliamp herdr hermes-agent-desktop-bin
```

Herdr and Hermes are optional. The desktop starts without them; the
`SUPER+CTRL+RETURN` Herdr binding and the Hermes gateway are the only things
that need them.

---

## 8. Restore `/etc` and enable services

```bash
sudo tar xzf ~/arch-packages/etc-configs.tar.gz -C /
sudo systemctl restart NetworkManager
```

Verify the important files:

```bash
ls -l /etc/nbfc/nbfc.json /etc/keyd/default.conf /etc/docker/daemon.json
ls /etc/NetworkManager/system-connections
```

If Wi-Fi did not reconnect, use `nmtui`.

Enable the system services:

```bash
sudo systemctl enable --now keyd nbfc_service thermald power-profiles-daemon ufw bluetooth
systemctl --user enable --now pipewire pipewire-pulse wireplumber
sudo systemctl enable docker.socket
sudo usermod -aG docker "$USER"
```

Check the two hardware-sensitive units:

```bash
systemctl status nbfc_service keyd --no-pager
```

`nbfc_service` needs `acpi_call`. If it fails:

```bash
journalctl -u nbfc_service -b
pacman -Q linux acpi_call
```

Confirm the running kernel and the `acpi_call` build match, then reboot.

If you use Docker with UFW, run the helper after the firewall config is back:

```bash
sudo ufw-docker install
```

Do **not** enable SDDM yet. Wait until the desktop packages and dotfiles are in
place.

The repo's `/etc` drop-ins (`keyd` exit 15, the user-manager timeout, and the
keyring DNS wait) are installed by `install.sh` in the next section. They are
versioned under `etc/systemd/system/` and are not stowed.

---

## 9. Dotfiles and desktop

Clone the standalone branch at the exact path the theme symlinks expect:

```bash
git clone --branch arch-ready https://github.com/DevJustinTech/uthman_dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

The repo **must** be at `~/dotfiles`. The relative theme symlinks resolve from
there into `~/.config/theme`; the installer refuses any other path.

If section 4 already cloned the repo for the package lists, use that clone
instead of cloning again:

```bash
cd ~/dotfiles
git fetch origin
git checkout arch-ready
git pull --ff-only
./install.sh
```

What the installer does:

1. Checks every required package and offers one `pacman -S` command for what is
   missing. After section 6 it should report nothing missing.
2. Creates `~/.config/theme/current` and `~/.config/theme/themes/snow_black`,
   and seeds the static fallback palette so the first login is themed before
   Matugen runs.
3. Stows the tracked dotfiles into `$HOME`, backing conflicts up to
   `~/.config-backup-<timestamp>` first. It offers to make zsh your login shell.
4. Optionally runs `getTheme` on a wallpaper you choose.
5. Links the Bibata cursor base, installs Inter, installs the SDDM theme when
   `/usr/share/sddm` exists, installs the systemd drop-ins, and copies the
   fastfetch art.
6. Offers the one-time touchpad edge-motion setup and the WatchCat setup.
7. Enables `battery-watch`, `failwatch`, `bt-agent`, and whichever of
   `edge-motion` / `watchcat` have their prerequisites.

If you kept local-only files, restore them now:

```bash
cp -a /mnt/backup/config-extras/git ~/.config/
cp -a /mnt/backup/config-extras/autostart ~/.config/
cp -a /mnt/backup/config-extras/keyrings ~/.local/share/
mkdir -p ~/.config/systemd/user
cp -a /mnt/backup/config-extras/hermes-gateway.service \
      /mnt/backup/config-extras/screentime.service \
      ~/.config/systemd/user/ 2>/dev/null || true
systemctl --user daemon-reload
```

Also restore wallpapers, the Wallhaven key, Zen web-app CSS, and the browser
profiles. `~/.config/quickshell/wallshelf.ini` is gitignored on purpose and is
not in the clone.

After restoring an external service, enable it:

```bash
systemctl --user enable --now hermes-gateway.service
# rebuild the screentime binary first, then:
systemctl --user enable --now screentime.service
```

---

## 10. Display manager and first login

```bash
sudo systemctl enable --now sddm
sudo reboot
```

At SDDM, choose **Hyprland** and log in. If you want autologin:

```bash
sudo tee /etc/sddm.conf.d/autologin.conf >/dev/null <<'EOF'
[Autologin]
User=justin
Session=hyprland.desktop
EOF
```

If SDDM does not start, log in on a TTY and start Hyprland directly to see the
error:

```bash
Hyprland
```

Then check:

```bash
systemctl status sddm --no-pager
journalctl -u sddm -b
```

After the first login, apply a wallpaper:

```bash
getTheme ~/Pictures/your-wallpaper.jpg
```

or open the wallpaper panel with `SUPER+E`. The first Matugen run writes every
generated file under `~/.config`.

---

## 11. Verify

```bash
uname -r
findmnt /
sudo btrfs subvolume list /
sudo snapper list
limine-list
efibootmgr -v
systemctl --failed
```

Check:

- `limine-list` shows `Arch Linux` and a **Snapshots** submenu.
- `snapper list` shows the baseline and the pre/post entries from the package
  restore.
- `efibootmgr` has a Limine entry and it is first.
- `findmnt /` shows the `@` subvolume.
- No failed units.
- `nbfc status` shows the HP profile; the Insert key produces `=` and
  Alt+Insert produces `\`.
- Wi-Fi, audio (`wpctl status`), Bluetooth, SDDM, and the touchpad work.
- `Hyprland --verify-config --config ~/.config/hypr/hyprland.lua` prints
  `config ok`.

Recommended: verify a snapshot actually boots.

```bash
sudo snapper -c root create --description "boot test"
sudo reboot
```

At Limine, open **Snapshots**, select `boot test`, and confirm it boots into a
read-only snapshot with a writable overlay. Do not restore; reboot normally
afterward.

---

## 12. Recovery

### Boot-menu recovery

If an update breaks the system:

1. Reboot.
2. At Limine, choose **Snapshots**.
3. Select the entry from before the update.
4. It boots read-only with an overlay. The desktop offers **Restore now**, or
   run `sudo limine-snapper-restore`.
5. Reboot into the restored system.

### TTY recovery

If the menu is intact but the snapshot entry will not boot, log in as root on a
TTY and roll back manually:

```bash
snapper list
snapper rollback <number>
reboot
```

### Rescue USB

This covers broken packages, configs, and kernels. It does **not** cover:

- Disk failure or filesystem corruption.
- A wiped or broken ESP/bootloader.
- Lost files in `/home`. Snapshots cover `@`, not `@home`.

Keep a rescue USB at home. Because root is LUKS, the ISO needs the passphrase
before anything else:

```bash
cryptsetup open /dev/nvme0n1p2 root
mount -o subvol=@ /dev/mapper/root /mnt
arch-chroot /mnt
snapper list
snapper rollback <number>
reboot
```

`@home`/`@log`/`@pkg` are separate subvolumes, so a rollback never touches your
files, logs, or package cache.

---

## 13. Do not do these

- Do not restore the old `/etc/fstab`, `/etc/kernel/cmdline`,
  `/etc/default/limine`, `/etc/mkinitcpio.conf.d`, or `/etc/pacman.conf`. The
  new install has new UUIDs and PARTUUIDs.
- Do not restore the old `/etc/sddm.conf.d`. It points at the `omarchy` theme,
  `start-hyprland` with an Omarchy Lua config, and an `omarchy.desktop` session.
- Do not restore `/etc/systemd/system/cups-browsed.service.d/10-omarchy.conf`.
  It is owned by `omarchy-settings` and is not part of the new system.
- Do not install `omarchy-only.txt`.
- Do not enable Secure Boot. Limine is not signed.
- Do not use `--noconfirm` for the 188-package restore until you have reviewed
  it once.
- Do not assume snapshots back up `/home`; they do not.
- Do not forget the LUKS passphrase. There is no recovery key by default.

---

## 14. Niri

Niri is viable on this laptop, but it is a desktop rewrite, not a package swap.
This repo has no niri config, and Quickshell 0.3.2 has no `Quickshell.Niri`.
The workspace/window modules, keybinds, and Matugen template would need porting.
Budget a day or two, not fifteen minutes.

If you want to try it, do it on the **current** system before wiping. Install
it alongside Hyprland, disable autologin, and pick Niri at SDDM:

```bash
sudo pacman -S --needed niri xwayland-satellite fuzzel mako swaybg swayidle swaylock
sudo mv /etc/sddm.conf.d/autologin.conf /etc/sddm.conf.d/autologin.conf.off
```

Log out, choose **Niri**, log in, and test the column workflow:

- `Mod+H/L` — focus columns
- `Mod+1/2` — switch workspaces
- `Mod+Ctrl+1` — move a column to workspace 1
- `Mod+Wheel` — scroll workspaces
- three-finger swipe — workspace switching
- `Print` — niri's built-in screenshot UI

Log out and choose Hyprland to go back. Restore autologin with:

```bash
sudo mv /etc/sddm.conf.d/autologin.conf.off /etc/sddm.conf.d/autologin.conf
```

If you hate it:

```bash
sudo pacman -Rns niri xwayland-satellite fuzzel mako swaybg swayidle swaylock
rm -rf ~/.config/niri
```

Limine, snapshots, keyd, fan control, and the package lists are unchanged by
the choice. Only the desktop layer changes.

---

## 15. Outside this repo

These are wired into the desktop but live outside the dotfiles. Restore them
from the backup if you use them; the desktop starts without them:

| Path / package | What it is |
|---|---|
| `~/projects/screentime` | Screen time daemon and SQLite store |
| `qemu-launch` | Bubble Tea QEMU launcher, ISOs from `~/Downloads` |
| `~/.local/zen.app` | Zen browser binary (not a package) |
| `~/.hermes` | Hermes data and gateway |
| `~/.config/quickshell/wallshelf.ini` | Wallhaven API key (gitignored) |
| `~/Wallpapers` | Local wallpaper collection (gitignored) |

`~/projects/screentime` has its own `install.sh`; run it to put the binary
back in `~/.local/bin` before enabling `screentime.service`.

The repo's `README.md` has the per-app details and keybinds.
