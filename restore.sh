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
# your new computer.

# Prints a friendly message so the user knows the restore process has begun.
echo "🏁 Starting system restore..."

# =====================================================================
# SECTION 1: INSTALL HOMEBREW IF IT IS MISSING
# =====================================================================
# Homebrew is a free package manager for macOS. It lets you install
# developer tools and desktop apps from the terminal instead of hunting
# for download links on websites. The restore process needs Homebrew
# first because everything else (apps, casks) depends on it.

# This checks whether the "brew" command is available on your system.
# "command -v brew" looks up whether a program called "brew" exists.
# "&> /dev/null" hides all output (both regular output and errors) so
# the terminal stays clean. The "!" at the start means "if NOT" — so
# this block runs only when Homebrew is NOT installed.
if ! command -v brew &> /dev/null; then

    # Tells the user that Homebrew is missing and is being installed.
    echo "🍺 Homebrew not found. Installing Homebrew..."

    # Downloads and runs the official Homebrew installer script from the
    # internet. "curl" is a tool that downloads files from URLs. The flags
    # mean: "-f" (fail silently on HTTP errors), "-s" (silent mode, no
    # progress bar), "-S" (show errors even in silent mode), "-L" (follow
    # redirects if the URL moves). The "/bin/bash -c" part runs the
    # downloaded script as a Bash command.
    /bin/bash -c "$(curl -fsSL https://githubusercontent.com)"

    # This checks what type of Mac processor you have. "uname -m" returns
    # the machine hardware name. On Apple Silicon Macs (M1, M2, M3, etc.)
    # it returns "arm64". On older Intel Macs it returns "x86_64". Apple
    # Silicon Macs need an extra step to add Homebrew to the system PATH
    # (the list of folders the system searches for programs).
    if [[ "$(uname -m)" == "arm64" ]]; then

        # "eval" runs a command that Homebrew's installer told us to run.
        # "brew shellenv" outputs settings that tell the system where to
        # find the brew command. On Apple Silicon, Homebrew installs to
        # /opt/homebrew instead of /usr/local, so the PATH must be updated.
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
else
    # This runs when Homebrew IS already installed — just tells the user
    # so they know this step was skipped and nothing is wrong.
    echo "🍺 Homebrew is already installed."
fi

# =====================================================================
# SECTION 2: RESTORE HOMEBREW APPS AND CASKS
# =====================================================================
# A "Brewfile" is a text file that lists every app and tool that was
# backed up by backup.sh. "Brew bundle" reads this file and installs
# everything in it — both command-line tools and GUI apps (called "casks").

# This checks if a file called "Brewfile" exists in the current
# directory. "-f" means "does this regular file exist?". You must run
# this script from inside the backup folder for it to find the Brewfile.
if [ -f "Brewfile" ]; then

    # Tells the user that app restoration is starting.
    echo "📦 Restoring Homebrew packages and desktop apps..."

    # "brew bundle" reads the Brewfile and installs every tool and app
    # listed in it. This is the magic command that turns a fresh Mac into
    # your fully-loaded dev machine with one line.
    brew bundle
else

    # Warns the user that no Brewfile was found. This usually means they
    # ran the script from the wrong folder, or the backup didn't include
    # a Brewfile. The warning emoji makes it easy to spot in the output.
    echo "⚠️ Brewfile not found in current directory!"
fi

# =====================================================================
# SECTION 3: RESTORE CODING LANGUAGE PACKAGES
# =====================================================================
# This section reinstalls the extra libraries for JavaScript (NPM),
# Python (PIP), and Ruby (GEM) that were saved during backup. Each
# language's packages are only installed if both the list file AND the
# language's package manager exist on the system.

# Prints a status message.
echo "🌐 Restoring language packages..."

# This line does TWO checks with "&&" (AND logic):
#   1. Does the file "global-npm-packages.txt" exist? (was it backed up?)
#   2. Is the "npm" command available? (is Node.js installed?)
# Both must be true before attempting installation. If either is false,
# the whole line is skipped silently — no errors, no noise.
if [ -f "global-npm-packages.txt" ] && command -v npm &> /dev/null; then

    # Tells the user what's about to happen.
    echo "Installing global NPM packages..."

    # "xargs" reads a list of package names from the file (one per line)
    # and passes them all to "npm install -g" as arguments. The "-g"
    # flag means install them globally (available everywhere, not just
    # one project folder). This is how we turn a text list back into
    # installed packages.
    xargs npm install -g < global-npm-packages.txt
