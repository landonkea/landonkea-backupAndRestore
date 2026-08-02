#!/bin/bash
# This line tells the system to use the Bash shell to run this script.
# Bash is the default command-line program on macOS that reads and executes
# shell scripts like this one. Without this line, the system wouldn't know
# how to interpret the commands below. The #! at the start is called a
# "shebang" — it's a special marker for the operating system.

# --- PROJECT CONTEXT ---
# This file is the BACKUP half of a macOS developer backup/restore toolkit.
# Its job is to collect all the things a developer has installed and configured
# on their Mac — apps, coding language packages, and secret SSH keys — and
# save them into one folder so they can be restored on a new Mac later.
#
# --- STRUCTURE ---
# WHAT: The script is organized as a series of small, single-purpose
# functions (one per backup category), plus a main() function at the
# bottom that calls them in order.
# WHY: Splitting the work into named functions makes each step easy to
# read, test, and reason about in isolation — e.g. you can tell exactly
# what "backup_ssh_keys" does without scrolling through unrelated code
# for Homebrew or npm. It also means adding or removing a backup step
# later is a one-line change in main(), not a rewrite of a giant block.
# HOW: Every function below does exactly one job and is named after that
# job. None of the actual commands, flags, or file paths were changed —
# this is a structural reorganization only, not a behavior change.

# =====================================================================
# SECTION 1: SET UP THE BACKUP FOLDER
# =====================================================================

# WHAT: Builds the backup folder path and creates it.
# HOW: BACKUP_DIR is a variable — a labeled box where we store a value,
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
# WHY: Homebrew is a free package manager for macOS — it lets you install
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
# SECTION 4: BACKUP DOTFILES (hidden configuration files)
# =====================================================================
# Dotfiles are hidden configuration files in your home folder. They start
# with a dot (.) which makes them invisible in Finder by default. They
# control things like how your terminal looks, what Git knows about you,
# and what shell shortcuts you've set up. Losing these on a new Mac means
# hours of re-configuring — so we back them up.

# WHAT: Copies .zshrc, .bash_profile, and .gitconfig into dotfiles/.
# HOW: Creates a "dotfiles" subfolder inside BACKUP_DIR to keep these
# files organized in one place, then copies each config file from $HOME
# with a ".bak" suffix. Each copy's "2>/dev/null" hides the error if that
# particular file doesn't exist on this machine (e.g. a user with no
# .bash_profile) — this is expected and not a failure.
# WHY: These files carry personal shell/editor/Git configuration that is
# tedious to recreate by hand — restoring them saves hours of setup.
backup_dotfiles() {
    echo "🔒 Copying configuration files..."
    mkdir -p "$BACKUP_DIR/dotfiles"

    cp "$HOME/.zshrc" "$BACKUP_DIR/dotfiles/zshrc.bak" 2>/dev/null
    cp "$HOME/.bash_profile" "$BACKUP_DIR/dotfiles/bash_profile.bak" 2>/dev/null
    cp "$HOME/.gitconfig" "$BACKUP_DIR/dotfiles/gitconfig.bak" 2>/dev/null
}

# =====================================================================
# SECTION 5: BACKUP SSH KEYS (SECRET authentication keys)
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
# NOT itself protected by anything in this script — the protection lives
# one layer up, in this repo's .gitignore, which excludes every folder
# matching "Mac_Backup_*/" (and "*.bak" files) from version control.
# HOW it holds together: as long as (a) this script keeps writing backups
# under the "$HOME/Mac_Backup_<date>" naming pattern, and (b) .gitignore
# keeps the "Mac_Backup_*/" pattern intact, a real private key can never
# be staged or committed by an ordinary `git add`/`git commit` from
# inside this repo — git will treat the whole folder as ignored.
# WHY this matters: SSH private keys are bearer secrets — anyone who
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

        # Copies the entire .ssh folder (and everything inside it) into the
        # backup. The -R flag means "recursive" — copy the folder AND all
        # its contents. This is a critical backup because losing SSH keys
        # means losing secure access to your GitHub account, servers, etc.
        cp -R "$HOME/.ssh" "$BACKUP_DIR/dotfiles/ssh_backup"
    fi
}

# =====================================================================
# DONE — TELL THE USER WHAT TO DO NEXT
# =====================================================================

# WHAT: Prints the final success message and next-step reminder.
# WHY: The backup folder now contains a real SSH private key. It's
# already git-ignored, but it still needs to end up somewhere private
# (not emailed, not uploaded to a public share) so the user gets an
# explicit reminder to move it to private storage.
print_backup_complete() {
    echo "✅ Backup complete! You can now move the folder '$BACKUP_DIR' to your private cloud storage."
}

# =====================================================================
# MAIN — RUN EVERY BACKUP STEP IN ORDER
# =====================================================================
# WHAT: Calls each single-purpose function above in the same order the
# original script ran its steps, so the final behavior is identical.
# WHY: Keeping the sequence explicit and in one place makes it obvious
# at a glance what a full backup run does, without re-reading every
# function body.
main() {
    setup_backup_dir
    backup_homebrew_packages
    backup_language_packages
    backup_dotfiles
    backup_ssh_keys
    print_backup_complete
}

main
