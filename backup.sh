#!/bin/bash
# This line tells the system to use the Bash shell to run this script.
# Bash is the default command-line program on macOS that reads and executes
# shell scripts like this one. Without this line, the system wouldn't know
# how to interpret the commands below. The #! at the start is called a
# "shebang", it's a special marker for the operating system.

# --- PROJECT CONTEXT ---
# This file is the BACKUP half of a macOS developer backup/restore toolkit.
# Its job is to collect all the things a developer has installed and configured
# on their Mac, apps, coding language packages, and secret SSH keys, and
# save them into one folder so they can be restored on a new Mac later.
#
# --- STRUCTURE ---
# WHAT: The script is organized as a series of small, single-purpose
# functions (one per backup category), plus a main() function at the
# bottom that calls them in order.
# WHY: Splitting the work into named functions makes each step easy to
# read, test, and reason about in isolation, e.g. you can tell exactly
# what "backup_ssh_keys" does without scrolling through unrelated code
# for Homebrew or npm. It also means adding or removing a backup step
# later is a one-line change in main(), not a rewrite of a giant block.
# HOW: Every function below does exactly one job and is named after that
# job. Originally this covered Homebrew, npm/pip/gem, three dotfiles, and
# SSH keys only; since then, coverage was widened to also capture language
# version managers, editor config, installed-app inventory, scheduled
# tasks, and non-SSH secrets (GPG, cloud CLIs, registry tokens), each as
# its own function following the same one-job pattern.

# --- PATH SETUP (for scheduled/unattended runs) ---
# WHAT: Adds common tool install locations to PATH before anything else runs.
# HOW: When this script is run by hand from an interactive terminal, PATH
# already includes everything .zshrc set up. When it's run by launchd on
# a schedule (see schedule/), launchd starts jobs with a minimal PATH
# ("/usr/bin:/bin:/usr/sbin:/sbin") that doesn't know about Homebrew,
# rbenv, or pyenv, so "brew", "code", "mas", "pyenv", and "rbenv" would
# all silently fail to be found. This line prepends their usual install
# locations for both Apple Silicon (/opt/homebrew) and Intel (/usr/local)
# Macs, plus rbenv/pyenv's own bin folders, before falling back to
# whatever PATH was already set.
# WHY: A scheduled backup that silently skips every tool because it
# can't find any of them is worse than no backup at all, it looks
# successful in the log but records almost nothing.
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:$HOME/.rbenv/bin:$HOME/.pyenv/bin:$PATH"

# =====================================================================
# SECTION 1: SET UP THE BACKUP FOLDER
# =====================================================================

# WHAT: Builds the backup folder path and creates it.
# HOW: BACKUP_DIR is a variable, a labeled box where we store a value,
# here a full file path like "/Users/yourname/Mac_Backup_2026-07-26".
# The $(date +%Y-%m-%d) part runs a date command that outputs today's
# date in year-month-day format, so each backup gets its own uniquely
# dated folder and never overwrites a previous backup. mkdir -p creates
# that folder; -p means "make parent directories if needed" and "don't
# complain if it already exists."
# WHY: A fresh, dated, dedicated folder keeps every backup run isolated
# and traceable, and guarantees later steps have somewhere safe to write.
setup_backup_dir() {
    BACKUP_DIR="$HOME/Mac_Backup_$(date +%Y-%m-%d)"
    mkdir -p "$BACKUP_DIR"
    # Prints a friendly message to the terminal so the user knows the
    # backup process has started and where the files will be saved. The
    # emoji is just decoration to make the output easier to read at a glance.
    echo "🏁 Starting system backup into: $BACKUP_DIR"
}

# =====================================================================
# SECTION 2: BACKUP HOMEBREW PACKAGES (apps installed via the terminal)
# =====================================================================