fi

# Same pattern for Python: check that the requirements file exists AND
# that pip is installed before trying to restore Python packages.
if [ -f "requirements.txt" ] && command -v pip &> /dev/null; then

    # Tells the user Python package installation is starting.
    echo "Installing Python packages..."

    # "pip install -r" reads the requirements.txt file and installs every
    # Python package listed in it, along with the correct version numbers
    # that were recorded during backup. This ensures you get the exact
    # same versions, avoiding compatibility problems.
    pip install -r requirements.txt
fi

# =====================================================================
# SECTION 4: RESTORE DOTFILES AND SSH KEYS
# =====================================================================
# Dotfiles are hidden configuration files (they start with a dot) that
# control how your terminal, Git, and SSH behave. SSH keys are secret
# files that let your computer prove its identity to servers like GitHub.
# Restoring these saves hours of manual re-configuration.

# Prints a status message.
echo "🔒 Restoring configuration files..."

# Creates the .ssh folder in your home directory if it doesn't already
# exist. The -p flag means "make parent folders if needed" and "don't
# complain if it already exists". SSH keys MUST live in ~/.ssh — if this
# folder doesn't exist, SSH won't work at all.
mkdir -p "$HOME/.ssh"

# This restores your Zsh configuration file. The pattern used here is:
#   [ condition ] && action
# This means "if the condition is true, then do the action." Specifically:
# Does "dotfiles/zshrc.bak" exist? If yes, copy it back to ~/.zshrc.
# This is safer than always copying because the backup might not include
# every dotfile (the user might not have had a .zshrc to begin with).
[ -f "dotfiles/zshrc.bak" ] && cp "dotfiles/zshrc.bak" "$HOME/.zshrc"

# Restores your Bash profile using the same safe check-then-copy pattern.
# If the backup includes a bash_profile.bak, it gets copied back to
# ~/.bash_profile. If not, this line does nothing and causes no errors.
[ -f "dotfiles/bash_profile.bak" ] && cp "dotfiles/bash_profile.bak" "$HOME/.bash_profile"

# Restores your Git configuration using the same pattern. This puts back
# your name, email, editor preferences, and any other Git settings you
# had customized on your old machine.
[ -f "dotfiles/gitconfig.bak" ] && cp "dotfiles/gitconfig.bak" "$HOME/.gitconfig"

# This checks if the backed-up SSH folder exists. If the backup included
# SSH keys, they'll be in a folder called "ssh_backup" inside "dotfiles".
# The -d flag checks for the existence of a directory (folder).
if [ -d "dotfiles/ssh_backup" ]; then

    # Tells the user that SSH key restoration is happening.
    echo "🔑 Restoring SSH keys..."

    # Copies all files from the backed-up ssh_backup folder into your
    # new ~/.ssh folder. The "*" is a wildcard that means "everything".
    # The -R flag means recursive (copy all contents, not just the folder).
    cp -R dotfiles/ssh_backup/* "$HOME/.ssh/"

    # Sets the .ssh folder's permissions to 700, which means: only YOU
    # can read, write, or enter this folder. No other user on the Mac
    # and no programs running as other users can access it. SSH REQUIRES
    # this strict permission — if it's too open, SSH will refuse to use
    # your keys and show confusing error messages. The number 700 breaks
    # down as: owner=read+write+execute (4+2+1=7), group=nothing (0),
    # everyone=nothing (0).
    chmod 700 "$HOME/.ssh"

    # Sets each individual key file's permissions to 600, which means:
    # only YOU can read and write to the file. No one else can see your
    # secret keys. SSH will refuse to work if your key files are readable
    # by anyone else — it's a security feature. The number 600 breaks
    # down as: owner=read+write (4+2=6), group=nothing (0), everyone=nothing (0).
    chmod 600 "$HOME/.ssh/"*
fi

# =====================================================================
# DONE — TELL THE USER THE RESTORE IS FINISHED
# =====================================================================

# Prints a final success message telling the user the restore is complete
# and that they should restart their terminal. Restarting is necessary
# because the terminal loads configuration files (.zshrc, .bash_profile)
# when it starts up — without restarting, the old (empty) configuration
# would still be in effect and none of the restored settings would work.
echo "✅ System restore complete! Please restart your terminal."
