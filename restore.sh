#!/bin/bash
# This line tells the system to use the Bash shell to run this script.
# The #! at the start is called a "shebang" — it's a special marker that
# tells the operating system which program should interpret the commands
# below. Without it, the system might try to run the script with the
# wrong interpreter and fail. Bash is macOS's default command-line shell.

# --- PROJECT CONTEXT ---
# This file is the RESTORE half of a macOS developer backup/restore toolkit.
# Its job is to take a backup folder created by backup.sh and use it to
# reinstall all the apps, coding libraries, and configuration files on a
# fresh Mac. You would run this script from inside the backup folder on
# your new computer — every relative path below (Brewfile,
# global-npm-packages.txt, dotfiles/...) is read relative to the current
# working directory for that reason.
#
# --- STRUCTURE ---
# WHAT: Like backup.sh, this script is organized as small, single-purpose
# functions plus a main() at the bottom that runs them in order.
# WHY: Each restore step (Homebrew, language packages, dotfiles/SSH) is
# independent and can fail or be skipped on its own (e.g. no Brewfile
# found) — separating them into functions makes each step's success
# path and fallback path easy to follow on its own.
# HOW: Originally a structural reorganization only; since then the
# Homebrew install URL was fixed (it pointed at a broken host) and Ruby
# gem restoration was added so gems round-trip like npm/pip packages.

# =====================================================================
# SECTION 1: INSTALL HOMEBREW IF IT IS MISSING
# =====================================================================
# Homebrew is a free package manager for macOS. It lets you install
# developer tools and desktop apps from the terminal instead of hunting
# for download links on websites. The restore process needs Homebrew
# first because everything else (apps, casks) depends on it.

