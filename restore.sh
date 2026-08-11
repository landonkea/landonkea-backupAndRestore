#!/bin/bash
# This line tells the system to use the Bash shell to run this script.
# The #! at the start is called a "shebang", it's a special marker that
# tells the operating system which program should interpret the commands
# below. Without it, the system might try to run the script with the
# wrong interpreter and fail. Bash is macOS's default command-line shell.

# --- PROJECT CONTEXT ---
# This file is the RESTORE half of a macOS developer backup/restore toolkit.
# Its job is to take a backup folder created by backup.sh and use it to
# reinstall all the apps, coding libraries, and configuration files on a
# fresh Mac. You would run this script from inside the backup folder on
# your new computer, every relative path below (Brewfile,
# global-npm-packages.txt, dotfiles/...) is read relative to the current
# working directory for that reason.
#
# --- STRUCTURE ---
# WHAT: Like backup.sh, this script is organized as small, single-purpose
# functions plus a main() at the bottom that runs them in order.
# WHY: Each restore step (Homebrew, language packages, dotfiles/SSH) is
# independent and can fail or be skipped on its own (e.g. no Brewfile
# found), separating them into functions makes each step's success
# path and fallback path easy to follow on its own.
# HOW: Originally a structural reorganization only; since then the
# Homebrew install URL was fixed (it pointed at a broken host), Ruby gem
# restoration was added so gems round-trip like npm/pip packages, and
# restore steps were added to match backup.sh's wider coverage: language
# version managers, VS Code, installed-app inventory, scheduled tasks,
# and non-SSH secrets (GPG, cloud CLIs, registry tokens).

# =====================================================================
# SECTION 1: INSTALL HOMEBREW IF IT IS MISSING
# =====================================================================
# Homebrew is a free package manager for macOS. It lets you install
# developer tools and apps from the terminal instead of hunting
# for download links on websites. The restore process needs Homebrew
# first because everything else (apps, casks) depends on it.

# WHAT: Installs Homebrew if it isn't already present, then makes sure
# it's on the PATH for Apple Silicon Macs.
# HOW: "command -v brew" looks up whether a program called "brew"
# exists; "&> /dev/null" hides all output (both regular output and
# errors) so the terminal stays clean. The "!" means "if NOT", so the
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
# everything in it, both command-line tools and GUI apps (called "casks").

# WHAT: Reinstalls every Homebrew app/tool listed in the backed-up Brewfile.
# HOW: "-f" checks whether a regular file called "Brewfile" exists in the
# current directory, you must run this script from inside the backup
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
# installed? If either is false, that block is skipped silently, no
# errors, no noise. "xargs npm install -g < file" reads package names
# one per line from the file and passes them as arguments to
# "npm install -g" (global install). "pip install -r requirements.txt"
# reads the "package==version" lines pip wrote during backup and
# reinstalls those exact versions. Ruby gems are handled a little
# differently: backup.sh saves "gem list" output, and each line of that
# looks like "gemname (1.2.3, 1.1.0)" rather than a plain name, so we
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
# SECTION 4: RESTORE LANGUAGE VERSION MANAGER VERSIONS
# =====================================================================
# WHAT: Reinstalls Node/Python/Ruby versions recorded by nvm, pyenv, or rbenv.
# HOW: Each block only runs if the manager itself is already installed
# on this new machine, this script installs the language *versions* those
# tools manage, not the tools themselves. Version numbers are pulled out
# of each saved listing with grep, since the default output of "nvm ls",
# "pyenv versions", and "rbenv versions" includes extra decoration
# (arrows, asterisks, "system", header lines) around the plain version
# number that would otherwise get passed straight to "install" and fail.
# WHY: A package that depends on "Node 18" or "Ruby 3.1" specifically
# will misbehave under whatever version Homebrew happens to default to.
restore_language_versions() {
    echo "🧬 Restoring language version manager versions..."

    if [ -f "nvm-versions.txt" ] && [ -s "$HOME/.nvm/nvm.sh" ]; then
        source "$HOME/.nvm/nvm.sh"
        grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' nvm-versions.txt | sort -u | while read -r version; do
            nvm install "$version"
        done
    fi

    if [ -f "pyenv-versions.txt" ] && command -v pyenv &> /dev/null; then
        grep -oE '[0-9]+\.[0-9]+\.[0-9]+' pyenv-versions.txt | sort -u | while read -r version; do
            pyenv install -s "$version"
        done
    fi

    if [ -f "rbenv-versions.txt" ] && command -v rbenv &> /dev/null; then
        grep -oE '[0-9]+\.[0-9]+\.[0-9]+' rbenv-versions.txt | sort -u | while read -r version; do
            rbenv install -s "$version"
        done
    fi
}

