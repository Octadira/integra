# Integra Technical Architecture

## 1. Executive Summary

**Integra** is a high-performance, native macOS SSHFS manager and AI agent tool provider engineered entirely in **Swift 5.10+ and SwiftUI**, targeting macOS 14.0 (Sonoma) and macOS 15.0+ (Sequoia). It replaces legacy Electron-based remote filesystem clients with a 100% native binary footprint (<4 MB package size, <25 MB RAM consumption), utilizing the kernel-extension-free **FUSE-T** user-space engine, an autonomous **Network Recovery Engine**, durable **Application Support JSON Persistence**, a **Native Model Context Protocol (MCP) Server (`integra-mcp`)**, **Touch ID Sudo Privilege Escalation**, and an integrated **AI Bridge & Developer Toolkit (`MCPConfigService`, `SudoAuthManager`, `AgentInstructionService`, & Port Tunnels)**.

---

## 2. High-Level Architecture Diagram

```
+-----------------------------------------------------------------------+
|                           macOS GUI Layer                             |
|  [IntegraApp (@main)] -> [AppDelegate (Startup AutoMount & Login)]    |
|                       -> [SidebarView] -> [ProfileListView]           |
|                       -> [ActiveMountsView] -> [AIToolsModalView]     |
|                       -> [SettingsView] -> [DependencyDoctorView]     |
+-----------------------------------+-----------------------------------+
                                    | SwiftUI @EnvironmentObject State Flow
+-----------------------------------v-----------------------------------+
|                        Core Services Layer                            |
|  - ProfileStore (Permanent ~/Library/Application Support/Integra/...) |
|  - SSHFSService (Process orchestration, background worker tasks)      |
|  - MCPConfigService (1-Click multi-client IDE configuration engine)   |
|  - SudoAuthManager (Touch ID, biometric, & macOS GUI authorization)  |
|  - NetworkRecoveryService (NWPathMonitor + Sleep/Wake Auto-Healing)   |
|  - SSHTunnelService (Multi-port SSH forwarding & collision checks)    |
|  - AgentInstructionService (Autonomous AGENTS.md & CLAUDE.md engine) |
|  - LaunchAtLoginService (SMAppService.mainApp & LaunchAgent manager)  |
|  - RemoteExecService (OpenSSH ControlMaster & integra-exec CLI bridge)|
|  - DesktopShortcutService (POSIX Symlink lifecycle manager)           |
|  - KeychainService (Apple Security.framework Keychain isolation)      |
|  - TerminalService (macOS LaunchServices & IDE integration)          |
|  - DependencyService (System diagnostics, Homebrew & PKG management)  |
|  - AppSettings (AI Integration Modes & startup preferences)           |
+-----------------------------------+-----------------------------------+
                                    | Task.detached (Worker Threads)
+-----------------------------------v-----------------------------------+
|                     Native MCP Server Target                          |
|  [integra-mcp (JSON-RPC 2.0 stdio server)]                            |
|    -> integra_execute_command (Sub-5ms ControlMaster + Sudo pipe)     |
|    -> integra_list_servers (Structured server mount topology)         |
|    -> integra_get_tunnels (Loopback AI & database endpoints)          |
+-----------------------------------+-----------------------------------+
                                    | System IPC / Sockets
+-----------------------------------v-----------------------------------+
|                        System Engine Layer                            |
|  - FUSE-T (User-space NFSv4 loopback daemon)                          |
|  - FUSE-T SSHFS CLI (/opt/homebrew/bin/sshfs, /usr/local/bin/sshfs)   |
|  - OpenSSH Client & ControlMaster Sockets (/usr/bin/ssh)              |
|  - Apple LocalAuthentication (Touch ID & biometric evaluation)        |
|  - Apple ServiceManagement.framework (SMAppService login item)       |
|  - Apple Network.framework (NWPathMonitor connectivity tracker)       |
|  - Apple Keychain Services (kSecClassGenericPassword)                 |
|  - macOS Filesystem (~/Library/Application Support/Integra/profiles)  |
+-----------------------------------------------------------------------+
```

---

## 3. View Component Architecture (`Sources/IntegraCore/Views/`)