# WHAT: Saves a list of every Homebrew-installed app/tool as a Brewfile.
# WHY: Homebrew is a free package manager for macOS, it lets you install
# developer tools and apps from the terminal instead of downloading them
# from a website. Saving this list means everything can be reinstalled
# later with one command (see restore.sh).
# HOW: "brew bundle dump --describe --force --file=..." writes a Brewfile
# listing every installed app/tool directly to an absolute path inside
# BACKUP_DIR; --describe adds helpful comments next to each name, --force
# overwrites the file if it already exists without asking. Using --file
# with an absolute path means this step never has to change the script's
# working directory, so a failure here can't take down later steps that
# don't depend on that directory being cwd.
backup_homebrew_packages() {
    echo "📦 Backing up Homebrew packages..."
    brew bundle dump --describe --force --file="$BACKUP_DIR/Brewfile"
}

# =====================================================================
# SECTION 3: BACKUP CODING LANGUAGE PACKAGES
# =====================================================================
# Many developers use coding languages like JavaScript (via NPM),
# Python (via PIP), or Ruby (via GEM). Each language has its own system
# for installing extra libraries. This section saves a list of every
# extra library you've installed for each language.

# WHAT: Saves globally-installed package lists for Node, Python, and Ruby.
# HOW: For each language, we redirect the package manager's list output
# into a text file inside BACKUP_DIR, hide errors with 2>/dev/null so a
# missing tool doesn't crash the script, and print a friendly fallback
# message with "|| echo ..." if the tool isn't installed.
#   - npm list -g --depth=0: "-g" means global packages (available
#     system-wide, not just in one project), "--depth=0" means only
#     top-level packages, not their hundreds of sub-dependencies.
#   - pip list --format=freeze: outputs "package==version" lines that
#     pip can read back in directly during restore.
#   - gem list: lists every installed Ruby gem.
# WHY: These lists let restore.sh reinstall the exact same libraries
# (and, for Python, the exact same versions) on a new machine.
backup_language_packages() {
    echo "🌐 Backing up language packages..."

    npm list -g --depth=0 > "$BACKUP_DIR/global-npm-packages.txt" 2>/dev/null || echo "Node/NPM not found, skipping."
    pip list --format=freeze > "$BACKUP_DIR/requirements.txt" 2>/dev/null || echo "Python/PIP not found, skipping."
    gem list > "$BACKUP_DIR/rubygems.txt" 2>/dev/null || echo "Ruby/Gems not found, skipping."
}

# =====================================================================
# SECTION 4: BACKUP LANGUAGE VERSION MANAGERS (nvm, pyenv, rbenv)
# =====================================================================
# backup_language_packages saves which packages are installed, but not
# which language runtime version they're installed under. If Node,
# Python, or Ruby versions are managed with nvm/pyenv/rbenv instead of
# whatever Homebrew ships, that version choice needs saving separately.

# WHAT: Saves the list of installed runtime versions for nvm, pyenv, and rbenv.
# HOW: nvm isn't a real executable, it's a shell function loaded by
# sourcing "$HOME/.nvm/nvm.sh", so it's sourced directly here instead of
# checked with "command -v". pyenv and rbenv are real executables, so
# "command -v" works for them. Each tool's version-listing output is
# saved to its own text file in BACKUP_DIR; a missing tool is skipped
# without error.
# WHY: Restoring the exact runtime versions avoids a package that needs
# a specific Node/Python/Ruby version behaving differently under
# whatever version Homebrew's default install happens to be.
backup_language_versions() {
    echo "🧬 Backing up language version manager state..."

    if [ -s "$HOME/.nvm/nvm.sh" ]; then
        source "$HOME/.nvm/nvm.sh"
        nvm ls --no-colors > "$BACKUP_DIR/nvm-versions.txt" 2>/dev/null
    fi

    command -v pyenv &> /dev/null && pyenv versions > "$BACKUP_DIR/pyenv-versions.txt" 2>/dev/null
    command -v rbenv &> /dev/null && rbenv versions > "$BACKUP_DIR/rbenv-versions.txt" 2>/dev/null
}

