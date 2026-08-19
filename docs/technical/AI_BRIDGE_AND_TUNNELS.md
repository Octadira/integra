# AI Agent Bridge, Model Context Protocol (MCP) & SSH Tunneling Architecture

## 1. Executive Summary

Modern AI coding assistants (such as **Google Antigravity 2.0**, **Claude Desktop**, **Claude Code CLI**, **Cursor**, **VS Code**, **OpenCode**, **Windsurf**, and autonomous CLI workers) and developers require three foundational capabilities when interacting with remote infrastructure:
1. **First-Class AI Tool Integration (MCP)**: Connecting the AI agent to structured, discoverable RPC tools (`integra_execute_command`, `integra_list_servers`, `integra_get_tunnels`) without polluting project workspaces.
2. **Secure Administrative Escalation (Sudo & Touch ID)**: Executing privileged commands (`sudo systemctl`, `sudo nft`, `sudo docker`) securely without exposing plain-text passwords or failing on non-interactive TTY password prompts.
3. **Network Port Forwarding**: Accessing remote LLM inference engines (such as **Ollama** on port `11434` or **vLLM** on `8000`), private databases (**PostgreSQL** on `5432`, **Redis** on `6379`), and private APIs via local loopback (`127.0.0.1:<port>`).

**Integra** delivers a comprehensive **AI Tool & Developer Engine**, pairing a native Model Context Protocol (MCP) server target (`integra-mcp`), 1-click auto-configuration across 13 AI clients, persistent OpenSSH ControlMaster sockets, Touch ID biometric sudo authorization, and managed multi-port SSH tunneling.

---

## 2. Native Model Context Protocol (MCP) Server (`integra-mcp`)

### 2.1. Protocol & Transport Architecture
Integra implements the open **Model Context Protocol (MCP)** specification via a dedicated lightweight executable target (`Sources/IntegraMCP/main.swift`):
- **Transport**: JSON-RPC 2.0 over standard input/output (`stdio`).
- **Binary Placement**: Bundled inside `/Applications/Integra.app/Contents/MacOS/integra-mcp` and linked to `~/.local/bin/integra-mcp`.
- **Latency**: Sub-5ms response time for tool discovery and execution.

### 2.2. Exposed MCP Tools

```json
[
  {
    "name": "integra_execute_command",
    "description": "Executes a shell command directly on a remote Linux/SSH server mounted via Integra with sub-5ms latency through persistent OpenSSH ControlMaster sockets.",
    "parameters": {
      "server": { "type": "string", "description": "Server name, host, IP, or short ID" },
      "command": { "type": "string", "description": "The exact shell command to execute" },
      "working_dir": { "type": "string", "description": "Optional remote working directory" },
      "sudo": { "type": "boolean", "description": "Set to true if command requires elevated privileges" }
    }
  },
  {
    "name": "integra_list_servers",
    "description": "Lists all configured and active remote SSHFS server mounts in Integra, including connection status, mount paths, hostnames, and loopback port tunnels."
  },
  {
    "name": "integra_get_tunnels",
    "description": "Lists active SSH loopback port forwarding tunnels (e.g. Ollama LLM endpoint, PostgreSQL, Redis) configured in Integra for remote servers."
  }
]
```

---

## 3. 1-Click Multi-Assistant Auto-Configuration (`MCPConfigService.swift`)

Integra automatically discovers, creates, and non-destructively merges the `integra-mcp` server registration across **15 leading AI clients**:

