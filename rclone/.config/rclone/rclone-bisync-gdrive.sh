#!/usr/bin/env bash
set -uo pipefail

# Two-way sync of selected home folders to same-named top-level folders on Google Drive.
# Each pair is an independent rclone bisync with its own state.
# First run on a machine: pass --resync (applies to every pair).

FILTER_FILE="${HOME}/.config/rclone/bisync-filters.txt"
LOG_FILE="${HOME}/.config/rclone/rclone-bisync.log"

# local path => remote path
PAIRS=(
    "${HOME}/Documents=gdrive:Documents"
    "${HOME}/Pictures=gdrive:Pictures"
    "${HOME}/Videos=gdrive:Videos"
    "${HOME}/Templates=gdrive:Templates"
    "${HOME}/Scratchpad=gdrive:Scratchpad"
    "${HOME}/Downloads/Archive=gdrive:Downloads"
)

if [ ! -f "$(rclone config file 2>/dev/null | tail -n 1)" ]; then
    echo "[ERROR] rclone.conf not found. Run 'rclone config' to set up the 'gdrive' remote." | tee -a "${LOG_FILE}"
    exit 1
fi

echo "=== Starting rclone bisync: $(date) ===" >> "${LOG_FILE}"
status=0

for pair in "${PAIRS[@]}"; do
    local_dir="${pair%%=*}"
    remote_dir="${pair#*=}"

    if [ ! -d "${local_dir}" ]; then
        echo "[SKIP] ${local_dir} does not exist" | tee -a "${LOG_FILE}"
        continue
    fi

    echo "--- ${local_dir} <-> ${remote_dir}" | tee -a "${LOG_FILE}"
    # bisync requires both sides to exist; mkdir is a no-op if it already does
    rclone mkdir "${remote_dir}" 2>&1 | tee -a "${LOG_FILE}"
    rclone bisync "${local_dir}" "${remote_dir}" \
        --filter-from "${FILTER_FILE}" \
        --create-empty-src-dirs \
        --conflict-resolve newer \
        --conflict-loser copy \
        --verbose \
        "$@" 2>&1 | tee -a "${LOG_FILE}"
    rc=${PIPESTATUS[0]}
    if [ "${rc}" -ne 0 ]; then
        echo "[ERROR] bisync failed for ${local_dir} (exit ${rc})" | tee -a "${LOG_FILE}"
        status=1
    fi
done

echo "=== Finished rclone bisync: $(date) (status ${status}) ===" >> "${LOG_FILE}"
exit "${status}"