# =====================================================================
# SECTION 5: BACKUP DOTFILES (hidden configuration files)
# =====================================================================
# Dotfiles are hidden configuration files in your home folder. They start
# with a dot (.) which makes them invisible in Finder by default. They
# control things like how your terminal looks, what Git knows about you,
# and what shell shortcuts you've set up. Losing these on a new Mac means
# hours of re-configuring, so we back them up.

# WHAT: Copies shell, Git, editor, and prompt config files into dotfiles/.
# HOW: Creates a "dotfiles" subfolder inside BACKUP_DIR to keep these
# files organized in one place, then copies each config file from $HOME
# with a ".bak" suffix. Each copy's "2>/dev/null" hides the error if that
# particular file doesn't exist on this machine, this is expected (not
# everyone uses tmux, or Powerlevel10k, or Starship) and not a failure.
# WHY: These files carry personal shell/editor/Git configuration that is
# tedious to recreate by hand, restoring them saves hours of setup.
backup_dotfiles() {
    echo "🔒 Copying configuration files..."
    mkdir -p "$BACKUP_DIR/dotfiles"

    cp "$HOME/.zshrc" "$BACKUP_DIR/dotfiles/zshrc.bak" 2>/dev/null
    cp "$HOME/.zprofile" "$BACKUP_DIR/dotfiles/zprofile.bak" 2>/dev/null
    cp "$HOME/.zshenv" "$BACKUP_DIR/dotfiles/zshenv.bak" 2>/dev/null
    cp "$HOME/.bash_profile" "$BACKUP_DIR/dotfiles/bash_profile.bak" 2>/dev/null
    cp "$HOME/.gitconfig" "$BACKUP_DIR/dotfiles/gitconfig.bak" 2>/dev/null
    cp "$HOME/.gitignore_global" "$BACKUP_DIR/dotfiles/gitignore_global.bak" 2>/dev/null
    cp "$HOME/.vimrc" "$BACKUP_DIR/dotfiles/vimrc.bak" 2>/dev/null
    cp "$HOME/.tmux.conf" "$BACKUP_DIR/dotfiles/tmux_conf.bak" 2>/dev/null
    cp "$HOME/.inputrc" "$BACKUP_DIR/dotfiles/inputrc.bak" 2>/dev/null
    cp "$HOME/.p10k.zsh" "$BACKUP_DIR/dotfiles/p10k_zsh.bak" 2>/dev/null
    cp "$HOME/.config/starship.toml" "$BACKUP_DIR/dotfiles/starship_toml.bak" 2>/dev/null
}

# =====================================================================
# SECTION 6: BACKUP EDITOR CONFIG (VS Code)
# =====================================================================
# VS Code stores installed extensions and personal settings/keybinding
# overrides outside of any dotfile, in its own app support folder. Losing
# these means re-finding and reinstalling every extension by hand.

# WHAT: Saves the list of installed VS Code extensions and copies its
# settings.json and keybindings.json.
# HOW: "code --list-extensions" prints one extension ID per line, which
# restore.sh can feed straight back into "code --install-extension". The
# settings/keybindings files live under VS Code's per-user "User" folder;
# both are copied only if present, missing either one is not an error.
# WHY: Extensions and editor settings are personal, hard-won configuration
# that's tedious to rebuild from memory on a new machine.
backup_vscode_config() {
    if command -v code &> /dev/null; then
        echo "🧩 Backing up VS Code extensions and settings..."
        mkdir -p "$BACKUP_DIR/dotfiles/vscode"

        code --list-extensions > "$BACKUP_DIR/dotfiles/vscode/extensions.txt" 2>/dev/null
        cp "$HOME/Library/Application Support/Code/User/settings.json" "$BACKUP_DIR/dotfiles/vscode/settings.json" 2>/dev/null
        cp "$HOME/Library/Application Support/Code/User/keybindings.json" "$BACKUP_DIR/dotfiles/vscode/keybindings.json" 2>/dev/null
    fi
}

