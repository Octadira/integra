# AI Bridge & SSH Port Forwarding Architecture

## 1. Executive Summary

Modern AI coding agents (such as **Antigravity 2.0**, **Cursor**, **Claude Code**, or autonomous CLI workers) and developers frequently require two foundational capabilities when interacting with remote infrastructure:
1. **Direct Terminal Command Execution**: Executing build tools (`npm`, `cargo`, `go`), containers (`docker`, `podman`), interactive administrative tasks (`sudo`, `htop`, `nano`), and service daemons (`systemctl`, `launchctl`) directly in the remote environment without local CPU emulation.
2. **Network Port Forwarding**: Accessing remote LLM inference engines (such as **Ollama** on port `11434` or **vLLM** on `8000`), private databases (**PostgreSQL** on `5432`, **Redis** on `6379`), and private APIs via local loopback (`127.0.0.1:<port>`).

**Integra v0.6.0** delivers a complete **AI Bridge & Developer Engine**, pairing persistent OpenSSH ControlMaster sockets (`integra-exec`), managed multi-port SSH tunneling, and an autonomous **Non-Destructive AI Instruction Provisioning Engine (`AgentInstructionService.swift`)** for `AGENTS.md` and `CLAUDE.md`.

---

## 2. Remote Command Execution Bridge (`integra-exec`)

### 2.1. Persistent OpenSSH ControlMaster Socket
To eliminate the latency of establishing new TCP/TLS handshakes on every command, `RemoteExecService.swift` maintains a multiplexed OpenSSH control master:

$$\text{Socket Path: } \texttt{/tmp/integra\_ctl\_<sanitized\_server\_name>.sock}$$

```
+-----------------------------------------------------------------------------------+
|                           AI Agent / Developer Terminal                           |
|              Runs: integra-exec docker ps (or integra-exec sudo ...)              |
+-----------------------------------------+-----------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|               integra-exec CLI Helper (~/.local/bin/integra-exec)                 |
|  1. Interactive PTY Detection: [ -t 0 ] && [ -t 1 ] -> uses -t (or -T for pipe)   |
|  2. Case-Insensitive Mount Match: matches ~/Mounts, ~/mounts, /Volumes            |
|  3. Root & Subfolder Path Mapping: transforms relative path to /$INNER_PATH       |
|  4. Socket Health Probe: instantly checks control socket liveness                 |
|  5. Dispatches: ssh $TTY_OPTS -S <sock> placeholder "cd /target/dir && <cmd>"     |
+-----------------------------------------+-----------------------------------------+
                                          |
                                          v (Sub-5ms Zero-Handshake Stream)
+-----------------------------------------------------------------------------------+
|                        Remote Linux Server / Cloud Node                           |
|             Executes command, handles PTY / sudo, & returns stdout/stderr         |
+-----------------------------------------------------------------------------------+
```

### 2.2. Zero-Configuration Case-Insensitive Path Translation
- **Case-Insensitive Mount Detection**: Matches both `Mounts` and `mounts` and resolves subpaths regardless of casing.
- **Root Mount Path Resolution**: When connecting to root-mounted filesystems (`/`), subpaths are cleanly formatted with leading absolute slashes (e.g. `/$INNER_PATH` ➔ `/etc/netplan` or `/mnt/HardExtern/forgejo`) rather than defaulting to `$HOME`.

### 2.3. Dual-Mode Terminal & PTY Allocation (`-t` vs `-T`)
- **Interactive Terminal Sessions**: When invoked from an interactive terminal (with an active TTY on STDIN/STDOUT), `integra-exec` automatically allocates a pseudo-terminal (`-t`), enabling password entry for `sudo`, interactive text editors (`nano`, `vi`), and terminal monitors (`htop`).
- **Automated AI Agent Tool Pipelines**: When invoked programmatically by AI agents or background scripts through non-interactive pipes, it enforces `-T` to prevent ANSI escape sequence pollution in tool outputs.

---

## 3. Autonomous AI Agent Instruction Lifecycle (`AgentInstructionService.swift`)

AI coding agents (Antigravity 2.0, Claude, Cursor, Cline) require unambiguous, authoritative instructions to understand that they are operating in a remote filesystem and must route shell commands through `integra-exec`.

### 3.1. Automatic Mount Provisioning
When a server profile is mounted and *Developer & AI Agent Tools* is enabled in Settings, `SSHFSService` invokes `AgentInstructionService.shared.injectInstructions(for: profile)`:
1. Targets `AGENTS.md` and `CLAUDE.md` in the root of the mounted directory.
2. If the files do not exist, Integra creates them with imperative directives.
3. If the files already exist with custom user rules, Integra injects its block between delimiters:
   ```markdown
   <!-- INTEGRA_AI_BRIDGE_START -->
   # ⚠️ MANDATORY RULE: REMOTE EXECUTION ENVIRONMENT (INTEGRA AI BRIDGE)
   ...
   <!-- INTEGRA_AI_BRIDGE_END -->
   ```
   **All user-defined project instructions and coding guidelines remain 100% preserved.**

### 3.2. Clean Non-Destructive Unmount Restoration
Upon unmounting:
1. If `AGENTS.md` or `CLAUDE.md` was created solely by Integra, the file is cleanly deleted.
2. If the file contained pre-existing user rules, only the delimited Integra block is removed, cleanly restoring the original file.

---

## 4. SSH Port Forwarding & AI Tunnels (`SSHTunnelService.swift`)

### 4.1. Multiplexed Port Forwarding
Integra allows configuring multiple port forwarding rules per server profile:
- **Ollama AI LLM Engine**: Local `11434` ➔ Remote `127.0.0.1:11434`
- **PostgreSQL Database**: Local `5432` ➔ Remote `127.0.0.1:5432`
- **Redis Cache**: Local `6379` ➔ Remote `127.0.0.1:6379`
- **Custom Web / API Services**: Local `8080` ➔ Remote `8080`

### 4.2. Local Loopback Port Collision Detection
Before initiating a tunnel, `SSHTunnelService` inspects `127.0.0.1:<port>` using POSIX `bind()` system calls. If a local port collision occurs, Integra aborts gracefully and warns the user.

---

## 5. UI/UX Architecture

- **Settings Master Toggle (`enableDeveloperAITools`)**: Kept disabled by default for standard users. When enabled, unlocks developer capabilities.
- **Dedicated Sheet (`AIToolsModalView.swift`)**:
  - Two dedicated tabs: *SSH Port Tunnels* and *Command Bridge (integra-exec)*.
  - Quick presets, active endpoint copy buttons (`http://127.0.0.1:<port>`), real-time terminal test console, and 1-click instruction copy to clipboard.
