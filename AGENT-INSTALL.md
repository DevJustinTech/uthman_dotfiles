# Agent-assisted install

This is the handoff for letting an AI coding agent (OpenCode) run the long,
tedious middle of [`ARCH-INSTALL.md`](ARCH-INSTALL.md). The agent reads the
runbook; this file defines what it is allowed to touch.

It does **not** replace the runbook. Sections 0–4 (backup, USB, archinstall,
first boot) and `install.sh` stay with you.

## Before you start

You need:

- The base install and first boot finished (`ARCH-INSTALL.md` sections 0–4).
- Working Wi-Fi.
- The repo at `~/dotfiles`.
- OpenCode installed and authenticated.

```bash
sudo pacman -Syu --needed curl git opencode
opencode auth login

git clone --branch arch-ready \
  https://github.com/DevJustinTech/uthman_dotfiles.git ~/dotfiles
```

If the repo is already cloned, update it instead:

```bash
cd ~/dotfiles && git pull --ff-only
```

## Temporary sudo

The agent's shell cannot answer a sudo password prompt. On a fresh machine,
grant passwordless sudo for the duration of the install:

```bash
echo "$USER ALL=(ALL) NOPASSWD: ALL" \
  | sudo tee /etc/sudoers.d/90-opencode-install >/dev/null
sudo chmod 440 /etc/sudoers.d/90-opencode-install
sudo visudo -cf /etc/sudoers.d/90-opencode-install
sudo -n true && echo "sudo ok"
```

Remove it when the install is done:

```bash
sudo rm /etc/sudoers.d/90-opencode-install
```

Until you remove it, anything running as you can become root without a
password. That is acceptable on a fresh laptop on your own network; it is not
acceptable to leave behind.

## Who does what

| Work | Who | Why |
|---|---|---|
| Sections 0–4: backup, USB, archinstall, first boot | You | Interactive and physical |
| Sections 5–9: Limine, snapshots, packages, AUR, `/etc`, dotfiles clone | Agent | Long, deterministic, easy to get wrong by hand |
| `./install.sh` | You | `read` prompts, no TTY in the agent shell |
| Section 10: SDDM, first login, wallpaper | You | Visual |
| Section 11: verification | Agent | Command output is the evidence |
| Remove the sudoers rule | You | Last step |

## Start the agent

```bash
cd ~/dotfiles
opencode
```

Paste the prompt below. Approve the section 6 package transaction when it asks;
that is the only large irreversible step.

## Prompt

```text
You are completing a fresh Arch Linux install on this machine.
Read ~/dotfiles/ARCH-INSTALL.md in full before you start. It is the runbook;
this message defines scope and guardrails.

Scope: execute sections 5 through 9 in order, then stop. After I run
install.sh and log in, I will ask you to do section 11.

Exceptions and stop points:
- Do NOT run ./install.sh. I will run it myself; it needs interactive answers.
- Stop and ask before any reboot, before enabling SDDM, and before the
  section 6 package transaction.
- Sections 0-4 are already done. Do not redo them. Do not touch sections 12-15.
- The backup drive is mounted at /mnt/backup. Ask me if it is not.

Rules:
- Never install omarchy-only.txt.
- Never restore the /etc files that section 13 excludes.
- Never enable Secure Boot.
- Derive the LUKS PARTUUID from /proc/cmdline or blkid; never invent it.
- Prefer the prebuilt Limine packages in ~/arch-packages/prebuilt/.
- Stop and report missing or renamed packages. Do not substitute silently.
- Do not add packages the runbook does not list. Report anything that seems
  missing instead.
- Use sudo -n. If it fails, stop and tell me rather than hanging.
- After I approve section 6, --noconfirm is allowed, but stop on any conflict
  or missing target.
- Verify every checkpoint with the commands in the runbook and show the output.
  Never claim success without evidence.
- Do not edit ~/dotfiles; only read it. Report problems instead.
- Keep ~/install-progress.md current: section, command, result, next step.
  I will reboot and tell you "resume" after each stop.

When you stop after section 9, report: what passed, what failed, and what I
must do by hand (install.sh, SDDM login, hardware checks, sudoers cleanup).
```

## Resume after a reboot

OpenCode runs in `~/dotfiles`; its session and your progress file both survive
a reboot.

```bash
cd ~/dotfiles
opencode
```

Then say:

```text
resume from ~/install-progress.md
```

The agent should re-read the progress file and the matching runbook section
before running anything.

## Why `install.sh` is manual

`install.sh` uses `set -euo pipefail` and asks questions with `read -rp`:
zsh as login shell, wallpaper, edge-motion, WatchCat. The agent's shell has no
interactive TTY, so the first `read` hits EOF and the script exits.

Run it yourself:

```bash
cd ~/dotfiles
./install.sh
```

## After the agent finishes

1. Run `./install.sh` and answer the prompts.
2. Enable SDDM and log in:

   ```bash
   sudo systemctl enable --now sddm
   sudo reboot
   ```

3. Apply a wallpaper: `getTheme ~/Pictures/your-wallpaper.jpg`.
4. Ask the agent to run section 11 and show the output.
5. Remove the sudoers rule:

   ```bash
   sudo rm /etc/sudoers.d/90-opencode-install
   ```

## Guardrails that matter

- Snapshots cover `@`, not `@home`. The backup drive is still the only copy of
  your files.
- `omarchy-only.txt` is a list of packages that do **not** exist on vanilla
  Arch. Installing it breaks the restore.
- The old `/etc/fstab`, `/etc/default/limine`, `/etc/mkinitcpio.conf.d`, and
  `/etc/sddm.conf.d` contain dead UUIDs, Omarchy paths, or both. They are
  excluded for a reason.
- Secure Boot stays off. Limine is not signed.
- If the agent wants to "fix" something outside the runbook, stop it and read
  the reason first.
