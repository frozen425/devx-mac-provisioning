#!/bin/bash
# install-orchestrator.sh
# Automated macOS workstation provisioning script.
# Designed to be run via MDM (e.g. Kandji, Jamf) as root.

set -euo pipefail

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $*"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*" >&2
}

# 1. Determine local user (Homebrew must not run as root)
log "Detecting local user..."
CONSOLE_USER=$(stat -f '%Su' /dev/console)
if [ -z "$CONSOLE_USER" ] || [ "$CONSOLE_USER" = "root" ] || [ "$CONSOLE_USER" = "loginwindow" ]; then
    CONSOLE_USER=$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ { print $3 }')
fi

if [ -z "$CONSOLE_USER" ] || [ "$CONSOLE_USER" = "root" ] || [ "$CONSOLE_USER" = "loginwindow" ]; then
    # Fallback to the first non-system user
    CONSOLE_USER=$(dscl . -list /Users UniqueID | awk '$2 >= 501 {print $1}' | grep -v "Shared" | head -n1)
fi

if [ -z "$CONSOLE_USER" ]; then
    error "Could not determine local user. Exiting."
    exit 1
fi

log "Local user identified as: $CONSOLE_USER"

# 2. Check and Install Homebrew
if [ "$(uname -m)" = "arm64" ]; then
    BREW_PATH="/opt/homebrew/bin/brew"
else
    BREW_PATH="/usr/local/bin/brew"
fi

if [ ! -f "$BREW_PATH" ]; then
    log "Homebrew not found. Installing..."
    # Run the official Homebrew installer as the console user
    sudo -u "$CONSOLE_USER" -i env NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    log "Homebrew installation completed."
else
    log "Homebrew is already installed at $BREW_PATH"
fi

# 3. Ensure Homebrew environment is activated for this session
eval "$($BREW_PATH shellenv)"

# 4. Install assets using Brewfile
BREWFILE_PATH="/Library/Application Support/DevX/assets/Brewfile"
if [ ! -f "$BREWFILE_PATH" ]; then
    # Fallback to local script relative path for manual runs
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    BREWFILE_PATH="$(dirname "$SCRIPT_DIR")/assets/Brewfile"
fi

if [ -f "$BREWFILE_PATH" ]; then
    log "Installing fleet baseline dependencies from $BREWFILE_PATH..."
    # Run brew bundle as the local user so packages are owned/managed by the user
    sudo -u "$CONSOLE_USER" -i env PATH="$PATH" "$BREW_PATH" bundle install --file="$BREWFILE_PATH"
    log "Dependencies install completed."
else
    error "Brewfile not found at $BREWFILE_PATH"
    exit 1
fi

# 5. Link Global Zsh Profile
GLOBAL_ZSHRC="/Library/Application Support/DevX/assets/zshrc.global"
if [ -f "$GLOBAL_ZSHRC" ]; then
    log "Configuring global shell environment..."
    # Source the global zshrc from the system-wide zshrc if not already present
    ETC_ZSHRC="/etc/zshrc"
    ZSHRC_LINE="[[ -f \"$GLOBAL_ZSHRC\" ]] && source \"$GLOBAL_ZSHRC\""
    if ! grep -q "$GLOBAL_ZSHRC" "$ETC_ZSHRC" 2>/dev/null; then
        echo -e "\n# DevX Fleet Workstation Global Shell Defaults\n$ZSHRC_LINE" >> "$ETC_ZSHRC"
        log "Added DevX global Zsh source to $ETC_ZSHRC"
    else
        log "DevX global Zsh configuration already active in $ETC_ZSHRC"
    fi
fi

log "macOS Fleet Provisioning Orchestration Completed Successfully!"