- **`SidebarView.swift`**: Primary navigation hub adhering to macOS HIG SplitView styling. Provides real-time badge counts for active connections and instant health status indicators.
- **`ProfileListView.swift`**: Connection management view featuring live search filtering, authentication segmented tabs, connection cards, Desktop shortcut toggling, and dedicated AI Tools modal sheet triggers.
- **`ActiveMountsView.swift`**: Dedicated live dashboard monitoring currently mounted filesystems with instant "Unmount All" action, mount paths, and quick launchers.
- **`AIToolsModalView.swift`**: Dedicated 3-tab modal managing MCP Auto-Configuration, SSH Port Forwarding rules (Ollama, PostgreSQL, Redis, custom), and the `integra-exec` remote command bridge with animated toast feedback.
- **`ProfileEditView.swift`**: High-stability scrollable modal form with dedicated cards for Server Connection Info, Authentication Mode, Filesystem Paths, **Sudo & AI Privilege Escalation**, Auto-Mount on Startup, and Desktop shortcut options.
- **`SettingsView.swift`**: Interactive configuration panel for default Terminal emulators (Terminal, Ghostty, iTerm2, Warp), Code Editors (VS Code, Cursor, Antigravity 2.0 IDE, Windsurf, Kiro, Codex), AI Integration Modes (`MCP-Only`, `Hybrid`, `Legacy CLI`), 1-Click MCP Auto-Configuration, **Profile Backup & Cross-Platform Sync (1-Click JSON Export & Import)**, and Launch at Login.
- **`DependencyDoctorView.swift`**: One-click system dependency diagnostic and automated installer interface.
- **`MenuBarView.swift`**: macOS status bar menu item (`MenuBarExtra`) enabling 1-click quick mounting directly from the top menu bar.

---

## 4. Core Services & Storage Layer (`Sources/IntegraCore/Services/`)

- **`MCPConfigService.swift`**: Discovers, reads, and merges the Integra MCP server configuration across **15 AI clients** (Claude Desktop, Claude Code CLI, OpenAI Codex, Kiro, Cursor, Antigravity 2.0, VS Code, OpenCode CLI & Desktop, Windsurf, Cline, Roo Code, Continue.dev, Pi.dev, Zed) with atomic non-destructive JSON and TOML merging.
- **`SudoAuthManager.swift`**: Manages Touch ID biometric evaluation (`LAContext`), universal macOS GUI dialog prompts, and 1-minute grace period session caching for administrative command execution.
- **`ProfileStore.swift`**: Manages CRUD operations, serialization, and synchronization for connection profiles. Persists data permanently in `~/Library/Application Support/Integra/profiles.json` with hermetic test-harness storage URL injection (`storageURL`), and provides `exportProfilesToData()`, `exportProfiles(to:)`, and `importProfiles(from:mergeStrategy:)` for 1-click portable JSON backup and cross-compatibility with `Integra-Win` (Windows CLI).
- **`SSHFSService.swift`**: Manages background execution of `sshfs` processes, mount table polling (`/sbin/mount`), active mount detection, and graceful unmounting.
- **`LaunchAtLoginService.swift`**: Controls background launch of Integra at macOS login using Apple's modern `SMAppService.mainApp` API.
- **`AgentInstructionService.swift`**: Manages `AGENTS.md` and `CLAUDE.md` provisioning based on selected `AIIntegrationMode` (`.mcpOnly`, `.hybrid`, `.cliAndMarkdown`).
- **`NetworkRecoveryService.swift`**: Uses Apple's `Network.framework` (`NWPathMonitor`) and macOS sleep/wake observers to automatically recover broken mounts and OpenSSH ControlMaster sockets with exponential backoff.
- **`SSHTunnelService.swift`**: Manages background SSH port forwarding processes, auto-reclaims orphaned SSH processes on port conflicts, performs active keepalive health monitoring, and exposes live endpoint URLs for AI agents.
- **`RemoteExecService.swift`**: Maintains persistent OpenSSH ControlMaster sockets for sub-5ms latency and manages the `~/.local/bin/integra-exec` CLI helper.
- **`UpdateCheckerService.swift`**: Polls the public release API every 24 hours and upon macOS wake from sleep (`NSWorkspace.didWakeNotification`) to verify SemVer versions and provide non-intrusive UI badging.
- **`KeychainService.swift`**: Wraps Apple's `Security.framework` (`SecItemAdd`, `SecItemCopyMatching`, `SecItemDelete`) for SSH passwords, private key passphrases, and sudo credentials.
