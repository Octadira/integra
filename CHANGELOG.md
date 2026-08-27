# Changelog

All notable changes to the Integra macOS SSHFS Manager project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.16.0] - 2026-08-27

### Added
- **1-Click Profile Backup & Cross-Platform Synchronization (`SettingsView.swift`, `ProfileStore.swift`)**:
  - Added dedicated **"Profile Backup & Cross-Platform Sync"** section in `SettingsView` featuring native macOS **Export Profiles (JSON)** and **Import Profiles (JSON)** actions.
  - Implemented `exportProfilesToData()`, `exportProfiles(to:)`, and `importProfiles(from:mergeStrategy:)` in `ProfileStore` supporting seamless backup, migration across macOS workstations, and cross-compatibility with `Integra-Win` (Windows CLI).
  - Added non-destructive merging of imported JSON profiles with collision detection and feedback banners.
- **Automated Test Suite (`Tests/IntegraTestRunner/main.swift`)**:
  - Added `testProfileStoreExportAndImportJSON` covering profile serialization, round-trip export, duplicate detection, and import merge strategies (43/43 tests passing).

---

## [0.15.4] - 2026-08-26

### Fixed
- **Auto-Healing SSH Port Tunnels & Automatic Mount Lifecycle (`SSHTunnelService.swift`, `NetworkRecoveryService.swift`, `SSHFSService.swift`)**:
  - Implemented asynchronous `terminationHandler` on SSH tunnel processes, eliminating zombie states in the UI and automatically triggering exponential backoff auto-recovery when a tunnel drops.
  - Integrated SSH Port Forwarding Tunnels directly into `NetworkRecoveryService`, ensuring that after system sleep/wake or network reconnection, database (DBeaver/Postgres/MySQL) and AI model tunnels (Ollama/vLLM) are automatically restored without manual restart.
  - Added automatic tunnel start on profile mount in `SSHFSService.mount`, ensuring enabled forwarding rules become immediately active upon connection or login auto-mount.
  - Ensured `isTunnelRunning` performs a strict live process check (`process.isRunning`) to guarantee 100% UI accuracy.
- **Automated Test Suite (`Tests/IntegraTestRunner/main.swift`)**:
  - Added `testTunnelLifecycleAndAutoRecoveryTracking` verifying intended tunnel tracking and user-initiated vs automated lifecycle boundaries (42/42 tests passing).

---

## [0.15.3] - 2026-08-24

### Fixed
- **Seamless Auto-Approve Sudo & Cross-Process Keychain Retrieval (`KeychainService.swift`, `SudoAuthManager.swift`)**:
  - Implemented `/usr/bin/security` CLI fallback in `KeychainService` guaranteeing 100% reliable password retrieval across security context boundaries between `Integra.app` (GUI) and `integra-mcp` (sub-process AI helper).
  - Enforced non-interactive execution for the `.autoApprove` policy, preventing modal dialog interruptions and supporting passwordless (`NOPASSWD`) remote sudo out of the box.
  - Allowed empty password authorization in interactive fallback prompts for servers configured with passwordless sudo.
- **Automated Test Suite (`Tests/IntegraTestRunner/main.swift`)**:
  - Added `testAutoApprovePolicyNonInteractiveSudo` covering Keychain password injection and passwordless sudo fallback (41/41 tests passing).

---

## [0.15.2] - 2026-08-21

### Fixed
- **Pi.dev Multi-Directory Global MCP Configuration Discovery (`MCPConfigService.swift`)**:
  - Configured `~/.pi/agent/mcp.json` as the primary user-global configuration path for Pi.dev (`pi-mcp-adapter`), accompanied by `~/.config/mcp/mcp.json` and `~/.agents/mcp.json`.
  - Resolves the issue where Pi.dev only detected Integra MCP when launched directly inside `$HOME` and lost discovery when navigated into subdirectories (e.g. `~/Working`).
- **Automated Test Suite (`Tests/IntegraTestRunner/main.swift`)**:
  - Added `testPiDevMCPConfigurationPaths` verifying global and secondary discovery paths (40/40 tests passing).

---

## [0.15.1] - 2026-08-20

### Fixed
- **Antigravity 2.0 IDE Launcher Resolution (`TerminalService.swift`)**:
  - Corrected bundle resolution when launching mounted workspaces in **Antigravity 2.0 IDE**, prioritizing the workspace IDE bundle (`com.google.antigravity-ide` / `Antigravity IDE.app`) over the standalone chat application (`Antigravity.app`).
  - Added CLI dispatch fallback to `~/.local/bin/agy` and `/usr/local/bin/agy`.

### Added
- **Expanded Modern AI & Code Editor Support (`AppSettings.swift`, `TerminalService.swift`, `SettingsView.swift`)**:
  - Added **Zed** and **OpenCode** directly to the preferred code editor launcher list.
- **Automated Test Suite (`Tests/IntegraTestRunner/main.swift`)**:
  - Expanded `testCodeEditorAppEnumIncludesWindsurfAndKiro` to cover Zed, OpenCode, and Antigravity IDE (39/39 tests passing).

---

## [0.15.0] - 2026-08-20

