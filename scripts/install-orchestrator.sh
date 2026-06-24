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
    log "Homebrew is already installed at $BREW_PATH. Attempting to update..."
    if ! sudo -u "$CONSOLE_USER" -i env PATH="$PATH" "$BREW_PATH" update; then
        log "Warning: Homebrew update failed. Attempting to repair and update using the official installer..."
        sudo -u "$CONSOLE_USER" -i env NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    log "Homebrew update/repair completed."
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
    # Clean up deprecated homebrew/bundle tap if previously cached/installed
    if sudo -u "$CONSOLE_USER" -i env PATH="$PATH" "$BREW_PATH" tap | grep -qi "homebrew/bundle"; then
        log "Untapping deprecated homebrew/bundle..."
        sudo -u "$CONSOLE_USER" -i env PATH="$PATH" "$BREW_PATH" untap homebrew/bundle || true
    fi

    # Explicitly trust custom taps to support Homebrew 6.0+ non-interactively
    log "Configuring Homebrew tap trust for custom repositories..."
    sudo -u "$CONSOLE_USER" -i env PATH="$PATH" "$BREW_PATH" trust mondoohq/mondoo || true
    sudo -u "$CONSOLE_USER" -i env PATH="$PATH" "$BREW_PATH" trust hashicorp/tap || true

    log "Installing fleet baseline dependencies from $BREWFILE_PATH..."
    # Run brew bundle as the local user with HOMEBREW_NO_REQUIRE_TAP_TRUST=1 as a fallback
    sudo -u "$CONSOLE_USER" -i env PATH="$PATH" HOMEBREW_NO_REQUIRE_TAP_TRUST=1 "$BREW_PATH" bundle install --file="$BREWFILE_PATH"
    log "Dependencies install completed."
else
    error "Brewfile not found at $BREWFILE_PATH"
    exit 1
fi

# 5. Set up mise & Build sm from source
USER_HOME="/Users/$CONSOLE_USER"
MISE_CONFIG_SRC="/Library/Application Support/DevX/assets/mise.config.toml"
if [ ! -f "$MISE_CONFIG_SRC" ]; then
    # Fallback to local script relative path for manual runs
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    MISE_CONFIG_SRC="$(dirname "$SCRIPT_DIR")/assets/mise.config.toml"
fi

if [ -f "$MISE_CONFIG_SRC" ]; then
    log "Configuring mise global presets..."
    sudo -u "$CONSOLE_USER" mkdir -p "$USER_HOME/.config/mise"
    sudo -u "$CONSOLE_USER" cp "$MISE_CONFIG_SRC" "$USER_HOME/.config/mise/config.toml"
    
    # Initialize/install mise packages (Go, Node, Python)
    log "Installing mise runtimes (Go, Node, Python)..."
    MISE_DIR="$(dirname "$BREW_PATH")"
    sudo -u "$CONSOLE_USER" -i env PATH="$PATH:$MISE_DIR" "$MISE_DIR/mise" install --yes
else
    log "Warning: mise config source not found. Skipping runtime installation."
fi

# Clone and build sm
log "Setting up local working directory..."
WORKING_DIR="$USER_HOME/working"
sudo -u "$CONSOLE_USER" mkdir -p "$WORKING_DIR"

if [ ! -d "$WORKING_DIR/sm" ]; then
    log "Cloning sm repository..."
    sudo -u "$CONSOLE_USER" git clone https://github.com/frozen425/sm.git "$WORKING_DIR/sm"
else
    log "sm repository already exists. Updating..."
    sudo -u "$CONSOLE_USER" git -C "$WORKING_DIR/sm" pull
fi

log "Compiling and installing sm..."
MISE_DIR="$(dirname "$BREW_PATH")"
sudo -u "$CONSOLE_USER" -i env PATH="$PATH:$MISE_DIR" bash -c "cd ~/working/sm && \"$MISE_DIR/mise\" exec -- go install"
log "sm binary compiled and installed."

# 6. Link Global Zsh Profile
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

# 7. Configure GPG Agent for Graphical Passphrase Entry
GPG_CONF_DIR="$USER_HOME/.gnupg"
GPG_AGENT_CONF="$GPG_CONF_DIR/gpg-agent.conf"
log "Configuring GPG Agent to use pinentry-mac..."
sudo -u "$CONSOLE_USER" mkdir -p "$GPG_CONF_DIR"
sudo -u "$CONSOLE_USER" chmod 700 "$GPG_CONF_DIR"

if [ "$(uname -m)" = "arm64" ]; then
    PINENTRY_PATH="/opt/homebrew/bin/pinentry-mac"
else
    PINENTRY_PATH="/usr/local/bin/pinentry-mac"
fi

if [ ! -f "$GPG_AGENT_CONF" ] || ! grep -q "pinentry-program" "$GPG_AGENT_CONF" 2>/dev/null; then
    echo "pinentry-program $PINENTRY_PATH" | sudo -u "$CONSOLE_USER" tee -a "$GPG_AGENT_CONF" >/dev/null
    log "GPG Agent configured with pinentry-mac."
    # Reload agent to apply configuration
    sudo -u "$CONSOLE_USER" -i env PATH="$PATH" gpg-connect-agent reloadagent /bye || true
else
    log "GPG Agent already configured with pinentry-program."
fi

log "macOS Fleet Provisioning Orchestration Completed Successfully!"
