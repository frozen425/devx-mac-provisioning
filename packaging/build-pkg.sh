#!/bin/bash
# build-pkg.sh
# Combines assets and scripts to compile a native macOS installation package (.pkg).
# Can be run locally or in a CI/CD pipeline.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_ROOT="$SCRIPT_DIR/build_root"
SCRIPTS_ROOT="$SCRIPT_DIR/scripts"
DIST_DIR="$REPO_ROOT/dist"

# Configurable package metadata
PKG_IDENTIFIER="com.frozen425.devx.provisioning"
PKG_VERSION="${1:-1.0.0}"
PKG_NAME="devx-mac-provisioning.pkg"

echo "Building package: $PKG_NAME"

# Clean previous build artifacts
rm -rf "$BUILD_ROOT" "$SCRIPTS_ROOT"
mkdir -p "$BUILD_ROOT/Library/Application Support/DevX/assets"
mkdir -p "$SCRIPTS_ROOT"
mkdir -p "$DIST_DIR"

# 1. Stage assets to install location
echo "Staging assets..."
cp "$REPO_ROOT/assets/Brewfile" "$BUILD_ROOT/Library/Application Support/DevX/assets/"
cp "$REPO_ROOT/assets/mise.config.toml" "$BUILD_ROOT/Library/Application Support/DevX/assets/"
cp "$REPO_ROOT/assets/zshrc.global" "$BUILD_ROOT/Library/Application Support/DevX/assets/"

# 2. Stage postinstall script
echo "Staging scripts..."
cp "$REPO_ROOT/scripts/install-orchestrator.sh" "$SCRIPTS_ROOT/postinstall"
chmod +x "$SCRIPTS_ROOT/postinstall"

# 3. Build the package
SIGNING_IDENTITY="${SIGNING_IDENTITY:-}"

if [ -n "$SIGNING_IDENTITY" ]; then
    echo "Signing package using identity: $SIGNING_IDENTITY"
    pkgbuild --root "$BUILD_ROOT" \
             --scripts "$SCRIPTS_ROOT" \
             --identifier "$PKG_IDENTIFIER" \
             --version "$PKG_VERSION" \
             --install-location "/" \
             --sign "$SIGNING_IDENTITY" \
             "$DIST_DIR/$PKG_NAME"
else
    echo "Warning: No SIGNING_IDENTITY environment variable detected. Building unsigned package..."
    pkgbuild --root "$BUILD_ROOT" \
             --scripts "$SCRIPTS_ROOT" \
             --identifier "$PKG_IDENTIFIER" \
             --version "$PKG_VERSION" \
             --install-location "/" \
             "$DIST_DIR/$PKG_NAME"
fi

# Clean up build root
rm -rf "$BUILD_ROOT" "$SCRIPTS_ROOT"

echo "Package compiled successfully at: dist/$PKG_NAME"
