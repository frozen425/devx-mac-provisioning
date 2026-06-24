#!/bin/bash
# bootstrap-dryrun.sh
# Diagnostic dry-run script to verify workstation readiness prior to full bootstrapping.

set -euo pipefail

# Ensure Homebrew doesn't prompt for tap trust in automated dry-runs
export HOMEBREW_NO_REQUIRE_TAP_TRUST=1

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[INFO] $*${NC}"
}

warn() {
    echo -e "${YELLOW}[WARN] $*${NC}"
}

error() {
    echo -e "${RED}[ERROR] $*${NC}" >&2
}

info() {
    echo -e "${BLUE}[DIAG] $*${NC}"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
BREWFILE="$REPO_ROOT/assets/Brewfile"
MISE_CONFIG="$REPO_ROOT/assets/mise.config.toml"

echo "=========================================================="
echo "          macOS WORKSTATION BOOTSTRAP DRY-RUN             "
echo "=========================================================="

# 1. System Diagnostics
info "System Information:"
OS_VER=$(sw_vers -productVersion)
ARCH=$(uname -m)
echo "  OS Version   : macOS $OS_VER"
echo "  Architecture : $ARCH"

# 2. Check Git installation (needed for cloning)
if command -v git >/dev/null 2>&1; then
    log "Git is installed ($(git --version))"
else
    warn "Git is not installed. Git will be installed via Homebrew during bootstrap."
fi

# 3. Check Homebrew status
if [ "$ARCH" = "arm64" ]; then
    BREW_PATH="/opt/homebrew/bin/brew"
else
    BREW_PATH="/usr/local/bin/brew"
fi

BREW_INSTALLED=0
if [ -f "$BREW_PATH" ]; then
    log "Homebrew detected at $BREW_PATH"
    eval "$($BREW_PATH shellenv)"
    BREW_INSTALLED=1
else
    warn "Homebrew is NOT installed. The bootstrap process will install it to $BREW_PATH."
fi

# 4. Check dependencies in Brewfile
if [ ! -f "$BREWFILE" ]; then
    error "Brewfile not found at $BREWFILE"
    exit 1
fi

info "Analyzing Brewfile dependencies..."
# Extract taps, brew formulas, and casks
TAPS=$(grep -E '^tap ' "$BREWFILE" | awk -F'"' '{print $2}')
BREWS=$(grep -E '^brew ' "$BREWFILE" | awk -F'"' '{print $2}')
CASKS=$(grep -E '^cask ' "$BREWFILE" | awk -F'"' '{print $2}')

if [ "$BREW_INSTALLED" -eq 1 ]; then
    # Run bundle check to see what is already satisfied
    echo "  Checking which packages are already installed..."
    if $BREW_PATH bundle check --file="$BREWFILE" >/dev/null 2>&1; then
        log "All Brewfile dependencies are already satisfied!"
    else
        echo "  The following packages are missing and will be installed:"
        $BREW_PATH bundle list --file="$BREWFILE" || true
    fi
    
    # Test accessibility of external taps and formulas
    echo "  Verifying connectivity to taps and package configurations..."
    for tap in $TAPS; do
        if ! $BREW_PATH tap | grep -q "^$tap$"; then
            echo -n "    Testing tap '$tap' access... "
            # Parse owner and repo name from tap (owner/repo)
            owner="${tap%%/*}"
            repo="${tap##*/}"
            github_url="https://github.com/${owner}/homebrew-${repo}"
            
            if curl -fsSL -o /dev/null "$github_url" 2>/dev/null; then
                echo -e "${GREEN}Accessible${NC}"
            else
                # Fallback to direct owner/repo check
                if curl -fsSL -o /dev/null "https://github.com/${owner}/${repo}" 2>/dev/null; then
                    echo -e "${GREEN}Accessible${NC}"
                else
                    echo -e "${RED}Failed (Check connection or repository permissions)${NC}"
                fi
            fi
        fi
    done
    
    # Test formula info resolution
    for brew in $BREWS; do
        echo -n "    Resolving formula '$brew' metadata... "
        if $BREW_PATH info "$brew" >/dev/null 2>&1; then
            echo -e "${GREEN}OK${NC}"
        else
            # Try to resolve it via declared taps if not tapped yet
            resolved=0
            for tap in $TAPS; do
                if $BREW_PATH info "${tap}/${brew}" >/dev/null 2>&1; then
                    echo -e "${GREEN}OK (via ${tap})${NC}"
                    resolved=1
                    break
                fi
            done
            if [ "$resolved" -eq 0 ]; then
                echo -e "${RED}Failed${NC}"
            fi
        fi
    done
    
    # Test cask info resolution
    for cask in $CASKS; do
        echo -n "    Resolving cask '$cask' metadata... "
        if $BREW_PATH info --cask "$cask" >/dev/null 2>&1; then
            echo -e "${GREEN}OK${NC}"
        else
            echo -e "${RED}Failed${NC}"
        fi
    done
else
    warn "Homebrew is not installed. Skipping online package resolution diagnostics."
    echo "  Taps to be configured: $TAPS"
    echo "  Formulas to be installed: $BREWS"
    echo "  Casks to be installed: $CASKS"
fi

# 5. Check mise presets
if [ -f "$MISE_CONFIG" ]; then
    info "Mise development tools configured:"
    # Extract mise tools
    while IFS= read -r line; do
        if [[ "$line" =~ ^[a-zA-Z0-9_-]+[[:space:]]*=[[:space:]]*\"[^\"]+\" ]]; then
            echo "  - $line"
        fi
    done < "$MISE_CONFIG"
else
    error "mise config not found at $MISE_CONFIG"
fi

# 6. Verify access to external sm repository
info "Verifying access to sm CLI source repository..."
if git ls-remote https://github.com/frozen425/sm.git >/dev/null 2>&1; then
    log "Successfully verified connection to https://github.com/frozen425/sm.git"
else
    error "Could not connect to https://github.com/frozen425/sm.git (Check internet or access rules)"
fi

echo "=========================================================="
echo "             DRY-RUN DIAGNOSTICS COMPLETED                "
echo "=========================================================="
