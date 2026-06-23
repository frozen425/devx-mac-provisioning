# devx-mac-provisioning

Centralized fleet configuration and automated provisioning orchestrator for macOS developer workstations.

This repository compiles verified macOS installer packages (`.pkg`) distributed via Mobile Device Management (MDM) to automate and enforce standard development environment configurations.

---

## Directory Structure

```text
devx-mac-provisioning/
├── .github/
│   └── workflows/
│       ├── security-gate.yml      # OSV vulnerability scanner and bash syntaxes
│       └── release-package.yml    # Compiles and signs the installer .pkg
├── assets/
│   ├── Brewfile                   # Baseline applications, casks, and custom taps
│   ├── mise.config.toml           # Default programming runtime versions
│   └── zshrc.global               # Global shell configurations sourced by Zsh
├── packaging/
│   ├── build-pkg.sh               # Local and CI packaging wrapper script
│   └── project.plist              # Metadata configurations for pkgbuild
└── scripts/
    ├── install-orchestrator.sh    # Post-install engine (Homebrew, Brewfile, paths)
    └── preflight-check.sh         # Local pre-commit vulnerability scanner and linter
```

---

## Getting Started

### 1. Prerequisite Bootstrap
For initial bootstrapping on a clean machine:
```bash
curl -fsSL https://raw.githubusercontent.com/frozen425/devx-mac-provisioning/main/scripts/install-orchestrator.sh | bash
```
> [!NOTE]
> When executing via MDM (e.g. Kandji, Jamf), the installer package installs the configuration files into `/Library/Application Support/DevX` and automatically fires the orchestrator script in the post-install phase as `root`.

### 2. Local Verification
Before committing changes to the baseline, run the local preflight suite:
```bash
./scripts/preflight-check.sh
```

---

## Security Guidelines

> [!CAUTION]
> **No Secrets / SA Keys Policy**:
> Do not commit Google Cloud Service Account key files (`.json`), AWS credentials, signing private keys, or API tokens under any circumstances.
> All workstation authentication must go through interactive login flows (e.g. running `sm login` manually) which securely persists credentials inside local user keystores.

### Homebrew Tap Namespace
All custom tools (such as `sm`) must utilize the `frozen425/internal` tap namespace.
Example declaration in `Brewfile`:
```ruby
tap "frozen425/internal"
brew "frozen425/internal/sm"
```

---

## Development Lifecycle for Platform Engineers

1. **Modify Assets**: Make edits to `assets/Brewfile` or `assets/mise.config.toml` on a feature branch.
2. **Local Run**: Execute `./scripts/preflight-check.sh` to check for syntax and vulnerabilities.
3. **Submit PR**: Open a pull request against the `main` branch. The `Security Gate` action runs checks.
4. **Approve & Merge**: Once approved by codeowners, the merge to `main` triggers release packaging automatically.