# =====================================================================
# SECTION 7: BACKUP APP INVENTORY (Mac App Store + manually installed apps)
# =====================================================================
# The Brewfile only covers apps installed through Homebrew. Anything
# installed via the Mac App Store, or dragged into /Applications from a
# downloaded .dmg, is invisible to it, so it's recorded separately here.

# WHAT: Saves the list of Mac App Store apps and everything in /Applications.
# HOW: "mas list" (if the "mas" CLI is installed) prints each App Store
# app's ID, name, and version; restore.sh can pass the ID straight to
# "mas install". The /Applications listing is reference-only, there's no
# reliable command-line installer for apps downloaded manually, so it's
# saved as a checklist to work through by hand.
# WHY: Between Homebrew, the Mac App Store, and manual installs, apps
# tend to end up in all three places, this makes sure none of them are
# silently forgotten in a restore.
backup_app_inventory() {
    echo "🗂️  Backing up installed application inventory..."

    command -v mas &> /dev/null && mas list > "$BACKUP_DIR/mas-apps.txt" 2>/dev/null
    ls /Applications > "$BACKUP_DIR/applications-list.txt" 2>/dev/null
}

# =====================================================================
# SECTION 8: BACKUP SCHEDULED TASKS (cron jobs and LaunchAgents)
# =====================================================================
# Developers sometimes automate things with cron jobs or their own
# LaunchAgents (macOS's built-in scheduler), and both are easy to forget
# about entirely until something quietly stops running on the new machine.

# WHAT: Saves the current crontab and any user-created LaunchAgents.
# HOW: "crontab -l" prints the logged-in user's cron jobs; it exits with
# an error (not a crash) when none exist, which 2>/dev/null and the
# fallback echo handle quietly. LaunchAgents are copied with the
# "source/." form (copy the folder's contents) into an explicitly
# pre-made destination, not "cp -R source dest" (copy the folder itself).
# The latter only behaves the same on a first run, if BACKUP_DIR/LaunchAgents
# already exists, e.g. from an earlier run today, "cp -R" nests the whole
# source folder inside it instead of merging into it, one level deeper
# every rerun. Pre-creating the destination and copying contents avoids
# that regardless of how many times this runs against the same dated folder.
# WHY: A cron job or LaunchAgent that silently stops running on a new
# machine can be a hard thing to notice, let alone diagnose later.
backup_scheduled_tasks() {
    echo "⏰ Backing up cron jobs and LaunchAgents..."

    crontab -l > "$BACKUP_DIR/crontab.txt" 2>/dev/null || echo "No crontab found, skipping."
    if [ -d "$HOME/Library/LaunchAgents" ]; then
        mkdir -p "$BACKUP_DIR/LaunchAgents"
        cp -R "$HOME/Library/LaunchAgents/." "$BACKUP_DIR/LaunchAgents/"
    fi
}

