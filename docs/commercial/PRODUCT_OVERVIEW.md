# Integra — Product Overview & Commercial Guide

## 1. Executive Summary

**Integra** is the modern, lightweight, and kernel-extension-free **SSHFS & Remote Filesystem Manager** built exclusively for macOS (macOS 14+ Sonoma & Sequoia). It bridges the gap between remote infrastructure (cloud virtual machines, bare-metal servers, staging environments, and Tailscale private mesh networks) and the macOS developer workspace.

With Integra, developers and system administrators can mount remote directories as native macOS drives in under one second, browse remote codebases directly in Finder, open remote files seamlessly in **VS Code**, **Cursor**, **Antigravity 2.0 IDE**, **OpenCode**, or modern terminal emulators (**Ghostty**, **iTerm2**, **Warp**), interact with remote environments via a built-in **Model Context Protocol (MCP)** tool server, auto-mount designated servers on boot, execute administrative commands with **Touch ID authorized sudo escalation**, and forward ports for remote AI LLMs (**Ollama**) and databases (**PostgreSQL**, **Redis**).

---

## 2. Core Value Propositions

### 🚀 Zero Kernel Extensions (100% SIP Compliant)
Unlike legacy mounting tools that require compromising macOS System Integrity Protection (SIP) and rebooting into Recovery Mode to authorize risky third-party Kernel Extensions (KEXTs), Integra runs 100% in user space powered by FUSE-T. It is fully certified for Apple Silicon (M1/M2/M3/M4) and Intel Macs, making it completely compliant with strict corporate IT and MDM security policies.

### 🧠 Native Model Context Protocol (MCP) Server (`integra-mcp`)
Integra embeds a high-performance JSON-RPC 2.0 `stdio` MCP server (`integra-mcp`), exposing first-class tool interfaces directly to AI clients:
- `integra_execute_command`: Direct remote command execution with sub-5ms latency over OpenSSH ControlMaster sockets.
- `integra_list_servers`: Real-time structured list of configured and mounted servers, paths, and status.
- `integra_get_tunnels`: Returns active loopback endpoints (e.g. Ollama `:11434`, databases).

### ⚡ 1-Click Multi-Assistant Auto-Configuration
With a single click, Integra discovers and automatically registers its MCP tool server into configuration files across **13 leading AI assistants and IDEs**:
- **Claude Desktop** & **Claude Code CLI**
- **Cursor**
- **Google Antigravity 2.0 (IDE & CLI)**
- **VS Code** (GitHub Copilot Chat & MCP extensions)
- **OpenCode CLI** & **OpenCode Desktop**
- **Windsurf**
- **Cline** & **Roo Code**
- **Continue.dev**
- **Pi.dev / Pi CLI**
- **Zed Editor**

Existing third-party tools and configurations are non-destructively preserved with atomic merging.

### 🛡️ Native Sudo Privilege Escalation & Touch ID Authorization
AI assistants can now execute administrative commands on remote Linux servers without failing on non-interactive TTY password prompts. Sudo passwords are encrypted in **macOS Keychain** and never visible to AI agents. When an AI requests `sudo`, macOS presents an interactive confirmation dialog or **Touch ID** prompt, with a configurable **15-minute grace period cache**.

### 🎛️ Zero-Pollution AI Integration Modes
- **`MCP-Only` (Default)**: Zero project file pollution — `AGENTS.md` and `CLAUDE.md` are not created or injected. Remote workspaces remain 100% pristine.
- **`Hybrid`**: Hierarchical dual-stack governance prioritizing native MCP tools with legacy CLI fallbacks.
- **`Legacy CLI Bridge`**: Injects traditional `integra-exec` directives.

### 💻 Zero-Touch Startup & Background Auto-Mount
Integra integrates native macOS Launch at Login (`SMAppService.mainApp`). When your Mac boots, Integra starts silently in the menu bar and automatically mounts all server profiles flagged with **Auto-Mount on Launch**, ensuring your remote volumes, tunnels, and AI bridges are always ready before you even open your IDE.

### 🔌 Multi-Port SSH Tunneling for AI & Databases
Forward remote services with 1 click: access remote **Ollama AI (11434)**, **PostgreSQL (5432)**, **Redis (6379)**, or custom APIs on `127.0.0.1:<port>` with automatic local port collision protection.

### 🔄 Autonomous Network Recovery & Auto-Healing
Integra integrates a native **Network Recovery Engine** using Apple's `Network.framework` (`NWPathMonitor`) and macOS sleep/wake lifecycle observers. When your laptop wakes from sleep or transitions between Wi-Fi and Hotspot networks, Integra automatically cleans stale mount points and reconnects active SSHFS mounts and control sockets with intelligent **Exponential Backoff** (1s, 2s, 4s, 8s, 16s).

### 💾 Zero-Data-Loss Application Support Persistence
Connection profiles are stored in durable, atomic JSON format inside `~/Library/Application Support/Integra/profiles.json`. Updating the app from a DMG, reinstalling, or moving the `.app` bundle never wipes your saved servers.

### 🔒 Enterprise-Grade Credential Protection
Integra never stores credentials in plaintext configuration files. All SSH passwords, private key passphrases, and sudo credentials are encrypted in hardware-backed storage via **Apple Keychain Services (`Security.framework`)**.

### 🌐 Native Tailscale SSH & Zero-Config Connectivity
Integra is the first macOS SSHFS client designed with native support for **Tailscale SSH**. Connect to internal private server meshes passwordlessly without managing static SSH keys or exposing public IP addresses.

### 🖥️ Smart Desktop Lifecycle
Mounting a remote server can automatically place a clean shortcut directly on the user's macOS Desktop. When unmounted, Integra automatically cleans up the Desktop to prevent broken symlinks.

---

## 3. Target Audience & Personas

1. **Software Engineers & Full-Stack Developers**: Need frictionless access to remote dev containers, staging servers, and production logs directly in Finder, VS Code, Cursor, Zed, or Antigravity IDE.
2. **AI Engineers & Agent Builders**: Require native MCP tool integration, transparent local port forwarding to remote GPU LLM instances (Ollama / vLLM), zero-pollution workspace governance, and Touch ID authorized sudo command execution for agentic workflows.
3. **DevOps & Infrastructure Engineers**: Manage dozens of SSH endpoints, Tailscale nodes, and cloud instances across AWS, GCP, Azure, and DigitalOcean.
4. **Enterprise Mac Fleets**: Require a modern SSHFS solution that passes strict InfoSec and MDM compliance audits without kernel extensions.
