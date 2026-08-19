import Foundation

@MainActor
public class AgentInstructionService {
    public static let shared = AgentInstructionService()
    
    public let startDelimiter = "<!-- INTEGRA_AI_BRIDGE_START -->"
    public let endDelimiter = "<!-- INTEGRA_AI_BRIDGE_END -->"
    
    private func sanitizeForMarkdown(_ input: String) -> String {
        return input
            .replacingOccurrences(of: "<", with: "")
            .replacingOccurrences(of: ">", with: "")
            .replacingOccurrences(of: "`", with: "'")
            .replacingOccurrences(of: "\n", with: " ")
    }
    
    public func generateInstructions(for profile: SSHProfile) -> String {
        let safeName = sanitizeForMarkdown(profile.name.isEmpty ? profile.host : profile.name)
        let safeHost = sanitizeForMarkdown(profile.host)
        let safeUser = sanitizeForMarkdown(profile.effectiveUser)
        let mode = AppSettings.shared.aiIntegrationMode
        
        var tunnelInfo = ""
        let enabledTunnels = profile.portTunnels.filter { $0.isEnabled }
        if !enabledTunnels.isEmpty {
            tunnelInfo = "\n### 🌐 Active Local Port Forwarding (Loopback Endpoints):\n"
            for t in enabledTunnels {
                let safeTunnelName = sanitizeForMarkdown(t.name)
                tunnelInfo += "- **\(safeTunnelName)**: `http://127.0.0.1:\(t.localPort)` ➔ Remote `:\(t.remotePort)`\n"
            }
        }
        
        if mode == .hybrid {
            return """
            \(startDelimiter)
            # ⚠️ REMOTE EXECUTION ENVIRONMENT (INTEGRA DUAL-STACK)
            
            > [!IMPORTANT]
            > **YOU ARE WORKING IN A REMOTE-MOUNTED SSHFS WORKSPACE** on **\(safeName)** (\(safeUser)@\(safeHost)).
            > Standard local terminal commands execute on macOS by default, NOT on the remote server.
            
            ---
            
            ### 🚨 EXECUTION RULES (HIERARCHICAL PRIORITY):
            1. 🥇 **PREFERRED (If Integra MCP Server is connected)**:
               - Use the native `integra_execute_command` MCP Tool directly for all shell, build, test, and container operations.
            2. 🥈 **FALLBACK (If MCP is not active in your IDE)**:
               - Prefix local terminal commands with `integra-exec <command>`:
                 ```bash
                 integra-exec docker compose up -d
                 integra-exec npm test
                 ```
            \(tunnelInfo)
            \(endDelimiter)
            """
        }
        
        return """
        \(startDelimiter)
        # ⚠️ MANDATORY RULE: REMOTE EXECUTION ENVIRONMENT (INTEGRA AI BRIDGE)
        
        > [!CRITICAL]
        > **YOU ARE OPERATING INSIDE A REMOTE-MOUNTED FILESYSTEM** via Integra SSHFS.
        > - **Filesystem modifications** occur directly on the remote host **\(safeName)** (\(safeUser)@\(safeHost)).
        > - **Standard local terminal commands execute on the local macOS host by default, NOT on the remote server!**
        
        ---
        
        ### 🚨 ABSOLUTE MANDATORY EXECUTION RULE:
        To execute ANY terminal command, build tool, container, script, test, service, or shell operation on the **\(safeName)** server, you **MUST ALWAYS prefix the command with `integra-exec`**:
        
        ```bash
        # Correct Examples (Executes directly on remote host):
        integra-exec docker ps
        integra-exec docker compose up -d
        integra-exec npm test
        integra-exec npm run build
        integra-exec python3 main.py
        integra-exec sudo systemctl restart nginx
        integra-exec git status
        ```
        
        - **NEVER** run `ssh user@host "..."` manually — `integra-exec` uses a persistent, zero-latency OpenSSH ControlMaster socket.
        - **NEVER** execute build tools, packages, or services without the `integra-exec` prefix inside this workspace.
        - Directory paths are automatically mapped: running `integra-exec <cmd>` from any subfolder executes in the matching remote directory automatically.
        \(tunnelInfo)
        \(endDelimiter)
        """
    }
    
    public func injectInstructions(for profile: SSHProfile) {
        let mountPath = (profile.defaultMountPath as NSString).standardizingPath
        guard FileManager.default.fileExists(atPath: mountPath) else { return }
        
        // Mode 1: MCP-Only -> Zero file pollution. If previously injected, clean it up!
        if AppSettings.shared.aiIntegrationMode == .mcpOnly {
            removeInstructions(for: profile)
            return
        }
        
        let instructions = generateInstructions(for: profile)
        let filenames = ["AGENTS.md", "CLAUDE.md"]
        
        for filename in filenames {
            let filePath = (mountPath as NSString).appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: filePath) {
                if let existingContent = try? String(contentsOfFile: filePath, encoding: .utf8) {
                    if let startRange = existingContent.range(of: startDelimiter),
                       let endRange = existingContent.range(of: endDelimiter) {
                        // Replace existing block
                        let before = String(existingContent[..<startRange.lowerBound])
                        let after = String(existingContent[endRange.upperBound...])
                        let updated = before.trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n" + instructions + "\n" + after.trimmingCharacters(in: .whitespacesAndNewlines)
                        try? updated.trimmingCharacters(in: .whitespacesAndNewlines).write(toFile: filePath, atomically: true, encoding: .utf8)
                    } else {
                        // Append block
                        let updated = existingContent.trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n" + instructions
                        try? updated.write(toFile: filePath, atomically: true, encoding: .utf8)
                    }
                }
            } else {
                // Create new file
                try? instructions.write(toFile: filePath, atomically: true, encoding: .utf8)
            }
        }
    }
    
    public func removeInstructions(for profile: SSHProfile) {
        let mountPath = (profile.defaultMountPath as NSString).standardizingPath
        guard FileManager.default.fileExists(atPath: mountPath) else { return }
        
        let filenames = ["AGENTS.md", "CLAUDE.md"]
        
        for filename in filenames {
            let filePath = (mountPath as NSString).appendingPathComponent(filename)
            guard FileManager.default.fileExists(atPath: filePath) else { continue }
            
            guard let existingContent = try? String(contentsOfFile: filePath, encoding: .utf8) else { continue }
            
            if let startRange = existingContent.range(of: startDelimiter),
               let endRange = existingContent.range(of: endDelimiter) {
                let before = String(existingContent[..<startRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                let after = String(existingContent[endRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                
                let remaining = (before + (before.isEmpty || after.isEmpty ? "" : "\n\n") + after).trimmingCharacters(in: .whitespacesAndNewlines)
                
                if remaining.isEmpty {
                    // File only contained Integra block -> delete it completely
                    try? FileManager.default.removeItem(atPath: filePath)
                } else {
                    // File had other content -> preserve other content, remove Integra block
                    try? remaining.write(toFile: filePath, atomically: true, encoding: .utf8)
                }
            }
        }
    }
}