# =====================================================================
# SECTION 9: BACKUP SSH KEYS (SECRET authentication keys)
# =====================================================================
# SSH keys are special secret files that let your computer prove its
# identity to servers like GitHub, university servers, or work servers.
# Without them, you'd have to type a password every single time you
# connect. They live in a hidden folder called .ssh in your home
# directory.
#
# --- SSH KEY SAFETY (read this before touching this function) ---
# WHAT the safety mechanism actually is: this script copies the real
# SSH private key out of ~/.ssh into the dated backup folder
# ($BACKUP_DIR, e.g. "Mac_Backup_2026-07-26/"). That backup folder is
# NOT itself protected by anything in this script, the protection lives
# one layer up, in this repo's .gitignore, which excludes every folder
# matching "Mac_Backup_*/" (and "*.bak" files) from version control. The
# other secrets backed up further down (Section 10) land in this same
# folder and rely on this exact same protection.
# HOW it holds together: as long as (a) this script keeps writing backups
# under the "$HOME/Mac_Backup_<date>" naming pattern, and (b) .gitignore
# keeps the "Mac_Backup_*/" pattern intact, a real private key can never
# be staged or committed by an ordinary `git add`/`git commit` from
# inside this repo, git will treat the whole folder as ignored.
# WHY this matters: SSH private keys are bearer secrets, anyone who
# gets a copy can impersonate you to GitHub/servers with no further
# password needed. Committing one to a public repo, even briefly, means
# treating it as compromised and rotating it. The .gitignore rule is the
# only thing standing between "backup folder on disk" and "secret key
# permanently in public git history," so it must never be loosened.
# This function does not change or weaken that mechanism in any way.
backup_ssh_keys() {
    # This checks if the .ssh folder actually exists on your computer.
    # The -d flag means "does this directory exist?". If you've never set
    # up SSH keys, this folder won't exist, and we don't want the script
    # to crash trying to copy something that isn't there.
    if [ -d "$HOME/.ssh" ]; then
        echo "🔑 Copying SSH keys..."

        # Copies the entire .ssh folder's contents into the backup. The -R
        # flag means "recursive", copy the folder AND all its contents.
        # The trailing "/." on the source and pre-made destination folder
        # matter: "cp -R sourceDir destDir" only behaves the same as a
        # merge on a first run, if destDir already exists (e.g. a second
        # run today), cp nests sourceDir inside it instead of copying into
        # it. Copying "sourceDir/." into an already-created destDir avoids
        # that regardless of how many times this runs against the same
        # dated folder. This is a critical backup because losing SSH keys
        # means losing secure access to your GitHub account, servers, etc.
        mkdir -p "$BACKUP_DIR/dotfiles/ssh_backup"
        cp -R "$HOME/.ssh/." "$BACKUP_DIR/dotfiles/ssh_backup/"
    fi
}

# =====================================================================
# SECTION 10: BACKUP OTHER SECRETS (GPG, cloud CLI configs, registry tokens)
# =====================================================================
# SSH keys aren't the only bearer secrets a developer's home folder
# holds. GPG keys (commit signing), cloud CLI credentials, and package
# registry auth tokens are just as sensitive and just as easy to forget
# when only thinking about "apps and dotfiles." These all land in the
# same "dotfiles" subfolder as the SSH backup above, so they're covered
# by the exact same "Mac_Backup_*/" .gitignore protection described in
# the SSH KEY SAFETY note above.

# WHAT: Copies GPG keys, AWS/gcloud/kube credentials, and npm/yarn
# registry configs, only for whichever of these actually exist.
# HOW: Each block checks for its folder/file with -d or -f before
# copying, so a tool that was never installed (e.g. no AWS CLI) is
# silently skipped instead of throwing an error. Each destination folder
# is pre-made and copied into with the "source/." form, same reasoning
# as backup_ssh_keys above: it keeps a rerun against today's folder from
# nesting a fresh copy inside the previous one instead of overwriting it.
# WHY: Losing a GPG key means commits stop verifying as signed; losing
# cloud credentials means re-authenticating every CLI from scratch;
# losing registry tokens means re-logging into private npm/yarn feeds.
backup_secrets() {
    echo "🔐 Copying GPG keys and cloud/registry credentials..."
    mkdir -p "$BACKUP_DIR/dotfiles"

    if [ -d "$HOME/.gnupg" ]; then
        mkdir -p "$BACKUP_DIR/dotfiles/gnupg_backup"
        cp -R "$HOME/.gnupg/." "$BACKUP_DIR/dotfiles/gnupg_backup/"
    fi
    if [ -d "$HOME/.aws" ]; then
        mkdir -p "$BACKUP_DIR/dotfiles/aws_backup"
        cp -R "$HOME/.aws/." "$BACKUP_DIR/dotfiles/aws_backup/"
    fi
    if [ -d "$HOME/.config/gcloud" ]; then
        mkdir -p "$BACKUP_DIR/dotfiles/gcloud_backup"
        cp -R "$HOME/.config/gcloud/." "$BACKUP_DIR/dotfiles/gcloud_backup/"
    fi
    if [ -f "$HOME/.kube/config" ]; then
        mkdir -p "$BACKUP_DIR/dotfiles/kube_backup"
        cp "$HOME/.kube/config" "$BACKUP_DIR/dotfiles/kube_backup/config"
    fi
    cp "$HOME/.npmrc" "$BACKUP_DIR/dotfiles/npmrc.bak" 2>/dev/null
    cp "$HOME/.yarnrc" "$BACKUP_DIR/dotfiles/yarnrc.bak" 2>/dev/null
}

