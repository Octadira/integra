# Integra — Native macOS SSHFS Manager & AI Agent Tool Provider (MCP)

[![macOS 14+](https://img.shields.io/badge/macOS-14.0%2B%20(Sonoma%20%7C%20Sequoia)-blue?logo=apple&style=flat-square)](https://www.apple.com/macos/)
[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-orange?logo=swift&style=flat-square)](https://developer.apple.com/swift/)
[![Model Context Protocol](https://img.shields.io/badge/MCP-2024--11--05%20%7C%202026-purple?logo=anthropic&style=flat-square)](https://modelcontextprotocol.io/)
[![FUSE-T KEXT-Free](https://img.shields.io/badge/FUSE--T-KEXT--Free-green?style=flat-square)](https://www.fuse-t.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](LICENSE)

**Integra** is a blazing-fast, native **SSHFS & Remote Filesystem Manager** built with Swift and SwiftUI for macOS (macOS 14+ Sonoma & Sequoia). It seamlessly mounts remote Linux/Unix servers as native macOS drives in Finder and acts as a first-class **Model Context Protocol (MCP)** tool provider for all major AI coding assistants (**Claude Desktop**, **Claude Code CLI**, **Cursor**, **Google Antigravity 2.0**, **VS Code**, **OpenCode**, **Windsurf**, **Cline**, **Roo Code**, **Pi.dev**, and **Zed**).

---

## ⚡ Instant Installation

### Option 1: Homebrew Cask (Recommended)
Install and manage Integra updates directly via Homebrew:

```bash
# Add the official tap and install
brew install --cask octadira/integra/integra
```

*(Or if you prefer upgrading an existing installation: `brew upgrade --cask octadira/integra/integra`)*

### Option 2: One-Line Quick Install
Install Integra and automatically configure macOS security permissions with a single terminal command:

```bash
curl -fsSL https://raw.githubusercontent.com/Octadira/integra/main/scripts/install.sh | bash
```

### Option 3: Manual DMG Download
1. Download the latest **`Integra-vX.Y.Z.dmg`** from [GitHub Releases](https://github.com/Octadira/integra/releases).
2. Open the DMG and drag **Integra** into your `/Applications` folder.
3. Launch **Integra**.  
   *(If prompted by Gatekeeper on initial launch, open `System Settings` ➔ `Privacy & Security` ➔ click **Open Anyway**, or right-click `Integra.app` and choose **Open**).*

---

## ✨ Key Features

- **🚀 Zero Kernel Extensions (100% SIP Compliant)**: Powered by FUSE-T (NFS user-space emulation). Runs natively on Apple Silicon (M1/M2/M3/M4) and Intel without modifying System Integrity Protection (SIP).
- **🧠 Native Model Context Protocol (MCP) Server (`integra-mcp`)**: Built-in JSON-RPC 2.0 `stdio` server exposing native tools (`integra_execute_command`, `integra_list_servers`, `integra_get_tunnels`) directly to AI clients with sub-5ms OpenSSH ControlMaster latency.
- **⚡ 1-Click AI Assistant Auto-Configuration**: 1-click automatic discovery and registration of the Integra MCP server across **15 AI clients** (Claude Desktop, Claude Code CLI, OpenAI Codex, Kiro, Cursor, Antigravity 2.0, VS Code, OpenCode CLI & Desktop, Windsurf, Cline, Roo Code, Continue.dev, Pi.dev, and Zed).
- **🛡️ Native Sudo Privilege Escalation & Touch ID Authorization**: AI agents can execute administrative commands with elevated privileges without exposing plain-text passwords. Includes Touch ID / native macOS dialog authorization and configurable 15-minute grace period session caching.
- **🎛️ Configurable AI Integration Modes**:
  - **`MCP-Only` (Default)**: Zero project file pollution — `AGENTS.md` and `CLAUDE.md` are not created. Remote workspaces stay 100% pristine.
  - **`Hybrid`**: Dual-stack governance prioritizing native MCP tools with legacy CLI fallbacks.
  - **`Legacy CLI Bridge`**: Injects traditional `integra-exec` directives.
- **🔌 Multi-Port SSH Tunneling**: 1-click port forwarding for remote Ollama AI (`11434`), PostgreSQL (`5432`), Redis (`6379`), and custom web services with loopback collision protection.
- **💻 Zero-Touch Startup & Background Auto-Mount**: Native macOS Launch at Login (`SMAppService.mainApp`). Auto-mounts designated servers silently on system boot.
- **🔄 Autonomous Network Recovery & Auto-Healing**: Uses Apple `Network.framework` (`NWPathMonitor`) to detect sleep/wake events and Wi-Fi transitions, automatically reconnecting broken mounts and re-establishing ControlMaster sockets with exponential backoff.
- **🔒 Enterprise-Grade Credential Protection**: Passwords, private key passphrases, and sudo credentials are encrypted exclusively in **Apple Keychain (`Security.framework`)**. Sockets are strictly isolated in `~/.ssh/integra/sock/` with `0700` POSIX permissions.
- **🖥️ Desktop Shortcuts & Finder Integration**: Automatically pins a clean shortcut on `~/Desktop` upon mount and cleans it up upon unmount.
- **⚡ IDE & Terminal Launchers**: Open remote workspaces directly in **VS Code**, **Cursor**, **Antigravity 2.0 IDE**, **Windsurf**, **Kiro (kiro.dev)**, **Codex (OpenAI)**, **Zed**, or **OpenCode**, and launch sessions in **Terminal.app**, **Ghostty**, **iTerm2**, or **Warp**.
- **🌐 Remote Directory Explorer**: Visual remote Linux filesystem navigator built right into the profile editor with parent jumps and hidden dot-file toggling.
- **🔄 Background Update Checker & Discrete Badging**: Low-overhead 24-hour background release checker listening to sleep/wake cycles with manual trigger in Settings and discrete, non-intrusive status badges.

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

# Build release binary, run 28 automated tests, and package drag-and-drop DMG installer
./scripts/package_app.sh
```

Generated artifacts will be placed in `dist/`:
- `dist/Integra.app`
- `dist/Integra-vX.Y.Z.dmg`
- `dist/Integra-vX.Y.Z.zip`

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
