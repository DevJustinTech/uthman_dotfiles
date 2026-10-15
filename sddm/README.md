# sddm/elarun-custom — Qt6 port notes

Uthman's greeter theme, ported from Qt5 (`Theme-API=2.0`) to Qt6 so it can run
under this machine's SDDM, which is 0.21 and links **qt6-base**, not Qt5.

## What changed

| | Was | Now |
|---|---|---|
| `metadata.desktop` | `Theme-API=2.0` | `Theme-API=6.0` |
| `Main.qml` | `import QtQuick 2.0` | `import QtQuick 6.0` + `SddmComponents 6.0` + `import "."` |
| `Palette.qml` | `import QtQuick 2.0` | `import QtQuick 6.0` |
| session list | `sessionModel.count`, `model.name` | `sessionModel.rowCount()` / `data(index(i,0), Qt.DisplayRole)` into a plain array |
| fonts | `Iceland` (not installed) | `Inter Display` |

The session-model change is the substantive one. Under Qt6 `sessionModel` is a
`QAbstractItemModel`, so there is no `.count` and no `.name` role — the Qt5
code would have thrown on the delegate. Same approach the omarchy theme uses.

`import "."` is what lets `qmllint` resolve `Palette` from `Main.qml`; at
runtime a sibling type resolves by name anyway, but the linter needs it.

## Verification

`qmllint` (from `/usr/lib/qt6/bin`) reports **0 errors and 40 warnings, all of
them `unqualified`** — `sddm`, `userModel` and `sessionModel` are context
properties injected by the greeter, which the linter cannot see. Linting the
known-working omarchy theme the same way produces the identical class of
warning, so these are expected rather than defects.

## Installing

`/usr/share/sddm/themes` is root-owned and the greeter runs as its own user:

```bash
sudo cp -r ~/dotfiles/sddm/elarun-custom /usr/share/sddm/themes/
sudo tee /etc/sddm.conf.d/99-zz-elarun.conf >/dev/null <<'CFG'
[Theme]
Current=elarun-custom
CFG
```

The `99-zz-` prefix matters: SDDM reads `*.conf` in this directory and later
files win, so this has to sort after `10-theme.conf` and `99-omarchy-login.conf`.

### Palette follows your wallpaper

Matugen can rewrite `Palette.qml` so the greeter matches your current theme,
but `/usr/share` is root-owned, so that needs a root prompt on every wallpaper
change. The palette is left at its checked-in values. To re-run it by hand:

```bash
matugen generate config.toml && sudo cp <generated> /usr/share/sddm/themes/elarun-custom/Palette.qml
```

## Reverting

```bash
sudo rm /etc/sddm.conf.d/99-zz-elarun.conf
```

## Known separate issue

`/usr/bin/sddm-greeter` in this image is a stale Qt5 binary and cannot load —
it needs `libQt5{Quick,Qml,Network,Gui,Core}.so.5` and **zero** qt5 packages are
installed. SDDM 0.21 uses `sddm-greeter-qt6`. Confirm which path your install
expects with `sddm --help | grep -i greeter` before removing anything, because a
wrong removal costs you the graphical login.