### Added
- **Asynchronous Background Execution in MCP Server (`IntegraMCP/main.swift`)**:
  - Added support for the `background: true` parameter in `integra_execute_command` for long-running operations (`apt-get upgrade`, `docker build`, `npm install`, large compilations).
  - Automatically dispatches remote tasks with `nohup` in a detached shell, redirects both stdout/stderr to `/tmp/integra_job_<timestamp>_<id>.log`, and returns the remote `BG_PID` and log file path immediately to prevent client-side MCP timeouts.
- **Configurable Process Execution Timeouts (`IntegraMCP/main.swift`)**:
  - Added optional `timeout_seconds` parameter (default 90s, configurable up to 600s) for synchronous command execution with structured timeout diagnostics and background suggestions.
- **Automated Test Suite (`Tests/IntegraTestRunner/main.swift`)**:
  - Added `testBackgroundJobCommandFormatting` (39/39 tests passing).

---

## [0.14.5] - 2026-08-20

### Added
- **Automatic SSH Private Key Permission Sanitizer (`SSHProfile.swift`, `SSHFSService.swift`, `RemoteExecService.swift`, `SSHTunnelService.swift`, `RemoteBrowserService.swift`)**:
  - Automatically verifies and sanitizes SSH private key permissions (`.pem`, `.id_rsa`, `.id_ed25519`) to `0600` (`-rw-------`) before initiating SSHFS mount, OpenSSH ControlMaster sockets, or port tunnels.
  - Prevents cryptic OpenSSH rejection errors (`WARNING: UNPROTECTED PRIVATE KEY FILE! Permissions 0644 are too open`).

### Fixed
- **Root User Administrative Sudo Authorization Flow (`SudoAuthManager.swift`, `IntegraMCP/main.swift`)**:
  - Optimized command execution for SSH profiles connected under the `root` account (`effectiveUser == "root"`).
  - Bypassed redundant sudo password prompts for `root` (UID 0), enforcing swift biometric/dialog approval without demanding password input in a dialog.
  - Stripped unnecessary `sudo` wrapper execution on remote Linux hosts when connected as `root`.
- **Automated Test Suite (`Tests/IntegraTestRunner/main.swift`)**:
  - Added `testIdentityFilePermissionSanitization` and `testRootUserSudoAuthAutoGrantsWithoutPassword` (38/38 tests passing).

---

## [0.14.4] - 2026-08-20

### Fixed
- **Password-Authenticated Server ControlMaster Socket & MCP Execution (`RemoteExecService.swift`, `SSHTunnelService.swift`, `main.swift`)**:
  - Implemented secure `SSH_ASKPASS` credential injection for password-authenticated SSH profiles when establishing persistent OpenSSH ControlMaster multiplexing sockets (`~/.ssh/integra/sock/`).
  - Added `SSH_ASKPASS` support to `SSHTunnelService` for port forwarding on password-only servers.
  - Updated `integra-mcp` (`integra_execute_command`) to automatically handle password authentication fallback via `SSH_ASKPASS` when sockets need initialization.
- **Automated Test Suite (`Tests/IntegraTestRunner/main.swift`)**:
  - Added `testPasswordAuthAskPassScriptGeneration` (36/36 tests passing).

---

## [0.14.3] - 2026-08-20

### Fixed
- **Single-Pass Keychain Sudo Read Optimization (`SudoAuthManager.swift`)**:
  - Eliminated redundant multiple reads of the sudo credentials from macOS Keychain during a single command execution, passing the in-memory credential directly to the authorization handler.
  - Resolves duplicate macOS system Keychain permission prompts when executing administrative remote commands.
- **Biometric Authorization Flow Alignment (`SudoAuthManager.swift`)**:
  - Refactored `LAContext` biometric evaluation handler to pass pre-resolved credentials upon successful Touch ID authentication without re-querying the Keychain.

---

## [0.14.2] - 2026-08-20

### Fixed
- **OpenCode CLI & Desktop MCP Schema Conformance (`MCPConfigService.swift`)**:
  - Corrected OpenCode MCP configuration schema format to adhere to the official specification (`"mcp": { "integra": { "type": "local", "command": ["<bin>"], "enabled": true } }`).
  - Added automatic removal of legacy/invalid `"enabled": true` and `"servers": {}` sub-keys during auto-configuration and uninstallation.
  - Successfully verified live connection with `opencode mcp list` (`✓ integra connected`).
- **Automated Test Suite (`Tests/IntegraTestRunner/main.swift`)**:
  - Updated `testOpenCodeConfigFormatWithoutTopLevelMCPServers` to validate `"type": "local"` and `command` array structures (35/35 tests passing).

---

## [0.14.1] - 2026-08-19

### Fixed
- **Sidebar Width & Navigation Truncation Fix (`IntegraApp.swift` & `SidebarView.swift`)**:
  - Imposed strict `.navigationSplitViewColumnWidth(min: 210, ideal: 230, max: 300)` and `.frame(minWidth: 210)` on the Sidebar to permanently prevent macOS from collapsing sidebar navigation items into truncated labels (*"Connec... 1"*, *"Active... 1"*, *"Dependen..."*).
- **Sidebar Footer & Update Badge Layout Optimization (`SidebarView.swift`)**:
  - Refactored footer layout to place the update notification badge inline next to the version label (`Integra vX.Y.Z [✨ vX.Y.Z]`) with `.fixedSize(horizontal: true, vertical: true)`, preventing vertical letter squishing or horizontal collisions with connection counts.

---

