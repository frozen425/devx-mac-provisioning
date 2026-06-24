# Installation Guide: Google Antigravity & Claude Suite

This guide contains step-by-step instructions for end-users to download and install:
1. **Google Antigravity 2.0**
2. **Google Antigravity IDE**
3. **Claude Suite** (Claude Code, Claude Desktop, and Claude Cowork)

You can run the helper utility `./scripts/download-urls.sh all` in this repository to print the correct, architecture-specific download links for your machine.

---

## 1. Google Antigravity 2.0 & Google Antigravity IDE

Both products are packaged as macOS disk images (`.dmg`).

### Step-by-Step Installation:
1. **Download the Installer**:
   - Determine your architecture-specific URL by running:
     ```bash
     ./scripts/download-urls.sh all
     ```
   - For **Google Antigravity 2.0**: Navigate to the link returned by `./scripts/download-urls.sh antigravity` in your browser.
   - For **Google Antigravity IDE**: Navigate to the link returned by `./scripts/download-urls.sh antigravity-ide` in your browser.
2. **Mount the DMG**:
   - Double-click the downloaded `.dmg` file in Finder, or run:
     ```bash
     hdiutil attach ~/Downloads/Antigravity-*.dmg
     # or
     hdiutil attach ~/Downloads/AntigravityIDE-*.dmg
     ```
3. **Install the Application**:
   - Drag the application icon to your **Applications** folder, or run:
     ```bash
     cp -R "/Volumes/Antigravity/Antigravity.app" /Applications/
     # or
     cp -R "/Volumes/AntigravityIDE/AntigravityIDE.app" /Applications/
     ```
4. **Clean Up**:
   - Eject the DMG disk image in Finder, or run:
     ```bash
     hdiutil detach "/Volumes/Antigravity"
     # or
     hdiutil detach "/Volumes/AntigravityIDE"
     ```

---

## 2. Claude Desktop & Claude Cowork

Claude Desktop provides a unified graphical application for both standard Claude chat sessions and autonomous Cowork workflows.

### Step-by-Step Installation:
1. **Download the Installer**:
   - Run `./scripts/download-urls.sh claude-desktop` to get the latest DMG link, or download directly from your browser.
2. **Mount and Install**:
   - Double-click `Claude.dmg` and drag the **Claude** application icon to your **Applications** folder, or run:
     ```bash
     hdiutil attach ~/Downloads/Claude.dmg
     cp -R "/Volumes/Claude/Claude.app" /Applications/
     hdiutil detach "/Volumes/Claude"
     ```
3. **Activating Claude Cowork**:
   - **Claude Cowork** is built directly into the Claude Desktop app.
   - Launch Claude from your Applications folder.
   - Log into your Anthropic/Claude account.
   - Select the **Cowork** tab in the sidebar interface to begin running background workflow agents.

---

## 3. Claude Code (Terminal CLI)

Claude Code is an agentic coding CLI tool designed for direct command-line workflows.

### Step-by-Step Installation:
You can bootstrap the installation using one of two methods:

#### Method A: Direct Installer Script (Recommended)
Run the official Anthropic installation script:
```bash
curl -fsSL https://claude.ai/install.sh | bash
```

#### Method B: Global NPM Package (Alternative)
Since this repository provisions Node and `npm` via `mise`, you can install Claude Code as a global npm package:
1. Ensure your Zsh shell has loaded Node (via `mise`):
   ```bash
   node --version
   ```
2. Install the package globally:
   ```bash
   npm install -g @anthropic-ai/claude-code
   ```

### Post-Install Verification
Run the following to initialize and authenticate the CLI:
```bash
claude
```
