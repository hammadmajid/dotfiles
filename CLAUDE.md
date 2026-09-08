# Machine notes

Fedora 44 Workstation with the CachyOS kernel, GNOME, fish shell. This repo is stow-managed: each top-level dir mirrors `$HOME` and `stow */` symlinks it in (see README.md). Deleting a symlink in `~/.config` never touches the repo copy.

## Root access

Passwordless sudo is configured for this user. Run `sudo` directly; never expect a password prompt to work.

## Package sources and gotchas

- **Terra repo is enabled.** Vendor RPMs that reuse a Terra package name (OpenCode did) conflict with Terra's copy. Install with `--allowerasing`, then pin with `dnf config-manager setopt terra.excludepkgs=<name>` so `dnf upgrade` can't swap it back. dnf5 writes that to `/etc/dnf/repos.override.d/`, not the `.repo` file.
- **Legacy CA bundle path is gone.** Fedora 44 no longer ships `/etc/pki/tls/certs/ca-bundle.crt`. Third-party `.repo` files with `sslcacert=` pointing there fail with curl error 77; repoint them to `/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem`.
- **1024x1024 icons are invisible.** The hicolor `index.theme` has no 1024x1024 entry, so a package that ships its icon only there shows a blank launcher. Resize copies into `512x512`, `256x256`, `128x128` under `/usr/share/icons/hicolor/*/apps/` and run `gtk-update-icon-cache -f -t /usr/share/icons/hicolor`. Those copies outlive package upgrades; an edited package-owned `.desktop` file does not.
- **AppImages live in `~/.appimages`**, launchers in `~/.local/share/applications`, autostart in `~/.config/autostart`. AppImage self-integration drops a second `appimagekit-*.desktop` launcher beside the hand-written one; delete the appimagekit copy.

## Removing software

Inventory before acting: rpm, flatpak, AppImage, `/opt`, `~/.local/bin`, leftover `.repo` files and GPG keys under `/etc/pki/rpm-gpg`. Dry-run with `dnf remove --assumeno`, report what will go, and wait for confirmation. Home-directory data (`~/.config`, `~/.local/share`, `~/.cache`) stays unless the user says to purge it. Password databases and similar user files stay even then.

## Google Drive sync

`rclone.md` documents the rclone bisync setup: what syncs, the Google Cloud OAuth client, first-run and new-device steps.