## [0.14.0] - 2026-08-19

### Added
- **Windsurf IDE Workspace Launcher (`TerminalService.swift` & `AppSettings.swift`)**:
  - Added native support for Codeium's **Windsurf** IDE in default Code Editor preferences, quick launcher buttons, and contextual menus.
  - Automatically searches candidate CLI binaries (`/Applications/Windsurf.app/Contents/Resources/app/bin/windsurf`, `/usr/local/bin/windsurf`, `/opt/homebrew/bin/windsurf`) to open remote mounted filesystems.
- **Kiro (kiro.dev) Agentic IDE Integration (`TerminalService.swift`, `AppSettings.swift`, `MCPConfigService.swift`)**:
  - Added dedicated launcher support for AWS **Kiro** spec-driven AI IDE (`dev.kiro.desktop`).
  - Added 1-Click MCP Auto-Configuration for Kiro (`~/.kiro/settings/mcp.json` and `~/.kiro/mcp.json`).
  - Expanded supported AI clients to **15 assistants** in 1-Click Auto-Configuration and 6 Code Editors in default preferences.
- **Automated Test Suite Expansion (`Tests/IntegraTestRunner/main.swift`)**:
  - Added `testKiroMCPConfigurationPathAndFormat` and `testCodeEditorAppEnumIncludesWindsurfAndKiro` (35/35 tests passing).

---

## [0.13.0] - 2026-08-19

### Added
- **Native Background Update Checker (`UpdateCheckerService.swift`)**:
  - Implemented ultra-lightweight background release checker polling the official GitHub / Forgejo release API once every 24 hours.
  - Automatically handles macOS sleep/wake transitions via `NSWorkspace.didWakeNotification` without consuming extra battery or background CPU cycles.
  - Accurate SemVer parsing and comparison logic (`isVersion(_:newerThan:)`).
- **Dedicated Software Updates Card in Settings (`SettingsView.swift`)**:
  - Displays current version status, last checked timestamp, and an on-demand *„Check for Updates”* manual trigger.
- **Discrete Non-Intrusive Update Notifications (`SidebarView.swift` & `MenuBarView.swift`)**:
  - Non-disruptive informational badges in the Sidebar status footer and Menu Bar menu informing users when a new version is available without modal popups or automatic installs.
- **Automated Test Suite Expansion (`Tests/IntegraTestRunner/main.swift`)**:
  - Added `UpdateCheckerTests` covering SemVer comparison, older version filtering, and version string sanitization (33/33 tests passing).

---

## [0.12.0] - 2026-08-19

### Added
- **OpenAI Codex MCP Auto-Configuration (`MCPConfigService.swift`)**:
  - Added native Model Context Protocol (MCP) auto-configuration for OpenAI Codex (`~/.codex/config.toml`).
  - Supports CLI registration via `codex mcp add/remove` as well as direct non-destructive TOML parsing and insertion under `[mcp_servers.integra]`.
  - Expanded supported AI clients to 14 assistants in 1-Click Auto-Configuration.
- **Dedicated Codex IDE Workspace Launcher (`TerminalService.swift`)**:
  - Fixed issue where opening a mounted server in Codex opened the general ChatGPT conversational window.
  - Integra now leverages the embedded Codex CLI (`/Applications/ChatGPT.app/Contents/Resources/codex app <path>`) to open remote workspaces directly into the Codex IDE environment.
- **Automated Test Suite Expansion (`Tests/IntegraTestRunner/main.swift`)**:
  - Added `testCodexTOMLConfigFormat` (30/30 tests passing).

---

## [0.11.1] - 2026-08-19

### Fixed
- **OpenCode Strict JSON Schema Compliance (`MCPConfigService.swift`)**:
  - Fixed OpenCode (`opencode.json`) configuration parsing error (*`Unrecognized key: mcpServers`*).
  - OpenCode CLI and Desktop now generate and manage strictly the nested `mcp.servers` dictionary, automatically stripping any unrecognized top-level `mcpServers` keys.
- **Added Automated Regression Test (`Tests/IntegraTestRunner/main.swift`)**:
  - Added `testOpenCodeConfigFormatWithoutTopLevelMCPServers` (29/29 tests passing).

---

## [0.11.0] - 2026-08-19

### Added
- **Native Sudo Privilege Escalation for AI Assistants (`SudoAuthManager.swift` & `KeychainService.swift`)**:
  - Implemented secure remote `sudo` command execution over OpenSSH ControlMaster sockets with automated password injection via in-memory `sudo -S` pipes.
  - Sudo passwords are encrypted exclusively in Apple's native macOS Keychain (`Security.framework`) and are never exposed to AI models or chat logs.
- **Interactive Touch ID & Native macOS Sudo Authorization**:
  - Added Touch ID and native macOS GUI dialog authorization prompts when AI agents request `sudo` privilege escalation.
  - Added configurable Sudo Authorization Policies on server profiles:
    - *Ask Once per Session* (15-minute grace period cache - default).
    - *Always Ask* (Touch ID or prompt required on every single sudo call).
    - *Auto-Approve from Keychain* (Autonomous background execution).
  - Just-in-Time (JIT) password prompt allowing users to enter and save sudo credentials on demand during an AI session.
- **Profile Sudo Configuration UI (`ProfileEditView.swift`)**:
  - Added dedicated *Sudo & AI Privilege Escalation* section in server connection editor with Keychain synchronization and SSH password inheritance toggle.