# =====================================================================
# SECTION 11: PRUNE OLD BACKUPS
# =====================================================================
# Every run creates a new dated "Mac_Backup_<date>" folder and never
# touches previous ones. That's fine for occasional manual runs, but a
# weekly scheduled run (see schedule/) would otherwise build up an
# unbounded pile of backup folders, and SSH-key copies, in $HOME forever.

# WHAT: Deletes older Mac_Backup_* folders beyond the most recent
# BACKUP_RETENTION_COUNT.
# HOW: "ls -1d" lists matching folders one per line as full paths; "sort"
# puts them in order since the date-stamped names sort chronologically as
# plain text. macOS ships BSD head, which (unlike GNU head) has no
# "-n -N" ("all but the last N lines") form, so the count of folders to
# delete is computed by hand instead: total folders minus how many to
# keep. If that comes out to zero or less (BACKUP_RETENTION_COUNT or
# fewer folders exist), nothing runs and no deletion happens.
# WHY: Keeping a handful of recent backups gives a short rollback window
# without letting unattended runs quietly consume disk space, or leave
# an ever-growing number of directories containing copies of SSH keys,
# forever.
BACKUP_RETENTION_COUNT=4

prune_old_backups() {
    echo "🧹 Pruning old backups (keeping the $BACKUP_RETENTION_COUNT most recent)..."

    local backups
    backups=$(ls -1d "$HOME"/Mac_Backup_*/ 2>/dev/null | sort)
    local total
    total=$(echo "$backups" | grep -c .)
    local delete_count=$((total - BACKUP_RETENTION_COUNT))

    if [ "$delete_count" -gt 0 ]; then
        echo "$backups" | head -n "$delete_count" | while read -r old_backup; do
            rm -rf "$old_backup"
        done
    fi
}

# =====================================================================
# DONE, TELL THE USER WHAT TO DO NEXT
# =====================================================================

# WHAT: Prints the final success message and next-step reminder.
# WHY: The backup folder now contains real secrets (SSH private keys and,
# on machines that have them, GPG keys and cloud CLI credentials). It's
# already git-ignored, but it still needs to end up somewhere private
# (not emailed, not uploaded to a public share) so the user gets an
# explicit reminder to move it to private storage.
print_backup_complete() {
    echo "✅ Backup complete! You can now move the folder '$BACKUP_DIR' to your private cloud storage."
    echo "   Reminder: this backup contains SSH keys and, if present on this machine, GPG/AWS/gcloud/kube credentials, keep it private."
}

# =====================================================================
# MAIN, RUN EVERY BACKUP STEP IN ORDER
# =====================================================================
# WHAT: Calls each single-purpose function above in order.
# WHY: Keeping the sequence explicit and in one place makes it obvious
# at a glance what a full backup run does, without re-reading every
# function body.
main() {
    setup_backup_dir
    backup_homebrew_packages
    backup_language_packages
    backup_language_versions
    backup_dotfiles
    backup_vscode_config
    backup_app_inventory
    backup_scheduled_tasks
    backup_ssh_keys
    backup_secrets
    prune_old_backups
    print_backup_complete
}

main