# WHAT: Installs Homebrew if it isn't already present, then makes sure
# it's on the PATH for Apple Silicon Macs.
# HOW: "command -v brew" looks up whether a program called "brew"
# exists; "&> /dev/null" hides all output (both regular output and
# errors) so the terminal stays clean. The "!" means "if NOT" — so the
# install block only runs when Homebrew is missing. The installer is
# fetched with curl ("-f" fail silently on HTTP errors, "-s" silent/no
# progress bar, "-S" still show errors even in silent mode, "-L" follow
# redirects) and piped into "/bin/bash -c" to run it. "uname -m" reports
# the CPU architecture; Apple Silicon Macs (M1/M2/M3, arm64) install
# Homebrew to /opt/homebrew instead of Intel's /usr/local, so on arm64
# we additionally need "eval "$(brew shellenv)"" to add that location to
# the PATH so later "brew" commands in this script can find it.
# WHY: Every later Homebrew step in this script depends on the "brew"
# command being callable, so this must run first.
install_homebrew_if_missing() {
    if ! command -v brew &> /dev/null; then
        echo "🍺 Homebrew not found. Installing Homebrew..."

        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        if [[ "$(uname -m)" == "arm64" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
    else
        echo "🍺 Homebrew is already installed."
    fi
}

# =====================================================================
# SECTION 2: RESTORE HOMEBREW APPS AND CASKS
# =====================================================================
# A "Brewfile" is a text file that lists every app and tool that was
# backed up by backup.sh. "Brew bundle" reads this file and installs
# everything in it — both command-line tools and GUI apps (called "casks").

# WHAT: Reinstalls every Homebrew app/tool listed in the backed-up Brewfile.
# HOW: "-f" checks whether a regular file called "Brewfile" exists in the
# current directory — you must run this script from inside the backup
# folder for it to be found. If present, "brew bundle" reads it and
# installs everything listed. If absent, we warn instead of failing
# silently, since a missing Brewfile usually means the script was run
# from the wrong folder.
# WHY: This is the step that turns a fresh Mac into a fully-loaded dev
# machine with a single command, using exactly what backup.sh recorded.
restore_homebrew_packages() {
    if [ -f "Brewfile" ]; then
        echo "📦 Restoring Homebrew packages and desktop apps..."
        brew bundle
    else
        echo "⚠️ Brewfile not found in current directory!"
    fi
}

# =====================================================================
# SECTION 3: RESTORE CODING LANGUAGE PACKAGES
# =====================================================================
# This section reinstalls the extra libraries for JavaScript (NPM),
# Python (PIP), and Ruby (GEM) that were saved during backup. Each
# language's packages are only installed if both the list file AND the
# language's package manager exist on the system.

# WHAT: Reinstalls globally-installed NPM and Python packages from the
# lists backup.sh saved.
# HOW: Each "if" does two checks joined with "&&" (both must be true):
# does the backed-up list file exist, AND is the package manager
# installed? If either is false, that block is skipped silently — no
# errors, no noise. "xargs npm install -g < file" reads package names
# one per line from the file and passes them as arguments to
# "npm install -g" (global install). "pip install -r requirements.txt"
# reads the "package==version" lines pip wrote during backup and
# reinstalls those exact versions. Ruby gems are handled a little
# differently: backup.sh saves "gem list" output, and each line of that
# looks like "gemname (1.2.3, 1.1.0)" rather than a plain name — so we
# use "awk '{print $1}'" to grab just the first field (the gem name) off
# each line before handing the names to "xargs gem install". This
# installs the latest available version of each gem rather than pinning
# the exact backed-up version, since "gem list"'s default output isn't a
# pip-style pinned-version format.
# WHY: Restoring the same globally-installed libraries (and, for
# Python, the exact same versions) avoids compatibility surprises on
# the new machine. Ruby gems are restored too, by name, so they round
# trip like the other two languages instead of only being listed for
# reference.
restore_language_packages() {
    echo "🌐 Restoring language packages..."

    if [ -f "global-npm-packages.txt" ] && command -v npm &> /dev/null; then
        echo "Installing global NPM packages..."
        xargs npm install -g < global-npm-packages.txt
    fi

    if [ -f "requirements.txt" ] && command -v pip &> /dev/null; then
        echo "Installing Python packages..."
        pip install -r requirements.txt
    fi

    if [ -f "rubygems.txt" ] && command -v gem &> /dev/null; then
        echo "Installing Ruby gems..."
        awk '{print $1}' rubygems.txt | xargs gem install
    fi
}

# =====================================================================
# SECTION 4: RESTORE DOTFILES
# =====================================================================
# Dotfiles are hidden configuration files (they start with a dot) that
# control how your terminal and Git behave. Restoring these saves hours
# of manual re-configuration.

# WHAT: Copies .zshrc, .bash_profile, and .gitconfig back from the
# backup into $HOME.
# HOW: Each line uses the pattern "[ condition ] && action" — "if the
# condition is true, then do the action." Specifically: does
# "dotfiles/<name>.bak" exist in the backup? If yes, copy it back to
# "$HOME/<name>". This is safer than always copying because the backup
# might not include every dotfile (the user may not have had one on the
# old machine), and doing nothing in that case causes no error.
# WHY: These files carry personal shell/Git configuration that's
# tedious to recreate by hand.
restore_dotfiles() {
    echo "🔒 Restoring configuration files..."

    [ -f "dotfiles/zshrc.bak" ] && cp "dotfiles/zshrc.bak" "$HOME/.zshrc"
    [ -f "dotfiles/bash_profile.bak" ] && cp "dotfiles/bash_profile.bak" "$HOME/.bash_profile"
    [ -f "dotfiles/gitconfig.bak" ] && cp "dotfiles/gitconfig.bak" "$HOME/.gitconfig"
}

# =====================================================================
# SECTION 5: RESTORE SSH KEYS (SECRET authentication keys)
# =====================================================================
# SSH keys are secret files that let your computer prove its identity to
# servers like GitHub. Restoring them means you don't have to regenerate
# and re-register new keys on every server you use.
#
# --- SSH KEY SAFETY (read this before touching this function) ---
# WHAT this function does: if backup.sh saved a copy of the old ~/.ssh
# folder into "dotfiles/ssh_backup", this copies those files into the
# new machine's ~/.ssh and then immediately locks down permissions.
# HOW the safety check works: "-d dotfiles/ssh_backup" only proceeds if
# that folder exists, so a backup without SSH keys can't cause an error
# copying nothing. After copying, "chmod 700 ~/.ssh" restricts the
# folder to owner-only access (rwx for you, nothing for anyone else —
# 4+2+1=7), and "chmod 600 ~/.ssh/*" restricts every individual key file
# to owner read/write only (4+2=6, nothing for group or everyone). SSH
# actively refuses to use keys that are readable by other users, so
# these permission fixes are required, not optional hardening.
# WHY this matters: this is the point where a real private key is
# written to disk on the new machine, outside of any git-tracked
# location. It's not a git-safety step (that's handled by .gitignore in
# the backup step) — it's an OS-permission-safety step, making sure the
# restored key is only ever readable by the machine's owner. Note this
# will silently overwrite an existing ~/.ssh with the same filenames if
# one already exists on the target machine — that mirrors the original
# script's behavior and was intentionally left unchanged here.
restore_ssh_keys() {
    # Creates the .ssh folder in your home directory if it doesn't already
    # exist. The -p flag means "make parent folders if needed" and "don't
    # complain if it already exists". SSH keys MUST live in ~/.ssh — if this
    # folder doesn't exist, SSH won't work at all.
    mkdir -p "$HOME/.ssh"

    # This checks if the backed-up SSH folder exists. If the backup included
    # SSH keys, they'll be in a folder called "ssh_backup" inside "dotfiles".
    # The -d flag checks for the existence of a directory (folder).
    if [ -d "dotfiles/ssh_backup" ]; then
        echo "🔑 Restoring SSH keys..."

        cp -R dotfiles/ssh_backup/* "$HOME/.ssh/"
        chmod 700 "$HOME/.ssh"
        chmod 600 "$HOME/.ssh/"*
    fi
}

# =====================================================================
# DONE — TELL THE USER THE RESTORE IS FINISHED
# =====================================================================

# WHAT: Prints the final success message and next-step reminder.
# WHY: The terminal loads configuration files (.zshrc, .bash_profile)
# only at startup — without restarting, the old (empty/default)
# configuration stays in effect and none of the restored settings take
# hold, so the user is explicitly told to restart.
print_restore_complete() {
    echo "✅ System restore complete! Please restart your terminal."
}

# =====================================================================
# MAIN — RUN EVERY RESTORE STEP IN ORDER
# =====================================================================
# WHAT: Calls each single-purpose function above in the same order the
# original script ran its steps, so the final behavior is identical.
# WHY: Keeping the sequence explicit and in one place makes it obvious
# at a glance what a full restore run does, without re-reading every
# function body.
main() {
    echo "🏁 Starting system restore..."

    install_homebrew_if_missing
    restore_homebrew_packages
    restore_language_packages
    restore_dotfiles
    restore_ssh_keys
    print_restore_complete
}

main
