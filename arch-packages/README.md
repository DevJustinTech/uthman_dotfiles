# Package lists

Snapshot of the explicit packages on the Omarchy system on 2026-11-21, kept
here so the reinstall plan survives losing the backup drive. The authoritative
copy is `~/arch-packages` on the live system; the copy on the backup drive also
holds the prebuilt Limine packages and the `/etc` bundle.

| File | Purpose |
|------|---------|
| `official.txt` | 188 explicit packages that exist in `core`, `extra`, or `multilib`. Safe on plain Arch. |
| `omarchy-only.txt` | 30 packages from the Omarchy repository. **Do not install these.** Replacements are listed in `ARCH-INSTALL.md`. |
| `aur-keep.txt` | The 3 AUR packages worth reinstalling: `nbfc-linux`, `opencode-desktop-bin`, `ttf-lxgw-wenkai-screen`. |
| `aur-optional.txt` | Optional AUR replacements for Omarchy packages: VS Code, LocalSend, IA Writer, Yaru icons, `ufw-docker`, the share picker, `tzupdate`. |

## Install

After the base Arch install and the Limine/snapshot setup in
`ARCH-INSTALL.md`:

```bash
cd ~/arch-packages
sudo pacman -S --needed $(cat official.txt) \
  linux linux-headers neovim zram-generator \
  curl libnotify mise papirus-icon-theme playerctl polkit polkit-gnome \
  poppler-glib python python-pillow ttf-jetbrains-mono-nerd upower xdg-utils
```

The extra names after `official.txt` were dependencies or handled by the
installer, not explicit packages. They are also the set `install.sh` checks for,
so the installer has nothing to add on a clean restore.

Do not feed `omarchy-only.txt` to pacman. It contains `omarchy`, the
`linux-omarchy` kernel, Omarchy-repo builds of `spotify`/`yay`/
`visual-studio-code-bin`, and other packages that do not exist on a vanilla
Arch mirror. `quickshell` is not on that list: it is in `official.txt` because
Arch `extra` ships it.

## Why the repo copy is text only

The prebuilt `limine-mkinitcpio-hook` and `limine-snapper-sync` packages are
16 MB of foreign binaries. They belong on the backup drive, not in git. Copy
`~/arch-packages/prebuilt/` before wiping; the plan explains where to install
them.

The `/etc` bundle is also machine-specific and intentionally not committed. It
contains Wi-Fi credentials, the fan profile, keyd remaps, and Docker/UFW
config. Create it with the command in `ARCH-INSTALL.md`.

## Refreshing the lists

Run this on the live system before wiping if packages have changed since the
snapshot:

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

Using the official-repo list, rather than subtracting the Omarchy repo, keeps
`quickshell`: it exists in both repos and pacman does not record which one a
package came from.

`aur-keep.txt` and `aur-optional.txt` are curated by hand; the commands above
do not regenerate them.
