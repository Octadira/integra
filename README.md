# Integra — Native macOS SSHFS Manager & AI Agent Bridge

[![macOS 14+](https://img.shields.io/badge/macOS-14.0%2B%20(Sonoma%20%7C%20Sequoia)-blue?logo=apple&style=flat-square)](https://www.apple.com/macos/)
[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-orange?logo=swift&style=flat-square)](https://developer.apple.com/swift/)
[![FUSE-T KEXT-Free](https://img.shields.io/badge/FUSE--T-KEXT--Free-green?style=flat-square)](https://www.fuse-t.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](LICENSE)

**Integra** is a fast, native **SSHFS & Remote Filesystem Manager** built with Swift and SwiftUI for macOS (macOS 14+ Sonoma & Sequoia). It seamlessly mounts remote Linux/Unix servers as native macOS drives in Finder, bridges AI coding assistants (Antigravity 2.0, Claude, Cursor, Codex) to remote servers via `integra-exec`, provisions automatic `AGENTS.md` and `CLAUDE.md` governance rules, and manages multi-port SSH tunnels.

---

## ⚡ Instant Installation

### Option 1: One-Line Quick Install (Recommended)
Install Integra and automatically configure macOS security permissions with a single terminal command:

```bash
curl -fsSL https://raw.githubusercontent.com/Octadira/integra/main/scripts/install.sh | bash
```

### Option 2: Homebrew Cask
Install and manage Integra updates directly via Homebrew:

```bash
# Add the tap and install
brew install --cask octadira/integra/integra
```

*(Or if you prefer tapping first: `brew tap octadira/integra && brew install --cask integra`)*

### Option 3: Manual DMG Download
1. Download the latest **`Integra-vX.Y.Z.dmg`** from [GitHub Releases](https://github.com/Octadira/integra/releases).
2. Open the DMG and drag **Integra** into your `/Applications` folder.
3. Launch **Integra**.  
   *(If prompted by Gatekeeper on initial launch, open `System Settings` ➔ `Privacy & Security` ➔ click **Open Anyway**, or right-click `Integra.app` and choose **Open**).*

---

## ✨ Key Features

- **🚀 Zero Kernel Extensions (100% SIP Compliant)**: Powered by FUSE-T (NFS user-space emulation). Runs natively on Apple Silicon (M1/M2/M3/M4) and Intel without modifying System Integrity Protection (SIP).
- **🤖 AI Agent Bridge & Remote Execution (`integra-exec`)**: Sub-5ms OpenSSH ControlMaster bridge allowing AI agents to run commands (`docker`, `npm`, `python`, `git`, `sudo`) directly on the remote Linux host with dynamic path mapping.
- **📜 Autonomous `AGENTS.md` & `CLAUDE.md` Lifecycle Engine**: Automatically injects non-destructive, high-authority AI execution rules in remote workspaces on mount and cleanly restores original files on unmount.
- **🔌 Multi-Port SSH Tunneling**: 1-click port forwarding for remote Ollama AI (`11434`), PostgreSQL (`5432`), Redis (`6379`), and custom web services with loopback collision protection.
- **💻 Zero-Touch Startup & Background Auto-Mount**: Native macOS Launch at Login (`SMAppService.mainApp`). Auto-mounts designated servers silently on system boot.
- **🔄 Autonomous Network Recovery & Auto-Healing**: Uses Apple `Network.framework` (`NWPathMonitor`) to detect sleep/wake events and Wi-Fi transitions, automatically reconnecting broken mounts and re-establishing ControlMaster sockets with exponential backoff.
- **🔒 Enterprise-Grade Security**: Passwords and private key passphrases are stored in **Apple Keychain (`Security.framework`)**. Sockets are strictly isolated in `~/.ssh/integra/sock/` with `0700` POSIX permissions.
- **🖥️ Desktop Shortcuts & Finder Integration**: Automatically pins a clean shortcut on `~/Desktop` upon mount and cleans it up upon unmount.
- **⚡ IDE & Terminal Launchers**: Open remote workspaces directly in **VS Code**, **Cursor**, **Antigravity 2.0 IDE**, or **Codex (OpenAI)**, and launch sessions in **Terminal.app**, **Ghostty**, **iTerm2**, or **Warp**.
- **🌐 Remote Directory Explorer**: Visual remote Linux filesystem navigator built right into the profile editor with parent jumps and hidden dot-file toggling.

---

## 🛠️ Building from Source

### Prerequisites
- macOS 14.0 (Sonoma) or newer
- Xcode 15+ / Command Line Tools (`xcode-select --install`)
- Swift 5.9+

### Build App Bundle & DMG
```bash
# Clone the repository
git clone https://github.com/Octadira/integra.git
cd integra

# Build release binary and package drag-and-drop DMG installer
./scripts/package_app.sh
```

Generated artifacts will be placed in `dist/`:
- `dist/Integra.app`
- `dist/Integra-vX.Y.Z.dmg`
- `dist/Integra-vX.Y.Z.zip`

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
