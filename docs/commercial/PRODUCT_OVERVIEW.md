# Integra — Product Overview & Commercial Guide

## 1. Executive Summary

**Integra** is the modern, lightweight, and kernel-extension-free **SSHFS & Remote Filesystem Manager** built exclusively for macOS. It bridges the gap between remote infrastructure (cloud virtual machines, bare-metal servers, staging environments, and Tailscale private mesh networks) and the macOS Finder experience.

With Integra, developers and system administrators can mount remote directories as native macOS drives in under one second, browse remote codebases directly in Finder, open remote files seamlessly in **VS Code**, **Cursor**, **Antigravity 2.0 IDE**, or modern terminal emulators (**Ghostty**, **iTerm2**, **Warp**), execute remote commands instantly via **`integra-exec`**, automatically provision authoritative AI agent guidelines (**`AGENTS.md`** and **`CLAUDE.md`**), auto-mount designated servers on boot, and forward ports for remote AI LLMs (**Ollama**) and databases (**PostgreSQL**, **Redis**).

---

## 2. Core Value Propositions

### 🚀 Zero Kernel Extensions (100% SIP Compliant)
Unlike legacy mounting tools that require compromising macOS System Integrity Protection (SIP) and rebooting into Recovery Mode to authorize risky third-party Kernel Extensions (KEXTs), Integra runs 100% in user space powered by FUSE-T. It is fully certified for Apple Silicon (M1/M2/M3/M4) and Intel Macs, making it completely compliant with strict corporate IT and MDM security policies.

### 💻 Zero-Touch Startup & Background Auto-Mount
Integra integrates native macOS Launch at Login (`SMAppService.mainApp`). When your Mac boots, Integra starts silently in the menu bar and automatically mounts all server profiles flagged with **Auto-Mount on Launch**, ensuring your remote volumes, tunnels, and AI bridges are always ready before you even open your IDE.

### 🤖 Autonomous AI Agent Governance (`AGENTS.md` & `CLAUDE.md`)
When working with AI coding assistants (Antigravity 2.0, Claude, Cursor, Cline), Integra automatically provisions clear, authoritative execution rules in the mounted workspace upon connection. It uses non-destructive delimited blocks to ensure that any pre-existing project rules are 100% preserved and cleanly restores the workspace upon unmount.

### ⚡ AI Bridge & Remote Command Execution (`integra-exec`)
Integra provides a sub-5ms persistent OpenSSH ControlMaster bridge. AI agents and developers can execute remote Linux commands (`docker ps`, `npm test`, `python script.py`, `sudo systemctl restart`) directly from inside any mounted directory with automatic path mapping and full interactive PTY support.

### 🔌 Multi-Port SSH Tunneling for AI & Databases
Forward remote services with 1 click: access remote **Ollama AI (11434)**, **PostgreSQL (5432)**, **Redis (6379)**, or custom APIs on `127.0.0.1:<port>` with automatic local port collision protection.

### 🔄 Autonomous Network Recovery & Auto-Healing
Integra integrates a native **Network Recovery Engine** using Apple's `Network.framework` (`NWPathMonitor`) and macOS sleep/wake lifecycle observers. When your laptop wakes from sleep or transitions between Wi-Fi and Hotspot networks, Integra automatically cleans stale mount points and reconnects active SSHFS mounts and control sockets with intelligent **Exponential Backoff** (1s, 2s, 4s, 8s, 16s).

### 💾 Zero-Data-Loss Application Support Persistence
Connection profiles are stored in durable, atomic JSON format inside `~/Library/Application Support/Integra/profiles.json`. Updating the app from a DMG, reinstalling, or moving the `.app` bundle never wipes your saved servers.

### 🔒 Enterprise-Grade Credential Protection
Integra never stores credentials in plaintext configuration files. All SSH passwords and private key passphrases are stored in encrypted hardware-backed storage via **Apple Keychain Services (`Security.framework`)**.

### 🌐 Native Tailscale SSH & Zero-Config Connectivity
Integra is the first macOS SSHFS client designed with native support for **Tailscale SSH**. Connect to internal private server meshes passwordlessly without managing static SSH keys or exposing public IP addresses.

### 🖥️ Smart Desktop Lifecycle
Mounting a remote server can automatically place a clean shortcut directly on the user's macOS Desktop. When unmounted, Integra automatically cleans up the Desktop to prevent broken symlinks.

---

## 3. Target Audience & Personas

1. **Software Engineers & Full-Stack Developers**: Need frictionless access to remote dev containers, staging servers, and production logs directly in Finder, VS Code, Cursor, or Antigravity IDE.
2. **AI Engineers & Agent Builders**: Require transparent local port forwarding to remote GPU LLM instances (Ollama / vLLM), autonomous workspace instructions (`AGENTS.md`), and seamless remote command execution (`integra-exec`) for agentic workflows.
3. **DevOps & Infrastructure Engineers**: Manage dozens of SSH endpoints, Tailscale nodes, and cloud instances across AWS, GCP, Azure, and DigitalOcean.
4. **Enterprise Mac Fleets**: Require a modern SSHFS solution that passes strict InfoSec and MDM compliance audits without kernel extensions.
