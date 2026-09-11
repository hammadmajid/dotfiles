# Google Drive two-way sync with rclone bisync

Selected home folders are kept in two-way sync with same-named top-level folders on Google Drive. Changes, including deletions and moves, propagate in both directions. If a file changed on both sides, the newer copy wins and the older one is kept beside it with a `.conflict` suffix.

## What syncs

| Local | Google Drive |
|---|---|
| `~/Documents` | `gdrive:Documents` |
| `~/Pictures` | `gdrive:Pictures` |
| `~/Videos` | `gdrive:Videos` |
| `~/Templates` | `gdrive:Templates` |
| `~/Scratchpad` | `gdrive:Scratchpad` |
| `~/Downloads` | `gdrive:Downloads` |

All of `~/Downloads` syncs, including its `Archive` subfolder. OAuth client JSONs and backup-code files are excluded by name so a stray download never lands on Drive. `~/Code`, `~/dotfiles`, SDKs, and dot-directories are never touched. There is no per-file size cap. Trash folders, lock files, and partial downloads are excluded via `bisync-filters.txt`.

The pair list lives in `rclone-bisync-gdrive.sh` and is the single source of truth: the watcher and the `drive` function read it from there. Add or remove a line, then run `drive resync` once and `drive watch` to restart the watcher.

## When it syncs

- **Local change**: `rclone-watch.service` keeps inotify watches on the six folders. After 30 seconds without further events (or 5 minutes of continuous writes) it starts the sync service. Idle cost is nil.
- **Remote change**: `rclone-bisync.timer` runs the sync 30 minutes after the previous run. Uploads from the Drive web or mobile app arrive on the laptop through this path only, so run `drive pull` if one is needed sooner.
- **No network**: the run is skipped silently and recorded as `offline`.

Both paths go through `rclone-bisync.service`, so two runs never overlap; a trigger during a run simply waits for it. Moves and renames are matched by hash (`--track-renames`) and become server-side moves on Drive instead of a delete plus re-upload. `--resilient --recover` lets the next run heal after a network blip without a resync. The service runs under `systemd-inhibit --what=sleep --mode=block`, so closing the lid mid-run keeps the laptop awake until the run ends (capped at 45 minutes by `TimeoutStartSec`); without it, listings caught by a suspend resume with an expired OAuth token, fail with 401, and abort the pair until the next run.

## Notifications

The sync script sends desktop notifications itself:

- **Failure** of any pair: critical, stays until dismissed, names the pair and the last error line.
- **Conflict files** created by a successful run: normal, lists up to five paths.
- **Skipped pair** because the local folder is missing: normal, on every run, until muted with `drive skip <pair>`.

## Day to day

`sys` prints the report card, also shown at the top of every new terminal: an aligned grid of icon, label and value cells (3 or 4 columns depending on terminal width) covering cpu, ram, swap, temperature, disk, wifi, throughput, tailscale, battery, failed units, pending updates, uptime, and the sync cells: age of the last run, time to the next timer run, watcher state, conflict count. Extra lines appear only for failures, skips or a stale sampler. `sys -v` adds mounts, all sensors, failed unit names and the full `drive status`. Icons are Nerd Font Material Design glyphs; the Font Awesome range does not render in ghostty's bundled font.

`drive` is the control surface:

| Command | Does |
|---|---|
| `drive sync [pair]` | run now and follow the output; `pull` and `push` are aliases; a pair name limits it to one folder |
| `drive status` | summary line, last-run details, unit states, conflict files |
| `drive conflicts` | list `.conflict` files to resolve by hand |
| `drive log [-f\|N]` | tail or follow the log |
| `drive resync [pair]` | re-baseline after asking; pauses the timer and watcher while it runs |
| `drive watch` | show the watcher, timer and sampler, start any that are down |
| `drive skip [pair]` | list or toggle muted skip notifications |

Pair names are the local path relative to `~`, for example `Documents` or `Downloads`.

## Files

Stow package `rclone` puts these in `~/.config/rclone/`:

- `rclone-bisync-gdrive.sh` — the sync: loops over the pairs, notifies, writes the last-run summary
- `rclone-watch.sh` — inotify watcher with debounce, started by `rclone-watch.service`
- `bisync-filters.txt` — exclusions applied to every pair
- `rclone.conf` — untracked, holds the OAuth token, mode 600
- `rclone-bisync.log` — untracked

Stow package `systemd` puts these in `~/.config/systemd/user/`: `rclone-bisync.service` and `.timer`, `rclone-watch.service`, and `sys-sample.service`, the once-a-minute sampler that feeds `sys` (installed from stow package `sys` as `~/.local/bin/sys-sample`).

Stow package `fish` holds the `drive`, `sys` and helper functions. Runtime state lives in `~/.local/state/drive/` (`last-run`, `muted`) and bisync's own listings in `~/.cache/rclone/bisync/`.

Needs `inotify-tools` from Fedora for the watcher and `libnotify` for notifications.

## Google Cloud side

Own OAuth client in project `bine` (ID `bine-42`), Google Auth Platform:

- Branding filled in, authorised domain `hammadmajid.pages.dev`
- Publishing status **In production**, unverified. Leaving it in Testing makes refresh tokens expire every 7 days.
- Client "rclone", type Desktop app. The secret is only shown once at creation; it is stored in `rclone.conf`.

## Bootstrapping a new device

1. Install `rclone`, `inotify-tools` and `stow`, clone dotfiles, run `stow */` in `~/dotfiles`.
2. Recreate the remote. The client ID and secret are in the old machine's `rclone.conf`:
   ```bash
   rclone config create gdrive drive client_id=<id> client_secret=<secret> scope=drive
   ```
   This opens a browser for Google consent. Expect a "Google hasn't verified this app" warning; continue through it.
3. Pull everything down, establish the bisync baseline, enable the units:
   ```bash
   for d in Documents Pictures Videos Templates Scratchpad; do rclone copy gdrive:$d ~/$d -P; done
   rclone copy gdrive:Downloads ~/Downloads -P
   ~/.config/rclone/rclone-bisync-gdrive.sh --resync
   systemctl --user daemon-reload
   systemctl --user enable --now rclone-bisync.timer rclone-watch.service sys-sample.service
   ```

## When something is off

- `drive status` first, then `drive log 100`.
- `Bisync aborted. Must run --resync to recover` in the log: `drive resync <pair>` for that pair.
- Watcher or timer shown red in `sys`: `drive watch` restarts them; `journalctl --user -u rclone-watch.service` explains why it died.
- `sys` says the sampler is stale: `drive watch` restarts it too.
