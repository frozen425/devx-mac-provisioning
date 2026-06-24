#!/bin/bash
# preflight-check.sh
# Runs local validation tests, lints, and security scans on configuration files before committing.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
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

# Ensure the script is NOT run as root/sudo
if [ "$EUID" -eq 0 ]; then
    error "This preflight check script must NOT be run as root / sudo."
    echo "Please run it as your standard user: ./scripts/preflight-check.sh" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

log "Starting preflight checks..."

# 1. Check if osv-scanner is installed
OSV_SCANNER_CMD="osv-scanner"
if ! command -v osv-scanner >/dev/null 2>&1; then
    warn "osv-scanner is not in current PATH. Checking Homebrew paths..."
    if [[ -f "/opt/homebrew/bin/osv-scanner" ]]; then
        OSV_SCANNER_CMD="/opt/homebrew/bin/osv-scanner"
    elif [[ -f "/usr/local/bin/osv-scanner" ]]; then
        OSV_SCANNER_CMD="/usr/local/bin/osv-scanner"
    else
        warn "osv-scanner not found. Please install it using 'brew install google/osv-scanner/osv-scanner' to run vulnerability scans."
        OSV_SCANNER_CMD=""
    fi
fi

# 2. Run OSV Scanner recursively on the repo
if [[ -n "$OSV_SCANNER_CMD" ]]; then
    log "Running OSV-Scanner recursively on the repository..."
    if "$OSV_SCANNER_CMD" -r "$REPO_ROOT" >/dev/null 2>&1; then
        log "OSV-Scanner check passed. No known vulnerabilities found."
    else
        warn "OSV-Scanner scan detected potential vulnerabilities or failed. Run manually:"
        echo "  $OSV_SCANNER_CMD -r \"$REPO_ROOT\""
    fi
fi

# 3. Check for obvious sensitive files / pattern leaks
log "Scanning repository for potential secrets..."
LEAKS_FOUND=0
# Search for private keys, AWS keys, service account JSON key structures, etc.
# Check files (excluding scripts/preflight-check.sh itself and .git)
while IFS= read -r file; do
    if [[ -f "$file" ]]; then
        # Check for typical private key markers or "private_key_id" or "client_secret"
        if grep -qiE "private_key|client_secret|api_key|service_account|secret_key" "$file"; then
            error "Potential secret/credential marker found in: $file"
            LEAKS_FOUND=$((LEAKS_FOUND + 1))
        fi
    fi
done < <(find "$REPO_ROOT" -type f -not -path '*/.*' -not -name 'preflight-check.sh')

if [ "$LEAKS_FOUND" -ne 0 ]; then
    error "Security Gate Failed: Potential credentials or sensitive keys detected."
    exit 1
else
    log "Secret scanning passed. No high-risk string patterns detected."
fi

# 4. Check syntax of shell scripts
log "Checking syntax of shell scripts..."
SYNTAX_ERRORS=0
while IFS= read -r sh_file; do
    if ! bash -n "$sh_file"; then
        error "Syntax error in shell script: $sh_file"
        SYNTAX_ERRORS=$((SYNTAX_ERRORS + 1))
    fi
done < <(find "$REPO_ROOT" -name "*.sh")

if [ "$SYNTAX_ERRORS" -ne 0 ]; then
    error "Shell script syntax checks failed."
    exit 1
else
    log "All shell scripts passed syntax validation."
fi

# 5. Lint shell scripts with ShellCheck (if installed)
if command -v shellcheck >/dev/null 2>&1; then
    log "Linting shell scripts with ShellCheck..."
    SHELLCHECK_ERRORS=0
    while IFS= read -r sh_file; do
        if ! shellcheck "$sh_file"; then
            error "ShellCheck lint failed for: $sh_file"
            SHELLCHECK_ERRORS=$((SHELLCHECK_ERRORS + 1))
        fi
    done < <(find "$REPO_ROOT" -name "*.sh")

    if [ "$SHELLCHECK_ERRORS" -ne 0 ]; then
        error "ShellCheck linting checks failed."
        exit 1
    else
        log "All shell scripts passed ShellCheck linting."
    fi
else
    warn "shellcheck not found. Skipping linting. Install it with 'brew install shellcheck' to enable."
fi

log "Preflight checks completed successfully!"
