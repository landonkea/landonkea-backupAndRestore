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
# Every line below targets a specific category of things to back up.

# =====================================================================
# SECTION 1: SET UP THE BACKUP FOLDER
# =====================================================================

# This creates a variable called BACKUP_DIR. A variable is like a labeled
# box where you store a value. Here, the value is a full file path like
# "/Users/yourname/Mac_Backup_2026-07-26". The $(date +%Y-%m-%d) part
# runs a date command that outputs today's date in year-month-day format,
# so each backup gets its own uniquely dated folder and never overwrites
# a previous backup.
BACKUP_DIR="$HOME/Mac_Backup_$(date +%Y-%m-%d)"

# This creates the backup folder on your computer. The -p flag means
# "make parent directories if they don't exist" — so if your home folder
# doesn't exist yet (it always does), it would create it. It also means
# this command won't complain if the folder already exists.
mkdir -p "$BACKUP_DIR"

# This prints a friendly message to the terminal so the user knows the
# backup process has started and where the files will be saved. The
# emoji is just decoration to make the output easier to read at a glance.
echo "🏁 Starting system backup into: $BACKUP_DIR"

# =====================================================================
# SECTION 2: BACKUP HOMEBREW PACKAGES (apps installed via the terminal)
# =====================================================================

# Homebrew is a free package manager for macOS — it lets you install
# developer tools and apps from the terminal instead of downloading them
# from a website. This section saves a list of everything you've installed
# through Homebrew so it can all be reinstalled later with one command.

# Prints a status message so the user knows what's happening right now.
echo "📦 Backing up Homebrew packages..."

# Changes the current working directory to the backup folder. All
# commands that follow will run inside that folder. The "|| exit" part
# means: if changing directory fails (for example, the folder doesn't
# exist), stop the entire script immediately. This prevents the script
# from accidentally saving files in the wrong location.
cd "$BACKUP_DIR" || exit

# This tells Homebrew to write a file called "Brewfile" that lists every
# app and tool you have installed. The --describe flag adds helpful
# comments next to each app name. The --force flag means "overwrite the
# file if it already exists" without asking for confirmation.
brew bundle dump --describe --force

# =====================================================================
# SECTION 3: BACKUP CODING LANGUAGE PACKAGES
# =====================================================================
# Many developers use coding languages like JavaScript (via NPM),
# Python (via PIP), or Ruby (via GEM). Each language has its own system
# for installing extra libraries. This section saves a list of every
# extra library you've installed for each language.

# Prints a status message.
echo "🌐 Backing up language packages..."

# This saves a list of all globally-installed Node.js packages (JavaScript
# libraries available everywhere on your computer, not just one project).
# "-g" means global, "--depth=0" means only top-level packages (not the
# hundreds of tiny helper packages they depend on). The ">" redirects the
# output into a file called "global-npm-packages.txt". The "2>/dev/null"
# hides any error messages so the script doesn't crash if Node.js isn't
# installed. The "|| echo ..." part prints a friendly message if NPM
# isn't found, instead of showing a scary error.
npm list -g --depth=0 > global-npm-packages.txt 2>/dev/null || echo "Node/NPM not found, skipping."

# This saves a list of all Python packages you've installed. "--format=freeze"
# outputs them in a clean "package==version" format that PIP can read later.
# The rest works the same as the NPM line above — redirect to file, hide
# errors, and show a friendly message if Python/PIP isn't installed.
pip list --format=freeze > requirements.txt 2>/dev/null || echo "Python/PIP not found, skipping."

# This saves a list of all Ruby gems (Ruby's version of packages/libraries).
# "gem list" shows every installed gem. Same error-handling pattern as above.
gem list > rubygems.txt 2>/dev/null || echo "Ruby/Gems not found, skipping."

# =====================================================================
# SECTION 4: BACKUP DOTFILES (hidden configuration files)
# =====================================================================
# Dotfiles are hidden configuration files in your home folder. They start
# with a dot (.) which makes them invisible in Finder by default. They
# control things like how your terminal looks, what Git knows about you,
# and what shell shortcuts you've set up. Losing these on a new Mac means
# hours of re-configuring — so we back them up.

# Prints a status message.
echo "🔒 Copying configuration files..."

# Creates a folder called "dotfiles" inside the backup directory to keep
# all the configuration files organized in one place.
mkdir -p "$BACKUP_DIR/dotfiles"

# Copies your Zsh configuration file (.zshrc) into the backup folder.
# Zsh is the default terminal shell on modern macOS. This file stores
# things like command aliases (shortcuts), PATH settings (where the
# system looks for programs), and custom prompts. The "2>/dev/null"
# hides errors if the file doesn't exist (some users may not have one).
cp "$HOME/.zshrc" "$BACKUP_DIR/dotfiles/zshrc.bak" 2>/dev/null

# Copies your Bash profile into the backup. Bash is an older terminal
# shell that some people still use. The .bash_profile runs every time
# you open a Bash terminal and can set up environment variables and
# shortcuts. Same error-hiding pattern as above.
cp "$HOME/.bash_profile" "$BACKUP_DIR/dotfiles/bash_profile.bak" 2>/dev/null

# Copies your Git configuration file. This file tells Git your name,
# email, preferred editor, and other personal settings. Losing this
# means Git wouldn't know who you are when you commit code. Same
# error-hiding pattern.
cp "$HOME/.gitconfig" "$BACKUP_DIR/dotfiles/gitconfig.bak" 2>/dev/null

# =====================================================================
# SECTION 5: BACKUP SSH KEYS (SECRET authentication keys)
# =====================================================================
# SSH keys are special secret files that let your computer prove its
# identity to servers like GitHub, university servers, or work servers.
# Without them, you'd have to type a password every single time you
# connect. They live in a hidden folder called .ssh in your home
# directory.

# This checks if the .ssh folder actually exists on your computer.
# The -d flag means "does this directory exist?". If you've never set
# up SSH keys, this folder won't exist, and we don't want the script
# to crash trying to copy something that isn't there.
if [ -d "$HOME/.ssh" ]; then

    # Prints a status message telling the user SSH keys are being copied.
    echo "🔑 Copying SSH keys..."

    # Copies the entire .ssh folder (and everything inside it) into the
    # backup. The -R flag means "recursive" — copy the folder AND all
    # its contents. This is a critical backup because losing SSH keys
    # means losing secure access to your GitHub account, servers, etc.
    cp -R "$HOME/.ssh" "$BACKUP_DIR/dotfiles/ssh_backup"
fi

# =====================================================================
# DONE — TELL THE USER WHAT TO DO NEXT
# =====================================================================

# Prints a final success message. It tells the user the backup is done
# and reminds them to move the backup folder to private cloud storage
# (like iCloud, Google Drive, or a USB drive) so they can use it on
# their new Mac. The word "private" is important because the backup
# contains SSH keys — secret files that should never be shared publicly.
echo "✅ Backup complete! You can now move the folder '$BACKUP_DIR' to your private cloud storage."