- **Expanded Automated Test Suite (`Tests/IntegraTestRunner/main.swift`)**:
  - Added 3 new test suites for Sudo session caching, Keychain CRUD operations, and fallback resolution (28/28 tests passing).

---

## [0.10.3] - 2026-08-19

### Added
- **Interactive Auto-Configuration Feedback & Animations (`AIToolsModalView.swift` & `SettingsView.swift`)**:
  - Added smooth animated progress state (`ProgressView`) on the "Auto-Configure All" button during client registration.
  - Added animated success confirmation banner detailing exactly which AI assistants were configured with 1-click dismissal.
- **VS Code Official MCP Dual-Structure Support (`MCPConfigService.swift`)**:
  - Implemented dual registration for VS Code (GitHub Copilot Chat & Extensions) across both `~/Library/Application Support/Code/User/mcp.json` and `globalStorage/mcp.json`, populating both `"servers"` (with `"type": "stdio"`) and `"mcpServers"`.

---

## [0.10.2] - 2026-08-19

### Added
- **Claude Code CLI & OpenCode (CLI & Desktop) Support (`MCPConfigService.swift`)**:
  - Added native auto-configuration for Anthropic's **Claude Code CLI** (`~/.claude.json` & `~/.claude/settings.json`).
  - Added native auto-configuration for **OpenCode CLI** (`~/.config/opencode/opencode.json`) and **OpenCode Desktop** (`~/Library/Application Support/OpenCode/opencode.json`), supporting both `mcp.servers` and root `mcpServers` schemas.

---

## [0.10.1] - 2026-08-19

### Fixed
- **Google Antigravity Global Configuration Sync (`MCPConfigService.swift`)**:
  - Updated Antigravity MCP auto-configuration to write directly to the official global configuration path (`~/.gemini/config/mcp_config.json`) alongside `~/.gemini/antigravity/mcp_config.json`, ensuring immediate recognition across all Antigravity CLI (`agy`) and IDE sessions.

---

## [0.10.0] - 2026-08-19

### Added
- **Native Model Context Protocol (MCP) Server (`integra-mcp`)**:
  - Implemented high-performance JSON-RPC 2.0 `stdio` MCP server binary exposing `integra_execute_command`, `integra_list_servers`, and `integra_get_tunnels` tools directly to AI clients.
  - Sub-5ms remote command execution through persistent OpenSSH ControlMaster sockets with full support for path mapping, environment isolation, and privilege escalation.
- **1-Click IDE Auto-Configuration (`MCPConfigService.swift`)**:
  - Integrated 1-click automatic discovery and registration of the Integra MCP server across all major AI coding assistants and IDEs: Claude Desktop, Cursor, Google Antigravity 2.0 (IDE & CLI), VS Code, Windsurf, Cline, Roo Code, Continue.dev, Pi.dev, and Zed.
  - Non-destructively merges server entries into client config files while preserving existing third-party servers.
- **AI Integration Modes (`AIIntegrationMode.swift` & `SettingsView.swift`)**:
  - Added configurable integration modes: `MCP-Only` (default: zero project file pollution), `Legacy CLI Bridge` (markdown injection), and `Hybrid` (hierarchical dual-stack priority).
- **Expanded Automated Test Suite (`Tests/IntegraTestRunner/main.swift`)**:
  - Added 6 new automated tests for MCP JSON-RPC protocol compliance, multi-client configuration parsing, and zero-pollution lifecycle verification (25/25 tests passing).

---

## [0.9.0] - 2026-08-17

### Added
- **Automated 1-Click GUI Dependency Installer (`DependencyService.swift` & `DependencyDoctorView.swift`)**:
  - Implemented 1-click in-app installer for FUSE-T and SSHFS, completely eliminating the need to open or interact with Terminal.app.
  - Automatically downloads official packages, validates cryptographic SHA256 checksums (`CryptoKit`), and executes the installation directly via macOS native Administrator Authorization (Touch ID or Password).
  - Integrated real-time animated progress indicators and live status updates directly within the Dependency Doctor interface.

---

## [0.8.6] - 2026-08-16

### Fixed
- **OpenSSH ControlMaster Indefinite Persistence & Health Watchdog (`RemoteExecService.swift`)**:
  - Configured `ControlPersist=yes` replacing the previous `2h` idle timeout, ensuring control sockets remain active indefinitely while server mounts are connected.
  - Added OS-level TCP Keep-Alive (`TCPKeepAlive=yes`) with robust heartbeat parameters (`ServerAliveInterval=20`, `ServerAliveCountMax=6`) to survive transient network lag without dropping sockets.
  - Implemented an automated background socket watchdog running every 25 seconds that detects any dropped sockets on mounted servers and auto-heals them transparently.

---

## [0.8.5] - 2026-08-16

### Fixed
- **Automatic OpenSSH ControlMaster Socket Recovery on Sleep/Wake (`NetworkRecoveryService.swift` & `RemoteExecService.swift`)**:
  - Resolved an issue where OpenSSH ControlMaster sockets remained disconnected after macOS woke from sleep while the filesystem mount reconnected.
  - Sockets are now unconditionally cleaned of dead TCP handles and re-established upon system wake and after every network recovery cycle.
  - Unified `AppSettings.shared` singleton in `SSHFSService.mount()` ensuring developer and AI tool bridges always initialize automatically on reconnect.

