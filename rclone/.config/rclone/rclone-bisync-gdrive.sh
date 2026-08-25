#!/usr/bin/env bash
set -euo pipefail

# Configuration
LOCAL_DIR="${HOME}"
REMOTE_TARGET="gdrive:Backup/home_bine"
FILTER_FILE="${HOME}/.config/rclone/bisync-filters.txt"
LOG_FILE="${HOME}/.config/rclone/rclone-bisync.log"

# Ensure rclone configuration exists
if ! rclone config file 2>/dev/null | grep -q "rclone.conf" || [ ! -f "$(rclone config file 2>/dev/null | tail -n 1)" ]; then
    echo "[ERROR] rclone.conf not found. Please run 'rclone config' first to set up the 'gdrive' remote." | tee -a "${LOG_FILE}"
    exit 1
fi

echo "=== Starting rclone bisync: $(date) ===" >> "${LOG_FILE}"

# Run rclone bisync with configured filters, conflict resolution, and max size limits
rclone bisync "${LOCAL_DIR}" "${REMOTE_TARGET}" \
    --filter-from "${FILTER_FILE}" \
    --max-size 100M \
    --conflict-resolve newer \
    --conflict-loser copy \
    --verbose \
    "$@" 2>&1 | tee -a "${LOG_FILE}"

echo "=== Finished rclone bisync: $(date) ===" >> "${LOG_FILE}"
