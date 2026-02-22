# CachyOS Infrastructure

Infrastructure scripts for setting up CachyOS workstations.

## Quick Start

```bash
sudo ./scripts/setup-all.sh ert
sudo reboot
```

## Scripts

| Script | Requires | Description |
|--------|----------|-------------|
| `setup-all.sh` | sudo | Master script - runs all setup |
| `setup-chicago95.sh` | user | Install Chicago95 theme, apply XFCE config |
| `setup-tty-autologin.sh` | sudo | TTY autologin + auto-start XFCE (faster than LightDM) |
| `setup-autologin.sh` | sudo | Configure LightDM auto-login (legacy) |
| `setup-boot.sh` | sudo | Set timeout=0, remove quiet/splash |
| `setup-remove-plymouth.sh` | sudo | Remove plymouth from initramfs (faster boot) |
| `setup-storage.sh` | sudo | Mount RAID storage (/dev/md0) at /mnt/storage |
| `setup-keyd.sh` | sudo | Install keyd and merge `cut = f13` mapping without overwriting existing keyd config |
| `setup-voxtype.sh` | user | Install voxtype + output backends, apply user config, install WirePlumber mic no-suspend rule, auto-enable voxtype GPU backend via `sudo voxtype setup gpu --enable` (when passwordless sudo is available), link `voxtype.service` to `default.target`, restart/start `voxtype.service`, enable/restart `ydotool.service` |
| `setup-gnome-keyring.sh` | sudo | Install gnome-keyring with PAM auto-unlock |
| `setup-tmux-chezmoi.sh` | user | Manage tmux display defaults in chezmoi and apply |
| `setup-ssh-controlmaster.sh` | user | Manage SSH ControlMaster defaults in chezmoi and apply |
| `setup-ssh-agent.sh` | user | Enable ssh-agent via systemd socket, add AddKeysToAgent/ForwardAgent to SSH config via chezmoi |
| `setup-packages.sh` | user | Install packages from `config/packages/yay-explicit.txt` via yay |
| `export-packages.sh` | user | Snapshot explicitly installed packages into `config/packages/yay-explicit.txt` |

## Config

XFCE configuration in `config/xfce4/`:
- `xfconf/xfce-perchannel-xml/` - XFCE settings (theme, panel, desktop)
- `helpers.rc` - Default applications

Voxtype configuration:
- `config/voxtype/config.toml` - User voxtype config template

Package snapshot:
- `config/packages/yay-explicit.txt` - Explicit package list consumable by `yay -S`

## What Gets Configured

1. **Chicago95 Theme** - Windows 98 retro look
   - GTK theme, icons, cursors, sounds
   - Helvetica bitmap font (better rendering than Tahoma)
   - Panel with "Start" button
   - Teal desktop background (#008080)

2. **TTY Autologin** - Fast boot direct to XFCE (no display manager)

3. **Boot** - Zero timeout, text output instead of splash

## Idempotency

All scripts are idempotent - safe to run multiple times. Existing configs are backed up before overwriting.
