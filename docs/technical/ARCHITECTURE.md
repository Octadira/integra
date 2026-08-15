# Integra Technical Architecture

## 1. Executive Summary

**Integra** is a high-performance, native macOS SSHFS manager engineered entirely in **Swift 5.10+ and SwiftUI**, targeting macOS 14.0 (Sonoma) and macOS 15.0+ (Sequoia). It replaces legacy Electron-based remote filesystem clients with a 100% native binary footprint (<3 MB package size, <25 MB RAM consumption), utilizing the kernel-extension-free **FUSE-T** user-space engine, an autonomous **Network Recovery Engine**, durable **Application Support JSON Persistence**, native **Launch at Login & Startup Automount Engine (`AppDelegate`)**, and an integrated **AI Bridge & Developer Toolkit (`integra-exec`, `AgentInstructionService`, & Port Tunnels)**.

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
|  - LaunchAtLoginService (SMAppService.mainApp & LaunchAgent manager)  |
|  - NetworkRecoveryService (NWPathMonitor + Sleep/Wake Auto-Healing)   |
|  - SSHTunnelService (Multi-port SSH forwarding & collision checks)    |
|  - RemoteExecService (OpenSSH ControlMaster & integra-exec CLI bridge)|
|  - AgentInstructionService (Autonomous AGENTS.md & CLAUDE.md engine) |
|  - DependencyService (System diagnostics, Homebrew & PKG management)  |
|  - DesktopShortcutService (POSIX Symlink lifecycle manager)           |
|  - KeychainService (Apple Security.framework Keychain isolation)      |
|  - TerminalService (macOS LaunchServices & IDE integration)          |
|  - AppSettings (User application & startup preferences)               |
+-----------------------------------+-----------------------------------+
                                    | Task.detached (Worker Threads)
+-----------------------------------v-----------------------------------+
|                        System Engine Layer                            |
|  - FUSE-T (User-space NFSv4 loopback daemon)                          |
|  - FUSE-T SSHFS CLI (/opt/homebrew/bin/sshfs, /usr/local/bin/sshfs)   |
|  - OpenSSH Client & ControlMaster Sockets (/usr/bin/ssh)              |
|  - Apple ServiceManagement.framework (SMAppService login item)       |
|  - Apple Network.framework (NWPathMonitor connectivity tracker)       |
|  - Apple Keychain Services (kSecClassGenericPassword)                 |
|  - macOS Filesystem (~/Library/Application Support/Integra/profiles)  |
+-----------------------------------------------------------------------+
```

---

## 3. View Component Architecture (`Sources/Integra/Views/`)

- **`SidebarView.swift`**: Primary navigation hub adhering to macOS HIG SplitView styling. Provides real-time badge counts for active connections and instant health status indicators.
- **`ProfileListView.swift`**: Connection management view featuring live search filtering, authentication segmented tabs, connection cards, Desktop shortcut toggling, and dedicated AI Tools modal sheet triggers.
- **`ActiveMountsView.swift`**: Dedicated live dashboard monitoring currently mounted filesystems with instant "Unmount All" action, mount paths, and quick launchers.
- **`AIToolsModalView.swift`**: Dedicated, spacious 2-tab modal managing SSH Port Forwarding rules (Ollama, PostgreSQL, Redis, custom), real-time terminal test console, and the persistent `integra-exec` remote command bridge.
- **`ProfileEditView.swift`**: High-stability scrollable modal form with dedicated cards for Server Connection Info, Authentication Mode, Filesystem Paths, Auto-Mount on Startup, and Desktop shortcut options.
- **`SettingsView.swift`**: Visual interactive tile selector for default Terminal emulators (Terminal, Ghostty, iTerm2, Warp), Code Editors (VS Code, Cursor, Antigravity 2.0 IDE), System & Startup Preferences (Launch at Login), Network Recovery Engine controls, and Developer & AI Agent Tools activation.
- **`DependencyDoctorView.swift`**: One-click system dependency diagnostic and automated installer interface.
- **`MenuBarView.swift`**: macOS status bar menu item (`MenuBarExtra`) enabling 1-click quick mounting directly from the top menu bar.

---

## 4. Core Services & Storage Layer (`Sources/Integra/Services/`)

- **`ProfileStore.swift`**: Manages CRUD operations for connection profiles. Persists data permanently in `~/Library/Application Support/Integra/profiles.json`, guaranteeing cross-version survival.
- **`SSHFSService.swift`**: Manages background execution of `sshfs` processes, mount table polling (`/sbin/mount`), active mount detection, and graceful unmounting.
- **`LaunchAtLoginService.swift`**: Controls background launch of Integra at macOS login using Apple's modern `SMAppService.mainApp` API (with automated fallback to `~/Library/LaunchAgents/com.integra.app.plist`).
- **`AgentInstructionService.swift`**: Automatically provisions, injects, and cleans `AGENTS.md` and `CLAUDE.md` files upon mount and unmount with non-destructive delimited blocks.
- **`NetworkRecoveryService.swift`**: Uses Apple's `Network.framework` (`NWPathMonitor`) and macOS sleep/wake observers to automatically recover broken mounts and OpenSSH ControlMaster sockets with exponential backoff.
- **`SSHTunnelService.swift`**: Manages background SSH port forwarding processes, detects local loopback port collisions, and exposes live endpoint URLs for AI agents.
- **`RemoteExecService.swift`**: Maintains persistent OpenSSH ControlMaster sockets for sub-5ms latency and manages the `~/.local/bin/integra-exec` CLI helper with intelligent PTY allocation (`-t` vs `-T`) and dynamic case-insensitive path mapping.
- **`DependencyService.swift`**: Verifies Homebrew, FUSE-T framework, and `sshfs` binary availability.
- **`DesktopShortcutService.swift`**: Creates and removes POSIX symlinks (`~/Desktop/<ServerName>`) with low-level attribute inspection to reliably detect and clean broken symlinks.
- **`KeychainService.swift`**: Wraps Apple's `Security.framework` (`SecItemAdd`, `SecItemCopyMatching`, `SecItemDelete`) using bundle identifier `com.integra.app`.
- **`TerminalService.swift`**: Interacts with `NSWorkspace` and `/usr/bin/open` to launch terminal sessions and code editors targeting mounted paths.
