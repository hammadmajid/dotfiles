#!/usr/bin/env bash
# Watches the locally synced folders with inotify and starts rclone-bisync.service
# once changes settle: QUIET seconds without an event, or CAP seconds after the
# first event when writes never pause. Remote-only changes are picked up by the timer.
set -uo pipefail

QUIET=30
CAP=300
SCRIPT="${HOME}/.config/rclone/rclone-bisync-gdrive.sh"

# Same pair list as the sync script, existing local folders only.
mapfile -t NAMES < <(sed -nE 's/^\s+"([A-Za-z0-9_\/-]+)=[^"]+"$/\1/p' "${SCRIPT}")
DIRS=()
for n in "${NAMES[@]}"; do
    [ -d "${HOME}/${n}" ] && DIRS+=("${HOME}/${n}")
done
if [ "${#DIRS[@]}" -eq 0 ]; then
    echo "no synced folders exist, nothing to watch"
    exit 1
fi

echo "watching: ${DIRS[*]}"

inotifywait -m -r -q \
    -e close_write -e moved_to -e moved_from -e create -e delete -e attrib \
    --exclude '(/\.Trash|\.conflict[0-9]*|~lock\.|\.goutputstream|\.tmp$|\.part$|\.crdownload$|\.partial$|\.swp$)' \
    --format '%w%f' "${DIRS[@]}" |
while true; do
    # Blocks until the first event. A closed pipe means inotifywait died; exit so systemd restarts us.
    IFS= read -r first || exit 1
    deadline=$(( $(date +%s) + CAP ))
    while IFS= read -r -t "${QUIET}" _; do
        [ "$(date +%s)" -ge "${deadline}" ] && break
    done
    echo "settled after change to ${first#${HOME}/}, syncing"
    # Blocks until the run finishes. If a run is already in progress this joins it
    # instead of starting a second one; events arriving meanwhile queue in the pipe.
    systemctl --user start rclone-bisync.service
done
