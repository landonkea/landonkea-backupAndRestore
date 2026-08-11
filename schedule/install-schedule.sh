#!/bin/bash
# --- PROJECT CONTEXT ---
# Installs a launchd job that runs ../backup.sh automatically every
# Sunday at 10:00 AM, so backups happen on their own instead of relying
# on remembering to run backup.sh by hand.

# WHAT: Copies the plist template next to this script into
# ~/Library/LaunchAgents, filling in the real absolute path to backup.sh
# and a log file location, then loads it with launchctl.
# HOW: "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" resolves this
# script's own directory to an absolute path regardless of where it's
# run from, so SCRIPT_PATH always points at the real backup.sh next to
# it rather than depending on the caller's current directory. "sed"
# swaps the __SCRIPT_PATH__/__LOG_PATH__ placeholders in the template for
# those real paths. "launchctl unload" is run first and allowed to fail
# (the "|| true") in case no job is currently loaded, "launchctl load -w"
# then loads the job and marks it enabled so it survives a reboot.
# WHY: launchd jobs need absolute paths, not relative ones, and must live
# in ~/Library/LaunchAgents by convention, this script does that
# translation once instead of asking for it to be done by hand.
SCHEDULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCHEDULE_DIR")"
SCRIPT_PATH="$REPO_DIR/backup.sh"
LOG_PATH="$HOME/Library/Logs/landonkea-backupandrestore.log"
PLIST_NAME="com.landonkea.backupandrestore.plist"
INSTALLED_PLIST="$HOME/Library/LaunchAgents/$PLIST_NAME"

mkdir -p "$HOME/Library/LaunchAgents"

sed -e "s|__SCRIPT_PATH__|$SCRIPT_PATH|g" -e "s|__LOG_PATH__|$LOG_PATH|g" \
    "$SCHEDULE_DIR/$PLIST_NAME" > "$INSTALLED_PLIST"

launchctl unload "$INSTALLED_PLIST" 2>/dev/null || true
launchctl load -w "$INSTALLED_PLIST"

echo "✅ Scheduled weekly backup installed: runs every Sunday at 10:00 AM."
echo "   Log file: $LOG_PATH"
echo "   To run it immediately instead of waiting for Sunday: launchctl start com.landonkea.backupandrestore"
echo "   To remove the schedule: schedule/uninstall-schedule.sh"
