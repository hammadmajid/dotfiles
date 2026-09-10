#!/usr/bin/env bash
set -uo pipefail

# Two-way sync of selected home folders to same-named top-level folders on Google Drive.
# Each pair is an independent rclone bisync with its own state.
#
# Usage:
#   rclone-bisync-gdrive.sh [rclone bisync flags...]
#   DRIVE_PAIRS="Documents Downloads/Archive" rclone-bisync-gdrive.sh   # subset of pairs
#   rclone-bisync-gdrive.sh --resync                                     # re-baseline (first run on a machine)
#
# Side effects besides the sync itself:
#   - desktop notifications on failure, on new .conflict files, on skipped pairs (unless muted)
#   - a machine-readable summary in $STATE_DIR/last-run, read by the `sys` and `drive` fish functions

FILTER_FILE="${HOME}/.config/rclone/bisync-filters.txt"
LOG_FILE="${HOME}/.config/rclone/rclone-bisync.log"
STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/drive"
MUTED_FILE="${STATE_DIR}/muted"          # pair names whose skip notifications are muted, one per line
LAST_RUN_FILE="${STATE_DIR}/last-run"    # key=value summary of the most recent run

# local path (relative to $HOME) => remote path
PAIRS=(
    "Documents=gdrive:Documents"
    "Pictures=gdrive:Pictures"
    "Videos=gdrive:Videos"
    "Templates=gdrive:Templates"
    "Scratchpad=gdrive:Scratchpad"
    "Downloads/Archive=gdrive:Downloads"
)

mkdir -p "${STATE_DIR}"

log() { echo "$*" | tee -a "${LOG_FILE}"; }

notify() { # notify <urgency> <summary> <body>
    command -v notify-send >/dev/null || return 0
    notify-send -a "Drive sync" -i folder-remote -u "$1" "$2" "$3" 2>/dev/null || true
}

count_conflicts() { # .conflict files across every existing local folder
    local pair d dirs=()
    for pair in "${PAIRS[@]}"; do
        d="${HOME}/${pair%%=*}"
        [ -d "$d" ] && dirs+=("$d")
    done
    [ "${#dirs[@]}" -gt 0 ] && find "${dirs[@]}" -name '*.conflict*' 2>/dev/null | wc -l || echo 0
}

write_last_run() { # write_last_run <status> <ran> <failed> <skipped> <new_conflicts> <error>
    local tmp="${LAST_RUN_FILE}.tmp"
    {
        echo "start=${START_EPOCH}"
        echo "end=$(date +%s)"
        echo "status=$1"
        echo "ran=$2"
        echo "failed=$3"
        echo "skipped=$4"
        echo "new_conflicts=$5"
        echo "conflicts=$(count_conflicts)"
        echo "error=$6"
    } > "${tmp}" && mv "${tmp}" "${LAST_RUN_FILE}"
}

is_muted() { [ -f "${MUTED_FILE}" ] && grep -qxF "$1" "${MUTED_FILE}"; }

# Only sync the pairs named in DRIVE_PAIRS when it is set.
pair_selected() {
    [ -z "${DRIVE_PAIRS:-}" ] && return 0
    local p
    for p in ${DRIVE_PAIRS}; do [ "$p" = "$1" ] && return 0; done
    return 1
}

START_EPOCH=$(date +%s)

# No network: skip quietly. NetworkManager's cached connectivity state costs nothing to read.
if [ "$(nmcli -g connectivity general 2>/dev/null)" = "none" ]; then
    echo "=== Skipped rclone bisync (no network): $(date) ===" >> "${LOG_FILE}"
    write_last_run offline "" "" "" 0 "no network"
    exit 0
fi

if [ ! -f "$(rclone config file 2>/dev/null | tail -n 1)" ]; then
    log "[ERROR] rclone.conf not found. Run 'rclone config' to set up the 'gdrive' remote."
    write_last_run 1 "" "" "" 0 "rclone.conf not found"
    notify critical "Drive sync failed" "rclone.conf not found"
    exit 1
fi

echo "=== Starting rclone bisync: $(date) ===" >> "${LOG_FILE}"
status=0
ran=()
failed=()
skipped=()
new_conflicts=()
last_error=""

for pair in "${PAIRS[@]}"; do
    name="${pair%%=*}"
    local_dir="${HOME}/${name}"
    remote_dir="${pair#*=}"

    pair_selected "${name}" || continue

    if [ ! -d "${local_dir}" ]; then
        log "[SKIP] ${local_dir} does not exist"
        skipped+=("${name}")
        continue
    fi

    log "--- ${local_dir} <-> ${remote_dir}"
    before=$(find "${local_dir}" -name '*.conflict*' 2>/dev/null | sort)

    # bisync requires both sides to exist; mkdir is a no-op if it already does
    rclone mkdir "${remote_dir}" 2>&1 | tee -a "${LOG_FILE}"
    out=$(rclone bisync "${local_dir}" "${remote_dir}" \
        --filter-from "${FILTER_FILE}" \
        --create-empty-src-dirs \
        --track-renames \
        --conflict-resolve newer \
        --conflict-loser num \
        --resilient \
        --recover \
        --max-lock 10m \
        --verbose \
        --color never \
        "$@" 2>&1; echo "rc=$?")
    rc="${out##*rc=}"
    out="${out%rc=*}"
    printf '%s' "${out}" >> "${LOG_FILE}"
    ran+=("${name}")

    if [ "${rc}" -ne 0 ]; then
        log "[ERROR] bisync failed for ${local_dir} (exit ${rc})"
        failed+=("${name}")
        status=1
        last_error=$(printf '%s' "${out}" | grep -E 'ERROR|Fatal|NOTICE' | grep -v -- '--conflict' | tail -n 1 | sed -E 's/^[0-9/ :]+//')
    fi

    after=$(find "${local_dir}" -name '*.conflict*' 2>/dev/null | sort)
    while IFS= read -r f; do
        [ -n "$f" ] && new_conflicts+=("${f#${HOME}/}")
    done < <(comm -13 <(printf '%s\n' "${before}") <(printf '%s\n' "${after}"))
done

echo "=== Finished rclone bisync: $(date) (status ${status}) ===" >> "${LOG_FILE}"
write_last_run "${status}" "${ran[*]:-}" "${failed[*]:-}" "${skipped[*]:-}" "${#new_conflicts[@]}" "${last_error}"

if [ "${#failed[@]}" -gt 0 ]; then
    notify critical "Drive sync failed: ${failed[*]}" "${last_error:-see ~/.config/rclone/rclone-bisync.log}"
fi

if [ "${#new_conflicts[@]}" -gt 0 ]; then
    body=$(printf '%s\n' "${new_conflicts[@]:0:5}")
    [ "${#new_conflicts[@]}" -gt 5 ] && body+=$'\n'"and $(( ${#new_conflicts[@]} - 5 )) more"
    notify normal "Drive sync: ${#new_conflicts[@]} conflict file(s) kept" "${body}"
fi

unmuted_skips=()
for s in "${skipped[@]:-}"; do
    [ -n "$s" ] && ! is_muted "$s" && unmuted_skips+=("$s")
done
if [ "${#unmuted_skips[@]}" -gt 0 ]; then
    notify normal "Drive sync skipped: ${unmuted_skips[*]}" "Local folder missing. Mute with: drive skip <name>"
fi

exit "${status}"
