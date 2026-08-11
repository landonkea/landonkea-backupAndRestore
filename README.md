# landonkea-backupAndRestore

A simple macOS developer backup and restore toolkit. Save everything you've installed and configured on your Mac, then restore it all on a new machine with two scripts.

## What It Backs Up

- **Homebrew packages**: command-line tools and desktop apps installed via Homebrew
- **Global npm packages**: JavaScript libraries available system-wide
- **Python packages**: libraries installed via pip
- **Ruby gems**: libraries installed via the gem system
- **Language versions**: nvm, pyenv, and rbenv version lists
- **Dotfiles**: `.zshrc`, `.zprofile`, `.zshenv`, `.bash_profile`, `.gitconfig`, global `.gitignore`, `.vimrc`, `.tmux.conf`, `.inputrc`, `.p10k.zsh`, `starship.toml`
- **VS Code**: installed extensions, `settings.json`, `keybindings.json`
- **App inventory**: Mac App Store apps (via `mas`) and everything in `/Applications`
- **Scheduled tasks**: crontab and user `LaunchAgents`
- **SSH keys**: authentication keys for GitHub, servers, etc.
- **Other secrets**: GPG keys, AWS/gcloud/kube credentials, npm/yarn registry configs (only backed up if present on the machine)

## How to Use

### Backing Up (on your current Mac)

```bash
cd landonkea-backupAndRestore
chmod +x backup.sh
./backup.sh
```

This creates a dated folder like `Mac_Backup_2026-07-26/` in your home directory. Move that folder to a **private** cloud drive or USB stick. Only the 4 most recent dated folders are kept, backup.sh deletes older ones automatically each time it runs.

### Running It Automatically Every Week

```bash
cd landonkea-backupAndRestore
schedule/install-schedule.sh
```

This installs a launchd job (macOS's built-in scheduler) that runs `backup.sh` every Sunday at 10:00 AM, so it happens without needing to remember. If the Mac is asleep or off at that time, launchd runs it the next time the Mac is awake instead of skipping it.

- Log output: `~/Library/Logs/landonkea-backupandrestore.log`
- Run it immediately instead of waiting for Sunday: `launchctl start com.landonkea.backupandrestore`
- Turn scheduling off: `schedule/uninstall-schedule.sh` (this only removes the schedule, `backup.sh` can still be run by hand any time)

### Restoring (on your new Mac)

1. Copy the backup folder to your new Mac
2. Open Terminal and navigate into the backup folder:

```bash
cd ~/Mac_Backup_2026-07-26
chmod +x /path/to/restore.sh
/path/to/restore.sh
```

3. Restart your terminal when it finishes

## Security Note

The backup folder contains your **SSH private keys** in `dotfiles/ssh_backup/`, and, if present on your machine, **GPG keys** (`dotfiles/gnupg_backup/`), **AWS/gcloud/kube credentials** (`dotfiles/aws_backup/`, `dotfiles/gcloud_backup/`, `dotfiles/kube_backup/`), and **registry auth tokens** (`dotfiles/npmrc.bak`, `dotfiles/yarnrc.bak`). These are all secret files that authenticate you with GitHub, cloud providers, and other services. **Never share this folder publicly** or upload it to a public repository. Store it on encrypted cloud storage or a physical drive you keep secure.
