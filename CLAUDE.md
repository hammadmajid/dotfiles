# Managing this laptop

HP EliteBook 820 G3: i5-6300U (4 threads), 12 GiB RAM, 256 GB NVMe as one btrfs partition (`zstd:1`, subvolumes `root` and `home`), Intel HD 520. Fedora 44 Workstation, stock kernel, GNOME 50 on Wayland, fish shell, Ghostty terminal. Owner: Hammad Majid, git author of everything here, working under kryft.dev and wowaitech.com.

This repo is the machine's operating manual. Stow-managed: each top-level dir mirrors `$HOME` and `stow */` symlinks it in (README.md). Deleting a symlink in `~/.config` never touches the repo copy. Three documents carry the detail and are the places to update when their subject changes:

- `packages.md` — everything user-installed, by channel. Every install or removal ends with a row added or removed here and a commit.
- `rclone.md` — Google Drive two-way sync: pairs, watcher, timer, notifications, `drive` and `sys`, new-device steps.
- `secrets.md` — self-hosted Infisical, the project map, `envs`, the Doppler fallback, CLI gotchas.

Commits are signed through the 1Password SSH agent. A "could not connect to socket" error means 1Password is locked; ask the user to unlock it and retry. Push to `v0`.

## Root access

Passwordless sudo is configured. Run `sudo` directly; a password prompt will never be answered.

## Installing software

Prefer, in order: Fedora or Terra RPM, vendor RPM repo, Copr, system flatpak, npm global (CLI tools, lands under mise's node), AppImage through Gear Lever. For a vendor repo, fetch the vendor's setup script, read it, and write the `.repo` file by hand with the same content; the script itself stays unexecuted. Record the result in `packages.md`.

- **Terra repo is enabled.** Vendor RPMs that reuse a Terra package name (OpenCode did) conflict with Terra's copy. Install with `--allowerasing`, then pin with `dnf config-manager setopt terra.excludepkgs=<name>` so `dnf upgrade` can't swap it back. dnf5 writes that to `/etc/dnf/repos.override.d/`, not the `.repo` file.
- **Legacy CA bundle path is gone.** Fedora 44 no longer ships `/etc/pki/tls/certs/ca-bundle.crt`. Third-party `.repo` files with `sslcacert=` pointing there fail with curl error 77; repoint them to `/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem`.
- **1024x1024 icons are invisible.** The hicolor `index.theme` has no 1024x1024 entry, so a package that ships its icon only there shows a blank launcher. Resize copies into `512x512`, `256x256`, `128x128` under `/usr/share/icons/hicolor/*/apps/` and run `gtk-update-icon-cache -f -t /usr/share/icons/hicolor`. Those copies outlive package upgrades; an edited package-owned `.desktop` file does not.
- **AppImages live in `~/.appimages`**, launchers in `~/.local/share/applications`, autostart in `~/.config/autostart`. AppImage self-integration drops a second `appimagekit-*.desktop` launcher beside the hand-written one; delete the appimagekit copy.
- **Kernel** is stock Fedora; three kernels are kept by dnf's installonly limit. A running kernel can only be removed after a reboot into another one.

## Removing software

Inventory before acting: rpm, flatpak, AppImage, `/opt`, `~/.local/bin`, leftover `.repo` files and GPG keys under `/etc/pki/rpm-gpg`. Dry-run with `dnf remove --assumeno`, report what will go, and wait for confirmation. Home-directory data (`~/.config`, `~/.local/share`, `~/.cache`, `~/.var/app`) stays unless the user says to purge it. Password databases and similar user files stay even then.

Residue an AppImage or Electron app leaves after Gear Lever removes it: its `.desktop` launcher and any `x-scheme-handler` line in `~/.config/mimeapps.list` (then `update-desktop-database ~/.local/share/applications`), `~/.config/<app>`, `~/.cache/<app>`. A flatpak that was renamed leaves its old app id under `~/.var/app`. The long key list in `/etc/pki/rpm-gpg` is the stock `distribution-gpg-keys` package, not residue.

## Disk

`du` reports uncompressed size, so it reads about 40% above `df` on this filesystem. The space is almost all under `$HOME`; `/usr` is 17 GB and `/var` 5 GB. Recurring consumers worth checking before anything else: `~/.local/share/Trash`, the pnpm store (`pnpm store prune`), `~/.cache/{google-chrome,go-build,pnpm}`, `~/.npm`, `~/.bun/install`, the Android toolchain (`~/Android`, `~/.android`, `~/.gradle`, `~/flutter`, `~/.pub-cache`, all live). `~/dotfiles/helix/.config/helix/runtime` is a gitignored 1.8 GB copy of what the helix RPM already ships in `/usr/share/helix`.

A `.git` directory far bigger than `git count-objects -vH` reports as packed is full of `tmp_pack_*` files: a corrupt loose object makes every auto-gc abort and leave one behind. Delete the temp packs, find the missing blob with `git fsck`, `git fetch origin <blob-sha>` restores it from GitHub, then `git gc`.

## Files and sync

`~/Code` holds one directory per domain plus `.trash/` and `.archive/` for old copies; no `.env` is tracked in any repo. `~/Downloads` is synced to Google Drive in full, OAuth client JSONs and backup-code files excepted by name, so anything dropped there is on Drive within a minute. Runtime state: `~/.local/state/drive/` (last run, muted skips), `/run/user/1000/sys-sample`, `~/.cache/rclone/bisync/`. Details in `rclone.md`.

## Secrets

`secrets.md` has the map. Never read a secret value: move env files through `$XDG_RUNTIME_DIR` and compare with `envdiff`, which prints keys and hash counts only. `infisical secrets set` masks values by default; `--show-values` stays unused. `rclone.conf` holds an OAuth token and stays out of this repo.

## Tasks

Todoist through `td` (the `todoist-cli` skill is installed). Projects: Inbox, Kryft, University, WowAI. Follow-ups from a session go to Kryft, or WowAI for wowaitech.com work, when the user asks to file them. Broad changes get `--dry-run` first; deletes need the user's explicit yes.

## Browser

Chrome profile directories under `~/.config/google-chrome`: `Default` is Hammad, `Profile 2` Kryft, `Profile 3` University, `Profile 5` wowaitech. Chrome Sync overwrites any direct edit to a profile's `Bookmarks` file on the next start; restructure bookmarks through the bookmark manager, with an HTML import plus cut and paste for bulk changes.

## Writing fish and systemd here

- `status` is a fish builtin, hence the report card is `sys`. A function called from another function's file needs its own autoload file.
- `math` has no comparisons; `test -lt` works and accepts floats. `string replace` has no `-m`; `_` is read-only in `read`.
- Ghostty's bundled font renders the Material Design range of Nerd Font glyphs (U+F0000 and up) and drops the Font Awesome range, so icons come from Material Design.
- The greeting must stay under 100 ms: anything slower than a file read (systemctl, nmcli, dnf) is sampled once a minute by `sys-sample.service` and read from its file.
- User units enable with `WantedBy=default.target`. A oneshot service reads `activating` while it runs, so poll `ActiveState` until `inactive` or `failed` rather than `is-active`. Monotonic timers (`OnUnitActiveSec`) have no realtime next-elapse; compute it from the last start. `systemd-run --user notify-send` reaches the desktop from a unit.
