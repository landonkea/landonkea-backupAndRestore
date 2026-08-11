#!/bin/bash
# Removes the scheduled weekly backup job installed by install-schedule.sh.
# WHAT: Unloads and deletes the launchd job.
# WHY: "launchctl unload" stops it from running again; deleting the
# plist keeps it from being reloaded at the next login. Neither step
# touches any backup folders that already exist under $HOME.
PLIST_PATH="$HOME/Library/LaunchAgents/com.landonkea.backupandrestore.plist"

if [ -f "$PLIST_PATH" ]; then
    launchctl unload "$PLIST_PATH" 2>/dev/null || true
    rm "$PLIST_PATH"
    echo "✅ Scheduled backup removed. backup.sh can still be run manually any time."
else
    echo "No scheduled backup job found."
fi