# =====================================================================
# SECTION 5: RESTORE DOTFILES
# =====================================================================
# Dotfiles are hidden configuration files (they start with a dot) that
# control how your terminal, editor, and Git behave. Restoring these
# saves hours of manual re-configuration.

# WHAT: Copies shell, Git, editor, and prompt config files back from the
# backup into $HOME.
# HOW: Each line uses the pattern "[ condition ] && action", "if the
# condition is true, then do the action." Specifically: does
# "dotfiles/<name>.bak" exist in the backup? If yes, copy it back to its
# real location. This is safer than always copying because the backup
# might not include every dotfile (the old machine may not have had one),
# and doing nothing in that case causes no error.
# WHY: These files carry personal shell/editor/Git configuration that's
# tedious to recreate by hand.
restore_dotfiles() {
    echo "🔒 Restoring configuration files..."

    [ -f "dotfiles/zshrc.bak" ] && cp "dotfiles/zshrc.bak" "$HOME/.zshrc"
    [ -f "dotfiles/zprofile.bak" ] && cp "dotfiles/zprofile.bak" "$HOME/.zprofile"
    [ -f "dotfiles/zshenv.bak" ] && cp "dotfiles/zshenv.bak" "$HOME/.zshenv"
    [ -f "dotfiles/bash_profile.bak" ] && cp "dotfiles/bash_profile.bak" "$HOME/.bash_profile"
    [ -f "dotfiles/gitconfig.bak" ] && cp "dotfiles/gitconfig.bak" "$HOME/.gitconfig"
    [ -f "dotfiles/gitignore_global.bak" ] && cp "dotfiles/gitignore_global.bak" "$HOME/.gitignore_global"
    [ -f "dotfiles/vimrc.bak" ] && cp "dotfiles/vimrc.bak" "$HOME/.vimrc"
    [ -f "dotfiles/tmux_conf.bak" ] && cp "dotfiles/tmux_conf.bak" "$HOME/.tmux.conf"
    [ -f "dotfiles/inputrc.bak" ] && cp "dotfiles/inputrc.bak" "$HOME/.inputrc"
    [ -f "dotfiles/p10k_zsh.bak" ] && cp "dotfiles/p10k_zsh.bak" "$HOME/.p10k.zsh"
    if [ -f "dotfiles/starship_toml.bak" ]; then
        mkdir -p "$HOME/.config"
        cp "dotfiles/starship_toml.bak" "$HOME/.config/starship.toml"
    fi
}

