# Local macOS VM Provisioning for Provisioning Verification

To ensure that the bootstrapper, Brewfile configuration, and environment setups work reliably on clean installations, you should test them in an isolated macOS Virtual Machine (VM). Testing locally on a VM prevents package contamination on your host workstation and allows you to test scripts under clean-state conditions.

This guide outlines two recommended approaches for running local Apple Silicon (M-series) macOS VMs:
1. **Tart** (CLI-first, high performance, ideal for automation and scripting).
2. **UTM** (GUI-based, visual, user-friendly).

---

## Prerequisites
- Apple Silicon Mac (M1, M2, M3, M4 series).
- macOS 13.0 (Ventura) or newer on host.
- At least 30 GB of free disk space.

---

## Option 1: Tart (CLI-First & Automation-Friendly)

[Tart](https://github.com/cirruslabs/tart) is a command-line tool built on Apple's native `Virtualization.framework` designed specifically for running macOS and Linux VMs on Apple Silicon.

### 1. Installation
Install Tart using Homebrew:
```bash
brew install cirruslabs/cli/tart
```

### 2. Pull a Pre-built macOS Image
Tart allows you to pull clean, pre-configured macOS images directly from a container registry:
```bash
# Pull a clean macOS Sequoia image
tart pull ghcr.io/cirruslabs/macos-sequoia-base:latest
```
*(Default credentials for these base images: Username: `admin`, Password: `admin`)*

### 3. Clone and Run the VM with Directory Sharing
To test the provisioning repository, you must share the local `devx-mac-provisioning` directory with the guest VM.

Clone the base image to create your test runner:
```bash
tart clone ghcr.io/cirruslabs/macos-sequoia-base:latest test-vm
```

Start the VM, mounting your repository directory to the guest:
```bash
tart run --dir=repo:$(pwd) test-vm
```
*A VM window will open, booting directly to the desktop. The guest OS automatically mounts the shared folder at `/Volumes/repo`.*

### 4. Run the Bootstrap Orchestrator
Inside the VM guest terminal, run the orchestrator directly from the shared volume:
```bash
cd /Volumes/repo
sudo ./scripts/install-orchestrator.sh
```

### 5. Cleaning Up
Once verification is complete, delete the VM to free up disk space:
```bash
tart delete test-vm
```

---

## Option 2: UTM (GUI-Based)

[UTM](https://mac.getutm.app/) is a popular, open-source virtualization wrapper that supports Apple's native `Virtualization.framework` and QEMU.

### 1. Installation
Install UTM via Homebrew Cask:
```bash
brew install --cask utm
```

### 2. Create the Virtual Machine
1. Open UTM and click **Create a New Virtual Machine**.
2. Select **Virtualize** (offers near-native speed using Virtualization.framework).
3. Select **macOS 12+**.
4. To select a restore image (IPSW), click **Browse...** and choose an IPSW file, or leave it blank to let UTM automatically download the latest stable macOS version from Apple.
5. Allocate hardware:
   - **Memory**: Minimum 8 GB (8192 MB) recommended.
   - **CPU Cores**: Minimum 4 cores recommended.
6. Allocate Drive Size: Minimum 32 GB.
7. Click **Save**.

### 3. Enable Directory Sharing (VirtioFS)
Before starting the VM:
1. In the UTM sidebar, right-click your new VM and choose **Edit**.
2. Navigate to **Sharing** tab.
3. Select **Directory Sharing** -> **VirtioFS**.
4. Click the **+** (Add) button under **Shared Directories**, select the `devx-mac-provisioning` directory on your host, and set the label to `repo`.
5. Save the configuration.

### 4. Set Up macOS and Execute Bootstrap
1. Click the **Play** button to boot the VM and go through the initial Apple Setup Assistant.
2. In the guest VM, mount the VirtioFS directory. Open Terminal and run:
   ```bash
   mkdir -p ~/Desktop/repo
   mount -t virtiofs repo ~/Desktop/repo
   ```
3. Run the installer:
   ```bash
   cd ~/Desktop/repo
   sudo ./scripts/install-orchestrator.sh
   ```

---

## Post-Run Verification Checklist

After the orchestrator completes running inside the guest VM, verify the following:
- [ ] Run `brew --version` to verify Homebrew is installed in `/opt/homebrew`.
- [ ] Run `brew bundle check --file=/Library/Application\ Support/DevX/assets/Brewfile` to ensure all baseline packages are correctly installed.
- [ ] Run `mise --version` and check that standard dev tools are functional.
- [ ] Open a new shell instance and check that global profile settings (such as prompt styles and umask `022`) are loaded.
- [ ] Run `sm -version` to confirm that the custom tapped tool installs and executes correctly.
