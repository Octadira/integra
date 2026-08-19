# Integra Product Roadmap

## Milestone Overview

```
  v0.2.0 (Stabilization)       v0.4.0 (Network Recovery)     v0.6.0 (AI Bridge & AGENTS.md)  v0.9.0 (1-Click GUI Installer)  v0.10.0–v0.11.0 (MCP & Sudo)
       [Completed]                  [Completed]                  [Completed]                     [Completed]                     [Completed]
  * Native Swift UI            * Network Recovery Engine     * Multi-Port SSH Forwarding    * 1-Click GUI Dependency        * Native MCP Server Target
  * KEXT-Free FUSE-T           * Exponential Backoff         * Remote CLI (integra-exec)    * CryptoKit SHA256 Integrity    * 13 AI Clients Auto-Config
  * Tailscale & Desktop Pin    * Sleep/Wake Auto-Healing     * AGENTS.md/CLAUDE.md Engine   * Zero Terminal Interaction     * Touch ID Sudo Escalation
```

---

## 1. Current Status (v0.11.x)

- ✅ **Native Model Context Protocol (MCP) Server (`integra-mcp`)**: High-performance JSON-RPC 2.0 stdio MCP server exposing `integra_execute_command`, `integra_list_servers`, and `integra_get_tunnels` tools.
- ✅ **1-Click AI Client Auto-Configuration Engine**: Automatic non-destructive registration across **13 AI assistants** (Claude Desktop, Claude Code CLI, Cursor, Antigravity 2.0, VS Code, OpenCode CLI & Desktop, Windsurf, Cline, Roo Code, Continue.dev, Pi.dev, Zed).
- ✅ **Native Sudo Privilege Escalation & Touch ID Authorization**: Secure remote sudo execution with Keychain storage, Touch ID / native macOS dialog prompts, and configurable 15-minute grace period caching.
- ✅ **Configurable AI Integration Modes**: `MCP-Only` (zero file pollution), `Hybrid`, and `Legacy CLI Bridge`.
- ✅ **Official Homebrew Tap Distribution**: 1-click install via `brew install --cask octadira/integra/integra`.
- ✅ **1-Click In-App Dependency Doctor**: Automated download, SHA-256 verification, and installation of FUSE-T.
- ✅ **Native SwiftUI Interface**: 100% native macOS 14+ SwiftUI architecture.
- ✅ **KEXT-Free Engine**: FUSE-T NFS loopback engine with universal `.pkg` installer.
- ✅ **macOS Launch at Login Engine**: Silent background startup via `SMAppService.mainApp` with configurable Settings toggle.
- ✅ **Unconditional Background Auto-Mount (`AppDelegate`)**: Automatic background mounting for connection profiles marked with `autoMount: true` via `NSApplicationDelegate`.
- ✅ **Desktop Symlink Lifecycle & Attribute Resilience**: Low-level attribute inspection preventing broken symlinks on unmounted drives.
- ✅ **Network Recovery Engine**: Real-time `NWPathMonitor` connectivity tracking and automatic exponential backoff auto-healing across Sleep/Wake and network changes.
- ✅ **AI Bridge & SSH Port Forwarding Engine**: Multi-port SSH forwarding for remote AI LLMs (Ollama, vLLM), Databases (Postgres, Redis), and private APIs with local port collision protection.
- ✅ **Durable Persistence**: File-based Application Support JSON profile storage surviving app reinstalls and updates.
- ✅ **Automated Test Suite**: 28 comprehensive automated unit and regression tests running on every build.
- ✅ **Automated Dual-Release Pipeline**: Automated releases and binary asset publishing to Forgejo and GitHub.

---

## 2. Near-Term Milestones (v0.12.0 - v0.13.0)

- **Smart Read/Write Caching**: Intelligent local RAM cache for frequently accessed small files (source code syntax trees, Git objects).
- **Enhanced Menu Bar Tray**: Real-time throughput indicators (KB/s read/write) in the macOS Menu Bar.
- **SSH Certificate Authority (CA) Authentication**: Support for enterprise short-lived SSH certificates (Vault, Smallstep, Teleport).

---

## 3. Mid-Term Milestones (v0.14.0 - v0.15.0)

- **FSKit Native Filesystem Driver**: Integration with Apple's new macOS FSKit user-space filesystem framework as it matures.
- **Encrypted iCloud Profile Sync**: Securely sync connection bookmarks and non-sensitive settings across developer Macs using iCloud Keychain.

---

## 4. Long-Term Vision (v1.0.0+)

- **Enterprise MDM Distribution**: Automated provisioning profiles for Jamf, Kandji, and Intune.
- **Multi-Cloud Connector Extensions**: Optional plug-in architecture supporting Amazon S3, Google Cloud Storage, and Cloudflare R2 mounting.
