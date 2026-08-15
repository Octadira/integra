# Integra Product Roadmap

## Milestone Overview

```
  v0.2.0 (Stabilization)       v0.4.0 (Network Recovery)     v0.6.0 (AI Bridge & AGENTS.md)  v0.8.1 (Settings Persistence)
       [Completed]                  [Completed]                  [Completed]                     [Completed]
  * Native Swift UI            * Network Recovery Engine     * Multi-Port SSH Forwarding    * Visual Remote Directory Browser
  * KEXT-Free FUSE-T           * Exponential Backoff         * Remote CLI (integra-exec)    * Persistent Mount Directory
  * Tailscale & Desktop Pin    * Sleep/Wake Auto-Healing     * AGENTS.md/CLAUDE.md Engine   * Application Support Settings
```

---

## 1. Current Status (v0.7.x)

- ✅ **Native SwiftUI Interface**: 100% native macOS 14+ SwiftUI architecture.
- ✅ **KEXT-Free Engine**: FUSE-T NFS loopback engine with universal `.pkg` installer.
- ✅ **macOS Launch at Login Engine**: Silent background startup via `SMAppService.mainApp` with configurable Settings toggle.
- ✅ **Unconditional Background Auto-Mount (`AppDelegate`)**: Automatic background mounting for connection profiles marked with `autoMount: true` via `NSApplicationDelegate`.
- ✅ **Desktop Symlink Lifecycle & Attribute Resilience**: Low-level attribute inspection preventing broken symlinks on unmounted drives.
- ✅ **Interactive Drag-and-Drop DMG**: Clean 540x360 px Apple-standard installer window.
- ✅ **Network Recovery Engine**: Real-time `NWPathMonitor` connectivity tracking and automatic exponential backoff auto-healing across Sleep/Wake and network changes.
- ✅ **Autonomous AI Agent Directives Engine (`AGENTS.md` & `CLAUDE.md`)**: Non-destructive injection and restoration of imperative AI Bridge rules on mount and unmount.
- ✅ **AI Bridge & SSH Port Forwarding Engine**: Multi-port SSH forwarding for remote AI LLMs (Ollama, vLLM), Databases (Postgres, Redis), and private APIs with local port collision protection.
- ✅ **Remote Command Execution Bridge (`integra-exec`)**: Sub-5ms persistent OpenSSH ControlMaster execution with automatic path translation from mounted workspaces.
- ✅ **Durable Persistence**: File-based Application Support JSON profile storage surviving app reinstalls and updates.
- ✅ **Automated Release Pipeline (`scripts/publish_release.sh`)**: 1-click publishing of releases and binary asset uploads to Forgejo.
- ✅ **Comprehensive Documentation Suite**: Full technical architecture guides and commercial competitive analysis.

---

## 2. Near-Term Milestones (v0.8.0 - v0.8.5)

- **Homebrew Cask Formula (`Casks/integra.rb`)**: Native distribution via custom Forgejo Homebrew Tap (`brew install --cask integra`).
- **Smart Read/Write Caching**: Intelligent local RAM cache for frequently accessed small files (source code syntax trees, Git objects).
- **Enhanced Menu Bar Tray**: Real-time throughput indicators (KB/s read/write) in the macOS Menu Bar.
- **Biometric Touch ID Authentication**: Quick connection unlocking using Touch ID / Secure Enclave.

---

## 3. Mid-Term Milestones (v0.9.0 - v0.9.5)

- **FSKit Native Filesystem Driver**: Integration with Apple's new macOS FSKit user-space filesystem framework as it matures.
- **Encrypted iCloud / Cloud Profile Sync**: Securely sync connection bookmarks and settings across developer Macs using iCloud Keychain.

---

## 4. Long-Term Vision (v1.0.0+)

- **Enterprise MDM Distribution**: Automated provisioning profiles for Jamf, Kandji, and Intune.
- **Multi-Cloud Connector Extensions**: Optional plug-in architecture supporting Amazon S3, Google Cloud Storage, and Cloudflare R2 mounting.