# =====================================================================
# SECTION 6: RESTORE EDITOR CONFIG (VS Code)
# =====================================================================
# WHAT: Reinstalls VS Code extensions and restores settings/keybindings.
# HOW: "xargs -L1 code --install-extension" installs one extension ID
# per line from the saved list; "-L1" runs the command once per line
# rather than batching every ID into a single call, so one bad or
# renamed extension ID fails on its own line instead of aborting the
# whole batch.
# WHY: Reinstalling extensions by hand from memory means missing several.
restore_vscode_config() {
    if [ -f "dotfiles/vscode/extensions.txt" ] && command -v code &> /dev/null; then
        echo "🧩 Restoring VS Code extensions and settings..."

        xargs -L1 code --install-extension < "dotfiles/vscode/extensions.txt"

        mkdir -p "$HOME/Library/Application Support/Code/User"
        [ -f "dotfiles/vscode/settings.json" ] && cp "dotfiles/vscode/settings.json" "$HOME/Library/Application Support/Code/User/settings.json"
        [ -f "dotfiles/vscode/keybindings.json" ] && cp "dotfiles/vscode/keybindings.json" "$HOME/Library/Application Support/Code/User/keybindings.json"
    fi
}

# =====================================================================
# SECTION 7: RESTORE APP INVENTORY (Mac App Store apps)
# =====================================================================
# WHAT: Reinstalls Mac App Store apps by ID; prints the manually-installed
# app list as a reminder rather than trying to auto-install those.
# HOW: "mas-apps.txt" lines look like "409183694 Keynote (12.2)", the
# leading number is the App Store ID mas needs, so awk grabs just that
# first field before handing IDs to "xargs -n1 mas install". There's no
# equivalent command for apps installed from a downloaded .dmg, so
# "applications-list.txt" is only printed for review by hand.
# WHY: mas apps can be reinstalled unattended given the IDs; manually
# installed apps can't be, so the best this script can do is surface the
# list instead of silently dropping it.
restore_app_inventory() {
    if [ -f "mas-apps.txt" ] && command -v mas &> /dev/null; then
        echo "🗂️  Restoring Mac App Store apps..."
        awk '{print $1}' mas-apps.txt | xargs -n1 mas install
    fi

    if [ -f "applications-list.txt" ]; then
        echo "🗂️  These apps were manually installed (not via Homebrew or the App Store) on the old machine, review and reinstall as needed:"
        cat applications-list.txt
    fi
}

# =====================================================================
# SECTION 8: RESTORE SCHEDULED TASKS (cron jobs and LaunchAgents)
# =====================================================================
# WHAT: Restores the crontab and copies LaunchAgents back into place.
# HOW: "crontab crontab.txt" replaces the current user's entire crontab
# with the backed-up one. LaunchAgents are copied back but deliberately
# NOT loaded with launchctl automatically, a restored agent might
# reference an app or path that doesn't exist yet on the new machine, so
# loading them is left as a manual step after review.
# WHY: Cron jobs and LaunchAgents run silently in the background, if
# restore skipped them, the only sign of a problem would be whatever
# they automated quietly not happening anymore.
restore_scheduled_tasks() {
    [ -f "crontab.txt" ] && echo "⏰ Restoring crontab..." && crontab crontab.txt

    if [ -d "LaunchAgents" ]; then
        echo "⏰ Restoring LaunchAgents (not auto-loaded, run 'launchctl load' on each after reviewing it)..."
        mkdir -p "$HOME/Library/LaunchAgents"
        cp -R LaunchAgents/. "$HOME/Library/LaunchAgents/"
    fi
}

