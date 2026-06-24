#!/bin/bash
# download-urls.sh
# Shell utilities to determine download URLs for Google Antigravity & Claude Suite.
# Usage: ./download-urls.sh [antigravity|antigravity-ide|claude-desktop|claude-code|claude-cowork]

set -euo pipefail

get_arch() {
    local arch
    arch=$(uname -m)
    if [ "$arch" = "arm64" ]; then
        echo "arm64"
    else
        echo "x64"
    fi
}

get_antigravity_url() {
    local arch
    arch=$(get_arch)
    if [ "$arch" = "arm64" ]; then
        echo "https://antigravity.google/download/mac/latest/Antigravity-arm64.dmg"
    else
        echo "https://antigravity.google/download/mac/latest/Antigravity-x64.dmg"
    fi
}

get_antigravity_ide_url() {
    local arch
    arch=$(get_arch)
    if [ "$arch" = "arm64" ]; then
        echo "https://antigravity.google/download/mac/latest/AntigravityIDE-arm64.dmg"
    else
        echo "https://antigravity.google/download/mac/latest/AntigravityIDE-x64.dmg"
    fi
}

get_claude_desktop_url() {
    # Direct download link for Claude Desktop macOS
    echo "https://desktop.claude.ai/mac/latest/Claude.dmg"
}

get_claude_code_url() {
    # Claude Code installation bash script
    echo "https://claude.ai/install.sh"
}

get_claude_cowork_url() {
    # Claude Cowork is a built-in tab inside Claude Desktop
    echo "https://desktop.claude.ai/mac/latest/Claude.dmg"
}

usage() {
    echo "Usage: $0 [tool_name]"
    echo "Available tool_names:"
    echo "  antigravity       - Google Antigravity 2.0 Standalone DMG"
    echo "  antigravity-ide   - Google Antigravity IDE DMG"
    echo "  claude-desktop    - Claude Desktop DMG"
    echo "  claude-code       - Claude Code CLI Bootstrap Script"
    echo "  claude-cowork     - Claude Cowork (part of Claude Desktop)"
    echo "  all               - Show all determined URLs"
    exit 1
}

if [ $# -lt 1 ]; then
    usage
fi

TOOL="${1}"

case "$TOOL" in
    antigravity)
        get_antigravity_url
        ;;
    antigravity-ide)
        get_antigravity_ide_url
        ;;
    claude-desktop)
        get_claude_desktop_url
        ;;
    claude-code)
        get_claude_code_url
        ;;
    claude-cowork)
        get_claude_cowork_url
        ;;
    all)
        echo "Determined URLs for $(uname -m) architecture:"
        echo "--------------------------------------------------"
        echo "Google Antigravity 2.0 : $(get_antigravity_url)"
        echo "Google Antigravity IDE : $(get_antigravity_ide_url)"
        echo "Claude Desktop         : $(get_claude_desktop_url)"
        echo "Claude Code            : $(get_claude_code_url) (Run: curl -fsSL \$(./download-urls.sh claude-code) | bash)"
        echo "Claude Cowork          : $(get_claude_cowork_url) (Included in Claude Desktop)"
        ;;
    *)
        usage
        ;;
esac
