# Feature Ideas

Eighteen ideas for where `backup.sh` and `restore.sh` could go next. Every one of these ties directly to something the scripts already do or a gap that shows up when you actually read them, nothing generic bolted on for the sake of a longer list.

1. **`--dry-run` flag for both scripts.** Right now the only way to know what `backup.sh` will touch is to read the source or just run it. A dry-run mode would walk through every `backup_*` function and print what it *would* write (`Brewfile`, `dotfiles/zshrc.bak`, and so on) without touching disk. Same idea for `restore.sh`, which is more important there since restore overwrites real files in `$HOME` with zero confirmation.

2. **Restore should warn before overwriting existing dotfiles.** `restore_dotfiles()` currently does `cp "dotfiles/zshrc.bak" "$HOME/.zshrc"` unconditionally. If someone runs restore on a Mac that already has a `.zshrc` (not brand new, maybe testing, maybe a second account), that file is gone with no backup and no prompt. A simple check, "`.zshrc` already exists, overwrite? [y/N]", or an automatic `.zshrc.pre-restore` copy, would prevent a real "oops."

3. **A manifest file written at the end of `backup.sh`.** One `manifest.json` (or plain text) listing every file actually written this run, its size, and whether each backup function succeeded or was skipped (e.g. "Ruby gems: skipped, gem not found"). Right now that information only exists as scrolled-past terminal output.

4. **Selective backup/restore via flags.** `./backup.sh --only=dotfiles,ssh` or `./backup.sh --skip=vscode,secrets`. Useful for someone who just wants to grab SSH keys before wiping a drive, without waiting on a full Homebrew/npm/pip/gem sweep every time.

5. **Configurable retention count.** `BACKUP_RETENTION_COUNT=4` is hardcoded at the top of `backup.sh`. Making it a flag (`--keep=8`) or an environment variable read at the top of the script means someone with more disk space, or someone who wants tighter retention on a laptop, doesn't have to edit the script to change it.

6. **Hostname in the backup folder name.** Currently every backup is `Mac_Backup_<date>`. Anyone who runs this on two Macs and syncs both to the same cloud folder will get silent collisions or overwrites on days both machines back up. `Mac_Backup_<hostname>_<date>` fixes that with one line in `setup_backup_dir()`.

7. **Optional encryption for the secrets folder.** The README already has a whole section warning that `dotfiles/ssh_backup/`, `gnupg_backup/`, etc. are plaintext secrets. An optional step, `gpg --symmetric` the `dotfiles/` folder into one encrypted archive before the "backup complete" message, would let someone store the result somewhere less trusted than "private cloud drive" without changing the rest of the flow.

8. **A `verify` mode that checks a past backup instead of making a new one.** `./backup.sh --verify Mac_Backup_2026-07-22` could confirm the folder isn't missing expected files, empty where it shouldn't be, or truncated, useful right before deleting an older machine, when finding out a backup was broken should not happen mid-restore on the new one.

9. **Post-backup cloud sync as an optional final step.** The README currently ends with "move that folder to a private cloud drive... yourself." An opt-in `rclone copy` (or plain `cp` to an already-mounted iCloud Drive/Dropbox path) as the last step of `backup.sh`, controlled by an environment variable like `BACKUP_SYNC_TARGET`, would close that manual gap for people who already have rclone configured.

10. **Restore install results reported per package, not just success/fail as a block.** `xargs npm install -g < global-npm-packages.txt` currently either mostly works or silently drops whichever packages failed inside the batch. Switching to a loop that installs one package at a time and logs failures by name would turn "some npm packages didn't come back and I don't know which" into an actual list to act on.

11. **A restore log file, mirroring the backup log.** `backup.sh` already writes to `~/Library/Logs/landonkea-backupandrestore.log` when run by launchd. `restore.sh` writes nothing anywhere, everything only lives in scrollback. A `restore.sh 2>&1 | tee ~/restore.log` built into the script itself (not left to the user to remember) would give something to check after the fact if part of the restore silently didn't happen.

12. **Docker config backup.** `~/.docker/config.json` and `docker context ls` output aren't covered by anything today, and plenty of the same developers who use nvm/pyenv/rbenv also use Docker daily. Same pattern as the existing `backup_secrets()` function: copy if present, skip quietly if not.

13. **iTerm2 / Terminal.app preferences.** Terminal customization (color schemes, profiles, window settings) is exactly the kind of "tedious to recreate from memory" config this tool already backs up for VS Code. iTerm2 keeps its preferences in a plist under `~/Library/Preferences/com.googlecode.iterm2.plist` that can be copied the same way `backup_vscode_config()` copies `settings.json`.

14. **Multiple Git identity support.** `backup_dotfiles()` only grabs `~/.gitconfig`. Developers who split work/personal commits often use `~/.gitconfig-work`, `~/.gitconfig-personal`, and conditional includes. Backing up every `~/.gitconfig*` match instead of just the one file would catch that setup instead of quietly dropping half of it.

15. **User font backup.** Fonts installed to `~/Library/Fonts` are personal, sometimes paid for, and completely absent from Homebrew's radar unless installed via `brew install --cask font-*`. A simple `cp -R "$HOME/Library/Fonts/." "$BACKUP_DIR/fonts/"` would close that gap for anyone who's hand-installed a typeface.

16. **Interactive restore mode.** `restore.sh --interactive` could prompt once per section ("Restore VS Code extensions? [Y/n]") instead of always running the full sequence. Useful when restoring onto a Mac that already has some tools set up differently, and you don't want a fresh `settings.json` clobbering changes you already made on the new machine.

17. **A single `--check` command that reports what's installed vs. what the last backup expects.** Instead of only working in one direction (snapshot now, or reinstall from snapshot), a comparison mode against the most recent `Mac_Backup_*` folder would show what's changed since the last run, new Homebrew packages installed, npm globals added, without doing a full backup or restore.

18. **`restore.sh` should refuse to run twice unintentionally.** There's currently no guard against accidentally running restore a second time on the same machine (for instance, re-running it after a partial failure). A lightweight marker file, `~/.landonkea-backupandrestore-restored`, checked at the top of `main()` with a "this machine already has a restore recorded, continue anyway? [y/N]" prompt, would catch the accidental double-run without blocking a deliberate one.