# =====================================================================
# SECTION 9: RESTORE SSH KEYS (SECRET authentication keys)
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
# folder to owner-only access (rwx for you, nothing for anyone else,
# 4+2+1=7), and "chmod 600 ~/.ssh/*" restricts every individual key file
# to owner read/write only (4+2=6, nothing for group or everyone). SSH
# actively refuses to use keys that are readable by other users, so
# these permission fixes are required, not optional hardening.
# WHY this matters: this is the point where a real private key is
# written to disk on the new machine, outside of any git-tracked
# location. It's not a git-safety step (that's handled by .gitignore in
# the backup step), it's an OS-permission-safety step, making sure the
# restored key is only ever readable by the machine's owner. Note this
# will silently overwrite an existing ~/.ssh with the same filenames if
# one already exists on the target machine, that mirrors the original
# script's behavior and was intentionally left unchanged here.
restore_ssh_keys() {
    # Creates the .ssh folder in your home directory if it doesn't already
    # exist. The -p flag means "make parent folders if needed" and "don't
    # complain if it already exists". SSH keys MUST live in ~/.ssh, if this
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
# SECTION 10: RESTORE OTHER SECRETS (GPG, cloud CLI configs, registry tokens)
# =====================================================================
# WHAT: Restores GPG keys, AWS/gcloud/kube credentials, and npm/yarn
# registry configs, locking down permissions the same way SSH keys are.
# HOW: Same pattern as restore_ssh_keys, each secret is only restored if
# its backup actually exists. GPG and AWS credential folders get
# "chmod -R go-rwx" (strip all group/other access recursively) rather
# than a flat "chmod 600 *", because both can contain subfolders (like
# GPG's private-keys-v1.d) that still need their owner-execute bit to
# stay traversable, a blanket 600 on a directory would lock the owner
# out of it too. The kube config is a single file, so a plain 600 is enough.
# WHY: These are the same category of bearer secret as an SSH key,
# skipping them here would mean re-authenticating every cloud CLI and
# regenerating a GPG key from scratch on every new machine.
restore_secrets() {
    if [ -d "dotfiles/gnupg_backup" ]; then
        echo "🔐 Restoring GPG keys..."
        cp -R dotfiles/gnupg_backup "$HOME/.gnupg"
        chmod -R go-rwx "$HOME/.gnupg"
    fi

    if [ -d "dotfiles/aws_backup" ]; then
        echo "🔐 Restoring AWS credentials..."
        cp -R dotfiles/aws_backup "$HOME/.aws"
        chmod -R go-rwx "$HOME/.aws"
    fi

    if [ -d "dotfiles/gcloud_backup" ]; then
        echo "🔐 Restoring gcloud credentials..."
        mkdir -p "$HOME/.config"
        cp -R dotfiles/gcloud_backup "$HOME/.config/gcloud"
    fi

    if [ -f "dotfiles/kube_backup/config" ]; then
        echo "🔐 Restoring kube config..."
        mkdir -p "$HOME/.kube"
        cp dotfiles/kube_backup/config "$HOME/.kube/config"
        chmod 600 "$HOME/.kube/config"
    fi

    [ -f "dotfiles/npmrc.bak" ] && cp "dotfiles/npmrc.bak" "$HOME/.npmrc"
    [ -f "dotfiles/yarnrc.bak" ] && cp "dotfiles/yarnrc.bak" "$HOME/.yarnrc"
}

# =====================================================================
# DONE, TELL THE USER THE RESTORE IS FINISHED
# =====================================================================

# WHAT: Prints the final success message and next-step reminders.
# WHY: The terminal loads configuration files (.zshrc, .bash_profile)
# only at startup, without restarting, the old (empty/default)
# configuration stays in effect and none of the restored settings take
# hold, so the user is explicitly told to restart. LaunchAgents are also
# deliberately left unloaded (see restore_scheduled_tasks), so that's
# called out too.
print_restore_complete() {
    echo "✅ System restore complete! Please restart your terminal."
    echo "   If any LaunchAgents were restored, review them and run 'launchctl load' on each you want active."
}

# =====================================================================
# MAIN, RUN EVERY RESTORE STEP IN ORDER
# =====================================================================
# WHAT: Calls each single-purpose function above in order.
# WHY: Keeping the sequence explicit and in one place makes it obvious
# at a glance what a full restore run does, without re-reading every
# function body.
main() {
    echo "🏁 Starting system restore..."

    install_homebrew_if_missing
    restore_homebrew_packages
    restore_language_packages
    restore_language_versions
    restore_dotfiles
    restore_vscode_config
    restore_app_inventory
    restore_scheduled_tasks
    restore_ssh_keys
    restore_secrets
    print_restore_complete
}

main
