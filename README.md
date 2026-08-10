# landonkea-backupAndRestore

A simple macOS developer backup and restore toolkit. Save everything you've installed and configured on your Mac, then restore it all on a new machine with two scripts.

## What It Backs Up

- **Homebrew packages**: command-line tools and desktop apps installed via Homebrew
- **Global npm packages**: JavaScript libraries available system-wide
- **Python packages**: libraries installed via pip
- **Ruby gems**: libraries installed via the gem system
- **Dotfiles**: `.zshrc`, `.bash_profile`, `.gitconfig`
- **SSH keys**: authentication keys for GitHub, servers, etc.

## How to Use

### Backing Up (on your current Mac)

```bash
cd landonkea-backupAndRestore
chmod +x backup.sh
./backup.sh
```

This creates a dated folder like `Mac_Backup_2026-07-26/` in your home directory. Move that folder to a **private** cloud drive or USB stick.

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

The backup folder contains your **SSH private keys** in `dotfiles/ssh_backup/`. These are secret files that authenticate you with GitHub, servers, and other services. **Never share this folder publicly** or upload it to a public repository. Store it on encrypted cloud storage or a physical drive you keep secure.
