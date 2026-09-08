# Google Drive two-way sync with rclone bisync

Selected home folders are kept in two-way sync with same-named top-level folders on Google Drive. Changes, including deletions, propagate in both directions. If a file changed on both sides, the newer copy wins and the older one is kept as a renamed copy.

## What syncs

| Local | Google Drive |
|---|---|
| `~/Documents` | `gdrive:Documents` |
| `~/Pictures` | `gdrive:Pictures` |
| `~/Videos` | `gdrive:Videos` |
| `~/Templates` | `gdrive:Templates` |
| `~/Scratchpad` | `gdrive:Scratchpad` |
| `~/Downloads/Archive` | `gdrive:Downloads` |

Nothing else in `~/Downloads` syncs. `~/Code`, `~/dotfiles`, SDKs, and dot-directories are never touched. There is no per-file size cap. Trash folders, lock files, and partial downloads are excluded via `bisync-filters.txt`.

The pair list lives in `rclone-bisync-gdrive.sh`. Add or remove a line there to change what syncs, then run the script once with `--resync`.

## Files

Stow package `rclone` puts these in `~/.config/rclone/`:

- `rclone-bisync-gdrive.sh` — loops over the pairs, runs `rclone bisync` on each
- `bisync-filters.txt` — exclusions applied to every pair
- `rclone.conf` — untracked, holds the OAuth token, mode 600
- `rclone-bisync.log` — untracked

Stow package `systemd` puts `rclone-bisync.service` and `rclone-bisync.timer` in `~/.config/systemd/user/`. The timer runs the script every 15 minutes.

## Google Cloud side

Own OAuth client in project `bine` (ID `bine-42`), Google Auth Platform:

- Branding filled in, authorised domain `hammadmajid.pages.dev`
- Publishing status **In production**, unverified. Leaving it in Testing makes refresh tokens expire every 7 days.
- Client "rclone", type Desktop app. The secret is only shown once at creation; it is stored in `rclone.conf`.

## First run on this machine

```bash
~/.config/rclone/rclone-bisync-gdrive.sh --resync
```

Then enable the timer:

```bash
systemctl --user daemon-reload
systemctl --user enable --now rclone-bisync.timer
```

## Bootstrapping a new device

1. Install `rclone` and `stow`, clone dotfiles, run `stow */` in `~/dotfiles`.
2. Recreate the remote. The client ID and secret are in the old machine's `rclone.conf`:
   ```bash
   rclone config create gdrive drive client_id=<id> client_secret=<secret> scope=drive
   ```
   This opens a browser for Google consent. Expect a "Google hasn't verified this app" warning; continue through it.
3. Pull everything down, then establish the bisync baseline and enable the timer:
   ```bash
   for d in Documents Pictures Videos Templates Scratchpad; do rclone copy gdrive:$d ~/$d -P; done
   rclone copy gdrive:Downloads ~/Downloads/Archive -P
   ~/.config/rclone/rclone-bisync-gdrive.sh --resync
   systemctl --user daemon-reload
   systemctl --user enable --now rclone-bisync.timer
   ```

## Checking on it

```bash
systemctl --user list-timers rclone-bisync.timer
systemctl --user status rclone-bisync.service
tail -50 ~/.config/rclone/rclone-bisync.log
```

If a run logs `Bisync aborted. Must run --resync to recover`, run the script once with `--resync` by hand.
