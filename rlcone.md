# Home Directory Architecture & Google Drive Backup Guide

This document records the structure of `/home/bine`, the file organization decisions made, and complete step-by-step instructions for setting up and managing `rclone bisync` backup to Google Drive — both for this current machine and for restoring / bootstrapping a new device in the future.

---

## 1. Directory Structure & Organization Summary

Root directory `/home/bine` has been cleaned up to strictly follow standard XDG conventions and maintain clean root organization:

### Synced Directories (Backed up via `rclone bisync`)
- `~/Documents/`: Primary personal & work documentation.
  - `~/Documents/Contracts/`: Holds signed agreements and legal documents (e.g., NDA/IP assignments, contractor agreements).
  - Subfolders: `Legal/`, `Invoices/`, `Projects/`, `Work/`, `Notes/`, `Certificates/`, `Archive/`, `Designs/`, `Books/`, `Misc/`.
- `~/Downloads/`: Web downloads (Files >100MB like OS ISOs are filtered out from cloud sync to save space/bandwidth).
- `~/Pictures/`: Screenshots, images, and photos.
- `~/Templates/`: File templates.
- `~/Videos/`: Video files.
- `~/Scratchpad/`: Quick working folder for temporary notes/projects.

### Excluded Local Directories (Not Synced to Google Drive)
- `~/Code/`: Git repositories (managed via remote git providers like GitHub/GitLab).
- `~/dotfiles/`: GNU Stow dotfile repository (manages shell, tools, systemd, and rclone configurations).
- `~/Android/`, `~/flutter/`, `~/go/`: Developer SDKs, caches, and toolchains.
- `~/.cache/`, `~/.local/`, and root dotdirs: System & browser runtime caches.

---

## 2. Setting Up Google Drive Remote (`rclone config`)

Before running any backup scripts, configure the `gdrive` remote in rclone:

1. Launch interactive configuration:
   ```bash
   rclone config
   ```
2. Press `n` for **New remote**.
3. Name: `gdrive`
4. Storage Type: Choose `drive` (Google Drive, typically number `42` or search for `drive`).
5. `client_id` & `client_secret`: Leave blank (press Enter) to use rclone's standard credentials, or supply your custom GCP credentials.
6. Scope: Choose `1` (`drive` - Full access to all files).
7. `service_account_file`: Leave blank (press Enter).
8. Advanced config: `n` (No).
9. Auto config: `y` (Yes). This opens a browser window to authenticate with your Google account. Grant permissions.
10. Confirm and save the remote (`y`), then quit (`q`).

Verify the remote works:
```bash
rclone lsd gdrive:
```

---

## 3. First-Time Backup (`--resync`) on Current Machine

Because `rclone bisync` performs bidirectional synchronization, the very first sync requires the `--resync` flag to establish baseline file listings.

Run the pre-configured runner script with `--resync`:

```bash
~/.config/rclone/rclone-bisync-gdrive.sh --resync
```

This will sync `Documents`, `Downloads` (<100MB), `Pictures`, `Templates`, `Videos`, and `Scratchpad` to `gdrive:Backup/home_bine`.

---

## 4. Automatic Sync via Systemd User Timer

Background sync is pre-configured via systemd user units to run every 15 minutes.

### Enable & Start Timer
```bash
systemctl --user daemon-reload
systemctl --user enable --now rclone-bisync.timer
```

### Check Status & Logs
- View timer schedule:
  ```bash
  systemctl --user list-timers rclone-bisync.timer
  ```
- View service status:
  ```bash
  systemctl --user status rclone-bisync.service
  ```
- View rclone sync logs:
  ```bash
  cat ~/.config/rclone/rclone-bisync.log
  ```

---

## 5. Bootstrapping a New Device (Restoring from Google Drive & Dotfiles)

When setting up a brand-new device in the future, follow these steps:

### Step 1: Install Dependencies
```bash
# Fedora / RHEL
sudo dnf install rclone stow

# Ubuntu / Debian
sudo apt update && sudo apt install rclone stow

# Arch Linux
sudo pacman -S rclone stow
```

### Step 2: Deploy Dotfiles (Includes rclone script & systemd units)
```bash
cd ~/dotfiles
stow */
```
This automatically symlinks `rclone` script/filters into `~/.config/rclone/` and `systemd` units into `~/.config/systemd/user/`.

### Step 3: Configure `gdrive` Remote
Run `rclone config` as shown in **Section 2** and name the remote `gdrive`.

### Step 4: Download Existing Files to Local Home
On a fresh device where local folders (`Documents`, `Pictures`, etc.) are empty:

1. Download all files from Google Drive to your local home directory:
   ```bash
   rclone copy gdrive:Backup/home_bine ~ --max-size 100M -P
   ```

2. Perform initial `bisync` initialization on the new machine:
   ```bash
   ~/.config/rclone/rclone-bisync-gdrive.sh --resync
   ```

3. Enable the systemd timer:
   ```bash
   systemctl --user daemon-reload
   systemctl --user enable --now rclone-bisync.timer
   ```

---

## 6. GNU Stow Packages & Helper Files Reference

Configurations are managed under `~/dotfiles` and stowed into `~/.config/`:

- **Stow Package `rclone`**: `~/dotfiles/rclone/.config/rclone/`
  - Filter File: `~/.config/rclone/bisync-filters.txt` -> `~/dotfiles/rclone/.config/rclone/bisync-filters.txt`
  - Runner Script: `~/.config/rclone/rclone-bisync-gdrive.sh` -> `~/dotfiles/rclone/.config/rclone/rclone-bisync-gdrive.sh`
- **Stow Package `systemd`**: `~/dotfiles/systemd/.config/systemd/user/`
  - Systemd Service: `~/.config/systemd/user/rclone-bisync.service` -> `~/dotfiles/systemd/.config/systemd/user/rclone-bisync.service`
  - Systemd Timer: `~/.config/systemd/user/rclone-bisync.timer` -> `~/dotfiles/systemd/.config/systemd/user/rclone-bisync.timer`
- **Log File** (untracked): `~/.config/rclone/rclone-bisync.log`