| AI Assistant / IDE | Primary Configuration Path | Schema Format |
| :--- | :--- | :--- |
| **Claude Desktop** | `~/Library/Application Support/Claude/claude_desktop_config.json` | `mcpServers.integra` |
| **Claude Code CLI** | `~/.claude.json` & `~/.claude/settings.json` | `mcpServers.integra` |
| **OpenAI Codex** | `~/.codex/config.toml` | `[mcp_servers.integra]` (TOML / CLI) |
| **Kiro (kiro.dev)** | `~/.kiro/settings/mcp.json` & `.kiro/mcp.json` | `mcpServers.integra` |
| **Cursor** | `~/.cursor/mcp.json` & globalStorage | `mcpServers.integra` |
| **Google Antigravity 2.0** | `~/.gemini/config/mcp_config.json` & `~/.gemini/antigravity/` | `mcpServers.integra` |
| **VS Code (Copilot & MCP)**| `~/Library/Application Support/Code/User/mcp.json` & storage | `servers.integra` (`type: stdio`) |
| **OpenCode CLI** | `~/.config/opencode/opencode.json` | `mcp.integra` (`type: local`) |
| **OpenCode Desktop** | `~/Library/Application Support/OpenCode/opencode.json` | `mcp.integra` (`type: local`) |
| **Windsurf** | `~/.codeium/windsurf/mcp_config.json` | `mcpServers.integra` |
| **Cline** | `Code/User/globalStorage/saoudrizwan.claude-dev/...` | `mcpServers.integra` |
| **Roo Code** | `Code/User/globalStorage/rooveterinaryinc.roo-cline/...` | `mcpServers.integra` |
| **Continue.dev** | `~/.continue/config.json` | `mcpServers.integra` |
| **Pi.dev / Pi CLI** | `~/.pi/mcp.json` | `mcpServers.integra` |
| **Zed Editor** | `~/.config/zed/settings.json` | `context_servers.integra` |

### Non-Destructive Atomic JSON Merging
Existing custom third-party MCP servers, user preferences, and IDE settings are never overwritten. Integra parses the existing JSON hierarchy, adds or updates the `integra` entry, and writes atomically back to disk.

---

## 4. Native Sudo Privilege Escalation & Touch ID Authorization

```
+-----------------------------------------------------------------------------------+
|                        AI Agent Requests Sudo Command                             |
|          Calls integra_execute_command(server: "xserver", command: "...", sudo: true) |
+-----------------------------------------+-----------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                 Integra MCP Server (SudoAuthManager.swift)                        |
|  1. Checks Sudo Authorization Policy:                                             |
|     - Ask Once per Session (15-min cache): checks active session timestamp        |
|     - Always Ask: prompts every call                                              |
|     - Auto-Approve: reads from Keychain                                           |
|  2. If prompt required:                                                           |
|     - Touch ID Evaluation via LocalAuthentication.framework (LAContext)           |
|     - Universal macOS System Dialog fallback with command details & Cancel/Approve|
|  3. Just-in-Time (JIT) password entry if not stored in Keychain                  |
+-----------------------------------------+-----------------------------------------+
                                          |
                                          v (Authorized)
+-----------------------------------------------------------------------------------+
|                 Secure In-Memory Pipe Execution over SSH Socket                   |
|     printf '%s\n' '<KEYCHAIN_PASS>' | sudo -S -p '' sh -c '<COMMAND>'             |
+-----------------------------------------+-----------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                        Remote Linux Server / Cloud Node                           |
|       Executes command as root, returns output, zero password in chat logs        |
+-----------------------------------------------------------------------------------+
```

---

## 5. AI Integration Modes (`AIIntegrationMode.swift`)

Integra provides three user-selectable modes in Settings:
1. **`MCP-Only` (Default / Recommended)**: Zero project file pollution — `AGENTS.md` and `CLAUDE.md` are not created. Remote workspaces stay 100% clean while modern AI clients use native MCP tools.
2. **`Hybrid`**: Dual-stack governance prioritizing native `integra_execute_command` MCP tools, with `integra-exec` as a fallback.
3. **`Legacy CLI Bridge`**: Injects traditional `integra-exec` directives using delimited blocks (`<!-- INTEGRA_AI_BRIDGE_START -->`).

---

## 6. SSH Port Forwarding & AI Tunnels (`SSHTunnelService.swift`)

- **Multiplexed Port Forwarding**: 1-click forwarding for Ollama (`11434`), PostgreSQL (`5432`), Redis (`6379`), and custom APIs.
- **Local Loopback Port Collision Detection**: Uses POSIX `bind()` system calls before starting tunnels to prevent binding conflicts on `127.0.0.1`.