---

## [0.8.4] - 2026-08-16

### Fixed
- **Unix Domain Socket Path Length Optimization (`SSHProfile.swift` & `RemoteExecService.swift`)**:
  - Compacted OpenSSH ControlMaster socket filenames to `i_<shortId>.sock` and directory to `~/.ssh/integra/sock/`.
  - Resolved `unix_listener: path too long for Unix domain socket` error by keeping the total socket path with OpenSSH temporary suffix (`.Elabp9...`) under 75 bytes (well within macOS Darwin's 104-byte `sun_path` limit).

---

## [0.8.3] - 2026-08-16

### Added
- **OpenAI / ChatGPT Codex IDE Support (`AppSettings.swift` & `TerminalService.swift`)**:
  - Added **Codex (OpenAI)** as a selectable preferred Code Editor & IDE option in Settings and connection action menus.
  - Automatically launches mounted workspaces in Codex / ChatGPT macOS App (`Codex.app`, `OpenAI Codex.app`, `ChatGPT.app`) or via the `codex` command-line tool.

---

## [0.8.2] - 2026-08-15

### Security & Fixed
- **Unique Socket Naming & Exact Directory Mapping (`SSHProfile.swift` & `RemoteExecService.swift`) [M-3 Fix]**:
  - ControlMaster sockets are now uniquely keyed by profile UUID (`integra_<uuid>.sock`), eliminating socket collision and overwrite between similarly named profiles.
  - Active mount paths are registered via exact mapping files (`integra_<uuid>.mount`); `integra-exec` now performs exact directory and subfolder matching rather than substring globbing.
- **AskPass Hardening in Remote Directory Browser (`RemoteBrowserService.swift`) [M-2 Fix]**:
  - Temporary askpass scripts now use quoted here-doc delimiters (`cat << 'INTEGRA_ASKPASS_EOF'`) in `/bin/sh` to prevent shell parameter/backtick expansion.
  - Askpass scripts are stored in a private `~/.ssh/integra/askpass/` directory with strict `0700` POSIX permissions and cleaned up immediately in `defer`.
- **Main Thread Offloading (`SSHFSService.swift` & `RemoteExecService.swift`) [L-7 Fix]**:
  - Offloaded `/sbin/mount` polling and `stopControlSocket` process executions to `Task.detached`, ensuring zero `@MainActor` thread blocks.
- **Backslash Sanitization in Terminal Launcher (`TerminalService.swift`) [L-4 Fix]**:
  - Escaped backslash characters (`\`) in profile names before embedding in `.command` script headers, preventing shell syntax breakage.
- **Log File Rotation (`IntegraLogger.swift`) [L-3 Fix]**:
  - Added automatic log file rotation to `integra.log.1` when `~/Library/Logs/Integra/integra.log` exceeds 5 MB.

---

## [0.8.1] - 2026-08-15

### Fixed
- **Persistent Default Mount Directory & Application Settings (`AppSettings.swift`)**:
  - Bound the *Default Local Mount Base Path* setting in `SettingsView.swift` to `AppSettings.shared.defaultMountsFolder` and backed it with atomic JSON storage in `~/Library/Application Support/Integra/settings.json` (and `UserDefaults`).
  - Saved mount base folder now persists permanently across DMG reinstallations, application updates, and app relaunches.
  - Dynamically linked `SSHProfile.defaultMountPath` and `ProfileEditView` placeholders to `AppSettings.currentMountsFolder`, ensuring all remote connections automatically respect the custom default mount directory.

---

## [0.8.0] - 2026-08-15

### Added
- **Remote Server Directory Browser & Visual Path Picker (`RemoteDirectoryPickerView.swift` & `RemoteBrowserService.swift`)**:
  - Interactive directory explorer added to the Connection Profile editor (`ProfileEditView.swift`), allowing users to visually browse remote Linux/SSH directories starting from root (`/`) or home (`~`) and pick mount paths with 1-click.
  - **Manual Input Preserved**: The `Remote Path on Server` text field remains 100% editable for manual entry.
  - **High-Performance Lazy Loading**: Queries subdirectories on-demand per folder without recursively scanning the server.
  - **Quick Jump Toolbar**: 1-click shortcuts for `[ 🌐 Root / ]`, `[ 🏠 Home ~ ]`, `[ ⬆ Parent Directory ]`, and `[ 🔄 Refresh ]`.
  - **Real-Time Directory Search & Filter**: Fast client-side folder filtering and hidden dot-folder toggle.
  - **Full Multi-Auth Compatibility**: Works seamlessly with Tailscale SSH, SSH Private Keys, and Passwords.

---

## [0.7.6] - 2026-08-15

### Fixed
- **Bash Script String Escaping in CLI Generator (`RemoteExecService.swift`)**:
  - Replaced interpolated multiline string with Swift raw multiline literal (`#""" ... """#`) and pure variable-based parameter expansion (`${REMOTE_SUBPATH//$SQ/$REPL}`).
  - Resolved fatal bash syntax error in `~/.local/bin/integra-exec` caused by Swift quote interpretation, ensuring zero-error command execution for AI agents (`agy`, Claude, Cursor).

---

## [0.7.5] - 2026-08-15

### Fixed
- **Compound Command Execution in `integra-exec` (`RemoteExecService.swift`)**:
  - Fixed an issue where command chaining (`&&`, `;`), pipes (`|`), redirections (`>`), and quoted compound strings were incorrectly grouped into a single literal argument token.
  - Commands passed to `integra-exec` now pass naturally to the remote login shell, while preserving strict single-quote sanitization for `REMOTE_SUBPATH` (`cd '$ESCAPED_SUBPATH'`).

---

## [0.7.4] - 2026-08-15

### Security
- **Command Injection Hardening (`RemoteExecService.swift`) [C-1 Fix]**: Rebuilt remote command argument execution in `integra-exec` with strict single-quote shell escaping (`${arg//\'/\'\\\'\'}`), preventing arbitrary remote command execution from maliciously crafted mounted directory names.
- **Strict Execution Target Isolation (`RemoteExecService.swift`) [C-2 Fix]**: Completely removed the insecure "first active socket" fallback. `integra-exec` now strictly requires execution within an active mounted directory (~/Mounts/<Server>), preventing accidental command execution on incorrect/production servers.
- **Private Socket Isolation (`SSHProfile.swift` & `RemoteExecService.swift`) [C-3 Fix]**: Moved OpenSSH ControlMaster sockets from world-writable `/tmp` to private per-user `~/.ssh/integra/sockets/` created with strict `0700` permissions.
- **Full TLS Verification (`publish_release.py`) [H-2 Fix]**: Removed `ssl.CERT_NONE` and enforced standard TLS certificate verification in the release publishing pipeline.
- **Cryptographic Package Verification (`DependencyService.swift`) [H-3 Fix]**: Pinned official SHA256 checksums for FUSE-T and SSHFS packages, verifying package integrity before executing `sudo /usr/sbin/installer`.
- **Hardened Code Signing & Notarization Pipeline (`package_app.sh`) [H-1 Fix]**: Added Developer ID signing with Hardened Runtime (`--options runtime`) and Apple `notarytool` submission support, falling back cleanly to hardened ad-hoc signing for local development.
- **Input Sanitization & Injection Prevention**:
  - Validated host and user arguments against leading dashes in `SSHFSService.swift` to prevent argument injection [M-2 Fix].
  - Escaped profile and host parameters in `.command` files in `TerminalService.swift` [M-3 Fix].
  - Sanitized profile metadata interpolated into `AGENTS.md` and `CLAUDE.md` in `AgentInstructionService.swift` [C-1 secondary vector].
  - Removed legacy `UserDefaults` profile mirroring in `ProfileStore.swift` [M-4 Fix].

---

## [0.7.3] - 2026-08-14

### Fixed
- **Shared Service Singletons & State Synchronization**: Unified `ProfileStore.shared`, `SSHFSService.shared`, and `AppSettings.shared` across `AppDelegate`, SwiftUI ViewModels, and background recovery tasks, eliminating multiple disjoint instances and ensuring synchronous state updates.
- **Dual-Layer Launch-at-Login (`LaunchAtLoginService.swift`)**: Dual-registered macOS `SMAppService.mainApp` and user-level `~/Library/LaunchAgents/com.integra.app.plist`, guaranteeing background startup on macOS boot regardless of codesign status.
- **Progressive Boot Readiness Intervals**: Enhanced `AppDelegate` auto-mount retry schedule with progressive delays (1.5s, 3.0s, 5.0s, 8.0s, 12.0s, 18.0s) to guarantee successful connections even when Tailscale MagicDNS or Wi-Fi takes up to 20 seconds to establish.
- **Integrated Diagnostic File Logger (`IntegraLogger.swift`)**: Added persistent file logging to `~/Library/Logs/Integra/integra.log` for real-time inspection of boot and background events.

---

## [0.7.2] - 2026-08-14

### Fixed
- **Recovery Engine Self-Cancellation on Remount**: Fixed a bug where `SSHFSService.unmount` unconditionally cancelled active recovery tasks and cleared intended mounts during internal recovery cycles. Added `isUserInitiated` flag so that internal unmounts preserve retry state.
- **Tailscale & Network Boot Readiness Retries (`AppDelegate`)**: Added graceful retry loops upon system boot in `AppDelegate` to accommodate Tailscale and Wi-Fi initialization delays, ensuring profiles marked with `autoMount: true` mount reliably on login.
- **Desktop Shortcut Refresh on Mount**: Guaranteed that `DesktopShortcutService.createShortcut` executes and refreshes the symlink whenever an auto-mount succeeds.

---

## [0.7.1] - 2026-08-14

### Fixed
- **Unconditional Background Startup Execution (`AppDelegate`)**: Attached `@NSApplicationDelegateAdaptor(AppDelegate.self)` to `IntegraApp` so that auto-mounting executes immediately and unconditionally upon macOS login, even when the application starts silently in the menu bar without an open UI window.
- **Broken Desktop Symlink Resolution (`DesktopShortcutService.swift`)**: Replaced `FileManager.default.fileExists` with `attributesOfItem(atPath:)` to properly detect and clean broken Desktop shortcuts, resolving the macOS Finder error *"The operation can’t be completed because the original item for 'ServerName' can’t be found"*.

---

## [0.7.0] - 2026-08-14

### Added
- **macOS Launch at Login Engine (`LaunchAtLoginService.swift`)**:
  - Automatically starts Integra in the background when logging into macOS (enabled by default), ensuring remote filesystems, port tunnels, and AI bridges are immediately available on startup.
  - Added dedicated toggle in `SettingsView.swift` under **System & Startup Preferences** to enable or disable launch at login on demand.
  - Native `SMAppService.mainApp` integration with seamless LaunchAgent fallback for universal macOS compatibility.

### Fixed
- **Resolved Auto-Mount on Application Startup (`IntegraApp.swift`)**:
  - Added asynchronous startup task that automatically mounts all connection profiles marked with `autoMount: true` upon launch.

---

## [0.6.0] - 2026-08-14

### Added
- **Automatic `AGENTS.md` & `CLAUDE.md` Lifecycle Engine (`AgentInstructionService.swift`)**:
  - Automatically provisions authoritative, high-priority AI agent instruction files (`AGENTS.md` and `CLAUDE.md`) inside mounted server workspaces when *Developer & AI Agent Tools* is enabled.
  - **High-Authority AI Directives**: Imperative, unambiguous system instructions that force AI coding assistants (Antigravity 2.0, Claude, Cursor, Cline) to use `integra-exec <command>` for all remote shell, container (`docker`), build (`npm`, `cargo`), test, and administrative tasks.
  - **Non-Destructive Delimited Injection**: If `AGENTS.md` or `CLAUDE.md` already exist in the remote project, Integra injects the AI Bridge block between `<!-- INTEGRA_AI_BRIDGE_START -->` and `<!-- INTEGRA_AI_BRIDGE_END -->` tags, preserving all pre-existing project rules.
  - **Clean Non-Destructive Unmount Restoration**: Upon unmounting, Integra cleanly removes injected instructions. If the file was created solely by Integra, it is deleted; if it had pre-existing user rules, only the Integra block is removed, cleanly restoring the user's original file.
  - **Automated OpenSSH ControlMaster Initialization**: Automatically starts the persistent control master socket on mount when AI Tools is enabled, making `integra-exec` ready immediately.

---

## [0.5.3] - 2026-08-14

### Fixed
- **Direct UI Thread Dispatch & Non-Blocking Socket Verification**: Eliminated synchronous subprocess execution on `@MainActor` by removing blocking `isSocketActive` process checks and wrapping command execution directly in `@MainActor` state updates.
- **Dedicated Terminal Console Output**: Added a permanent terminal-style output console box in the AI Tools modal with real-time status updates ("Executing...", "Output", "Clear").

---

## [0.5.2] - 2026-08-14

### Fixed
- **Resolved Spinner Freeze in Test Remote Command Runner**: Fixed an issue where running test commands in the AI Tools modal could cause the UI button to hang on the progress spinner indefinitely.
- **Pipe Deadlock & STDIN Closure**: Closed `standardInput` immediately on command processes and decoupled pipe reading to prevent buffer deadlocks.
- **Execution Safety Timeout**: Added a strict 15-second execution safety timeout and `BatchMode=yes` to prevent OpenSSH from hanging indefinitely on interactive prompts when a control socket is not yet initialized.

---

## [0.5.1] - 2026-08-14

### Fixed
- **Persistent Profile Storage on Reinstall**: Replaced volatile `UserDefaults` storage with permanent Application Support JSON persistence (`~/Library/Application Support/Integra/profiles.json`), ensuring saved connections are preserved across new DMG installations, app updates, and bundle relocations.
- **Case-Insensitive Path Resolution in `integra-exec`**: Resolved case-sensitivity mismatches (`Mounts` vs `mounts`) by introducing case-insensitive mount matching and dynamic subfolder detection.
- **Absolute Root Directory Path Resolution**: Fixed subfolder path translation for root-mounted filesystems (`/`), ensuring commands correctly execute in absolute paths (`/$INNER_PATH` e.g. `/etc/netplan` or `/mnt/HardExtern/forgejo`) instead of falling back to `$HOME`.
- **Interactive Pseudo-Terminal (PTY) Allocation**: Added intelligent TTY detection in `integra-exec` (`-t` for interactive terminal sessions with `sudo`, `nano`, `htop` password prompts; `-T` for clean automated AI agent pipes).
- **OpenSSH ControlMaster Auto-Recovery**: Integrated persistent control socket health checking and automatic reconnection on macOS Sleep/Wake and Wi-Fi transitions in `NetworkRecoveryService`.

---

## [0.5.0] - 2026-08-14

### Added
- **AI Bridge & SSH Port Forwarding Engine (`SSHTunnelService.swift`)**:
  - Multi-port SSH tunneling supporting local port forwarding for remote AI LLMs (Ollama on `11434`), Databases (PostgreSQL on `5432`, Redis on `6379`), and custom web services.
  - Automatic local loopback port collision verification before starting tunnels.
  - One-click copyable local endpoints (`http://127.0.0.1:<port>`) for AI agents and developer workflows.
- **Remote Command Execution Bridge (`RemoteExecService.swift` & `integra-exec`)**:
  - Persistent OpenSSH ControlMaster socket management enabling sub-5 millisecond remote command execution without repeated SSH handshakes.
  - Dynamic local-to-remote path mapping: when `integra-exec <cmd>` is executed inside any mounted subfolder (`~/Mounts/<Server>/subfolder`), it automatically translates and executes `cd /remote/path/subfolder && <cmd>` on the remote Linux host.
  - Installed standalone CLI helper `~/.local/bin/integra-exec`.
- **Dedicated AI Tools Modal (`AIToolsModalView.swift`)**:
  - Clean 2-tab modal sheet keeping primary connection cards clutter-free.
  - Interactive in-app test console runner and 1-click copyable instructions for AI agents (Antigravity 2.0, Cursor, CLI).
- **Settings Developer & AI Tools Toggle**:
  - Added "Developer & AI Agent Tools" toggle in `SettingsView.swift` (`enableDeveloperAITools`) to keep the interface simple for standard users while empowering power users on demand.

---

## [0.4.0] - 2026-08-14

### Added
- **Network Recovery & Auto-Healing Engine**: Integrated native `Network.framework` (`NWPathMonitor`) and macOS sleep/wake lifecycle observers (`NSWorkspace.didWakeNotification`).
- **Automatic Exponential Backoff Reconnection**: Automatically detects broken connections after laptop sleep, signal drops, or Wi-Fi network switches and reconnects active SSHFS mounts with intelligent backoff intervals (1s, 2s, 4s, 8s, 16s).
- **Settings Toggle & Status Indicator**: Added real-time network monitoring pill and configuration toggle in Settings.

---

## [0.3.3] - 2026-08-14

### Changed
- **Comprehensive Documentation Suite Update**: Refreshed all technical documentation (`ARCHITECTURE.md`, `BUILD_AND_RELEASE.md`) and commercial documentation (`PRODUCT_OVERVIEW.md`, `ROADMAP.md`) to reflect the latest UI components, Drag-and-Drop DMG packaging pipeline, and milestone progress.

---

## [0.3.2] - 2026-08-14

### Fixed
- **Clean Minimalist DMG Layout**: Completely redesigned DMG installer window with 1:1 pixel-perfect 540x360 dimensions, precise icon coordinate alignment ({140, 175} and {400, 175}), removed obstructive solid shapes and duplicate labels, providing a clean Apple-standard drag-and-drop installation experience.

---

## [0.3.1] - 2026-08-14

### Added
- **Interactive Drag-and-Drop DMG Installer**: Generated an installer DMG window featuring dark slate branding and standard drag-to-Applications installation workflow.

---

## [0.3.0] - 2026-08-14

### Added
- **Complete Technical Documentation Suite**: Added comprehensive engineering documentation in `docs/technical/` covering:
  - System Architecture & Component Flow (`ARCHITECTURE.md`)
  - User-Space FUSE-T NFS Engine & Mount Parameters (`FUSE_T_ENGINE.md`)
  - Apple Keychain Services & Security Model (`KEYCHAIN_SECURITY.md`)
  - Desktop Symlink Lifecycle Architecture (`DESKTOP_LIFECYCLE.md`)
  - Build, Packaging & Semantic Versioning Guide (`BUILD_AND_RELEASE.md`)
- **Complete Commercial Documentation & Competitive Analysis**: Added product and market documentation in `docs/commercial/` covering:
  - Product Overview & Value Propositions (`PRODUCT_OVERVIEW.md`)
  - Comprehensive Competitive Analysis vs. Mountain Duck, CloudMounter, Transmit 5, ForkLift 4, and Legacy Macfusion (`COMPETITIVE_ANALYSIS.md`)
  - Pricing, Open Core Licensing & Distribution Strategy (`PRICING_AND_LICENSING.md`)
  - Product Development Roadmap (`ROADMAP.md`)

---

## [0.2.0] - 2026-08-14

### Added
- **Native SwiftUI Architecture**: 100% native macOS application built with Swift and SwiftUI (macOS 14+), replacing Electron.
- **Universal KEXT-Free FUSE-T Engine**: Integrated user-space NFS FUSE-T engine with automated direct `.pkg` installation via `/usr/sbin/installer`.
- **Multi-Authentication Support**: Support for Tailscale SSH (passwordless / SSH Agent), SSH Private Keys (with passphrase), and Password authentication saved securely in macOS Keychain (`Security.framework`).
- **Dedicated Active Mounts Dashboard**: Separate live view for active filesystem mounts with real-time status pills, path links, and one-click bulk "Unmount All".
- **Per-Server Desktop Shortcut**: Optional automatic creation of `~/Desktop/<ServerName>` shortcut upon mount with automatic cleanup on unmount.
- **Configurable Terminals & IDEs**: Preference options to launch SSH sessions in **Terminal.app**, **Ghostty**, **iTerm2**, or **Warp**, and open folders in **VS Code**, **Cursor**, or **Antigravity 2.0 IDE**.
- **Search & Authentication Filters**: Fast real-time connection search and segmented filtering (`All`, `Tailscale`, `SSH Key`, `Password`).
- **Agent Governance (`AGENTS.md`)**: Comprehensive documentation and versioning rules for AI agents.

### Fixed
- **Profile Edit Form Visibility**: Resolved form layout clipping in the Add/Edit connection profile sheet, ensuring all input fields and controls render reliably.
- **Startup Diagnostics Badge**: Fixed false-positive dependency warning badge on launch by running synchronous initial inspection.
- **Non-blocking UI Thread**: Process execution runs on background worker threads (`Task.detached`), preventing UI beachballs.
