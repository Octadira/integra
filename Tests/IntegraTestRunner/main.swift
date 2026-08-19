import Foundation
import IntegraCore

@MainActor
func main() async {
    print("==========================================================")
    print("=== Running Integra Comprehensive Automated Test Suite ===")
    print("==========================================================")
    print("")
    
    let startTime = CFAbsoluteTimeGetCurrent()
    
    // ---------------------------------------------------------
    // 1. SSHProfile & Control Socket Path Tests
    // ---------------------------------------------------------
    print("▶︎ Running Suite: SSHProfile & Darwin Socket Limits")
    
    TestContext.runTest(suite: "SSHProfileTests", name: "testShortIdGeneration") {
        let profile = SSHProfile(name: "Prod", host: "10.0.0.1", port: 22, user: "root")
        TestContext.assertEqual(profile.shortId.count, 12, "shortId must be exactly 12 hexadecimal characters")
        TestContext.assertFalse(profile.shortId.contains("-"), "shortId must not contain hyphens")
        TestContext.assertTrue(profile.shortId.allSatisfy { $0.isHexDigit }, "shortId must be valid hex characters")
    }
    
    TestContext.runTest(suite: "SSHProfileTests", name: "testControlSocketPathLengthUnderDarwinLimit") {
        let profile = SSHProfile(
            name: "Very Long Server Name That Could Be Created By User",
            host: "tailscale-node-with-a-very-long-magicdns-subdomain.xantu-everest.ts.net",
            port: 2222,
            user: "enterprise_service_account"
        )
        let socketPath = profile.controlSocketPath
        let openSSHInitTempPath = socketPath + ".1234567890123456"
        
        TestContext.assertTrue(socketPath.contains("/.ssh/integra/sock/i_"), "Socket path must be in ~/.ssh/integra/sock/ with i_ prefix")
        TestContext.assertTrue(socketPath.hasSuffix(".sock"), "Socket path must have .sock extension")
        TestContext.assertLessThanOrEqual(socketPath.utf8.count, 65, "Base socket path must be <= 65 bytes")
        TestContext.assertLessThanOrEqual(openSSHInitTempPath.utf8.count, 85, "Socket path with OpenSSH temporary suffix must be <= 85 bytes (well under Darwin 104 limit)")
    }
    
    TestContext.runTest(suite: "SSHProfileTests", name: "testControlMountMapPath") {
        let profile = SSHProfile(name: "Dev", host: "1.1.1.1", port: 22, user: "dev")
        TestContext.assertTrue(profile.controlMountMapPath.hasSuffix("/.ssh/integra/sock/i_\(profile.shortId).mount"), "Mount map path must end with i_<shortId>.mount")
    }
    
    TestContext.runTest(suite: "SSHProfileTests", name: "testJSONSerializationRoundTrip") {
        let originalProfile = SSHProfile(
            name: "Cloud Server",
            host: "cloud.octadira.com",
            port: 2200,
            user: "ubuntu",
            authMethod: .key,
            remotePath: "/var/www/app",
            localPath: "/Volumes/CustomApp",
            identityFile: "~/.ssh/id_ed25519",
            autoMount: true,
            createDesktopShortcut: true,
            portTunnels: [
                PortTunnelRule(name: "DB", localPort: 5432, remotePort: 5432, isEnabled: true)
            ]
        )
        let data = try JSONEncoder().encode(originalProfile)
        let decoded = try JSONDecoder().decode(SSHProfile.self, from: data)
        
        TestContext.assertEqual(decoded.id, originalProfile.id)
        TestContext.assertEqual(decoded.name, originalProfile.name)
        TestContext.assertEqual(decoded.host, originalProfile.host)
        TestContext.assertEqual(decoded.user, originalProfile.user)
        TestContext.assertEqual(decoded.port, originalProfile.port)
        TestContext.assertEqual(decoded.remotePath, originalProfile.remotePath)
        TestContext.assertEqual(decoded.localPath, originalProfile.localPath)
        TestContext.assertEqual(decoded.authMethod, originalProfile.authMethod)
        TestContext.assertEqual(decoded.identityFile, originalProfile.identityFile)
        TestContext.assertEqual(decoded.autoMount, originalProfile.autoMount)
        TestContext.assertEqual(decoded.createDesktopShortcut, originalProfile.createDesktopShortcut)
    }
    
    TestContext.runTest(suite: "SSHProfileTests", name: "testEffectiveUserFallback") {
        let profileEmptyUser = SSHProfile(name: "Local", host: "localhost", port: 22, user: "")
        TestContext.assertEqual(profileEmptyUser.effectiveUser, NSUserName(), "Empty user should fall back to current macOS username")
        let profileCustomUser = SSHProfile(name: "Remote", host: "remote.host", port: 22, user: "deploy")
        TestContext.assertEqual(profileCustomUser.effectiveUser, "deploy")
    }
    
    print("")
    
    // ---------------------------------------------------------
    // 2. Security & Shell Quoting Sanitization Tests
    // ---------------------------------------------------------
    print("▶︎ Running Suite: Security Quoting & Injection Prevention")
    
    TestContext.runTest(suite: "SecurityQuotingTests", name: "testSingleQuoteEscapingForShellSubpaths") {
        func escapeForSingleQuotes(_ input: String) -> String {
            return input.replacingOccurrences(of: "'", with: "'\\''")
        }
        let pathWithQuotes = "/var/www/user's project/app"
        let escaped = escapeForSingleQuotes(pathWithQuotes)
        TestContext.assertEqual(escaped, "/var/www/user'\\''s project/app")
        
        let pathWithMultipleQuotes = "dir/'name'/test'2'"
        let escapedMultiple = escapeForSingleQuotes(pathWithMultipleQuotes)
        TestContext.assertEqual(escapedMultiple, "dir/'\\''name'\\''/test'\\''2'\\''")
    }
    
    TestContext.runTest(suite: "SecurityQuotingTests", name: "testRemoteCommandInjectionPayloadSafety") {
        func buildRemoteCommandPrefix(subpath: String) -> String {
            guard !subpath.isEmpty else { return "" }
            let escaped = subpath.replacingOccurrences(of: "'", with: "'\\''")
            return "if [ -d '\(escaped)' ]; then cd '\(escaped)'; fi; "
        }
        let injectionPayload = "/folder'; rm -rf /; echo '"
        let prefix = buildRemoteCommandPrefix(subpath: injectionPayload)
        
        TestContext.assertTrue(prefix.contains("cd '/folder'\\''"), "Single quotes must be closed and re-escaped")
        TestContext.assertFalse(prefix.contains("'; rm -rf /; '"), "Unescaped quote sequence must never occur")
    }
    
    TestContext.runTest(suite: "SecurityQuotingTests", name: "testSafeTitleBackslashEscaping") {
        let nameWithBackslashes = #"My\Server\Folder"#
        let escapedName = nameWithBackslashes.replacingOccurrences(of: "\\", with: "\\\\")
        TestContext.assertEqual(escapedName, #"My\\Server\\Folder"#)
    }
    
    TestContext.runTest(suite: "SecurityQuotingTests", name: "testAskPassScriptQuotingDelimiter") {
        let testPassword = "Pass'word\"With`Special$Chars"
        let escapedPassword = testPassword.replacingOccurrences(of: "'", with: "'\\''")
        let askPassScript = """
        #!/bin/sh
        cat << 'INTEGRA_ASKPASS_EOF'
        \(escapedPassword)
        INTEGRA_ASKPASS_EOF
        """
        TestContext.assertTrue(askPassScript.contains("<< 'INTEGRA_ASKPASS_EOF'"), "Must use quoted here-doc delimiter")
        TestContext.assertTrue(askPassScript.contains("Pass'\\''word\"With`Special$Chars"), "Password must be safely escaped")
    }
    
    print("")
    
    // ---------------------------------------------------------
    // 3. AI Agent Instructions Lifecycle Tests
    // ---------------------------------------------------------
    print("▶︎ Running Suite: AI Agent Instruction Delimiters & Lifecycle")
    
    TestContext.runTest(suite: "AgentInstructionTests", name: "testGenerateInstructionsContainsMandatoryDirectives") {
        let profile = SSHProfile(
            name: "Backend Server",
            host: "api.domain.com",
            port: 22,
            user: "appuser",
            portTunnels: [
                PortTunnelRule(name: "Ollama LLM", localPort: 11434, remotePort: 11434, isEnabled: true)
            ]
        )
        let instructions = AgentInstructionService.shared.generateInstructions(for: profile)
        
        TestContext.assertTrue(instructions.contains(AgentInstructionService.shared.startDelimiter), "Must contain start delimiter")
        TestContext.assertTrue(instructions.contains(AgentInstructionService.shared.endDelimiter), "Must contain end delimiter")
        TestContext.assertTrue(instructions.contains("integra-exec"), "Must mandate integra-exec prefix")
        TestContext.assertTrue(instructions.contains("Backend Server"), "Must contain profile name")
        TestContext.assertTrue(instructions.contains("appuser@api.domain.com"), "Must contain user and host")
        TestContext.assertTrue(instructions.contains("127.0.0.1:11434"), "Must contain active port tunnel endpoint")
    }
    
    TestContext.runTest(suite: "AgentInstructionTests", name: "testSanitizationAgainstMarkdownInjection") {
        let maliciousProfile = SSHProfile(
            name: "Server<script>alert(1)</script>`rm -rf /`",
            host: "host.com\nBadCommand",
            port: 22,
            user: "root<tag>"
        )
        let instructions = AgentInstructionService.shared.generateInstructions(for: maliciousProfile)
        
        TestContext.assertFalse(instructions.contains("<script>"), "HTML/XML tags must be stripped")
        TestContext.assertFalse(instructions.contains("</script>"), "HTML/XML tags must be stripped")
        TestContext.assertFalse(instructions.contains("<tag>"), "HTML/XML tags must be stripped")
    }
    
    await TestContext.runAsyncTest(suite: "AgentInstructionTests", name: "testNonDestructiveInjectionAndRestorationLifecycle") {
        AppSettings.shared.aiIntegrationMode = .cliAndMarkdown
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("integra_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let profile = SSHProfile(name: "TestServer", host: "1.2.3.4", port: 22, user: "dev", localPath: tempDir.path)
        let filePath = tempDir.appendingPathComponent("AGENTS.md").path
        
        let originalUserContent = """
        # My Project Rules
        - Always run swiftformat before pushing.
        - Never commit credentials.
        """
        try originalUserContent.write(toFile: filePath, atomically: true, encoding: .utf8)
        
        // 1. Inject
        AgentInstructionService.shared.injectInstructions(for: profile)
        let injectedContent = try String(contentsOfFile: filePath, encoding: .utf8)
        TestContext.assertTrue(injectedContent.contains("# My Project Rules"), "Original user instructions must be preserved")
        TestContext.assertTrue(injectedContent.contains(AgentInstructionService.shared.startDelimiter), "Integra block must be injected")
        
        // 2. Re-inject (Idempotency)
        AgentInstructionService.shared.injectInstructions(for: profile)
        let doubleInjected = try String(contentsOfFile: filePath, encoding: .utf8)
        let startCount = doubleInjected.components(separatedBy: AgentInstructionService.shared.startDelimiter).count - 1
        TestContext.assertEqual(startCount, 1, "Idempotent injection must never create duplicate blocks")
        
        // 3. Clean unmount restoration
        AgentInstructionService.shared.removeInstructions(for: profile)
        let restoredContent = try String(contentsOfFile: filePath, encoding: .utf8)
        TestContext.assertFalse(restoredContent.contains(AgentInstructionService.shared.startDelimiter), "Integra delimiter must be cleanly removed")
        TestContext.assertEqual(restoredContent.trimmingCharacters(in: .whitespacesAndNewlines), originalUserContent.trimmingCharacters(in: .whitespacesAndNewlines), "User content must match original byte-for-byte")
    }
    
    await TestContext.runAsyncTest(suite: "AgentInstructionTests", name: "testPureIntegraFileDeletionOnUnmount") {
        AppSettings.shared.aiIntegrationMode = .cliAndMarkdown
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("integra_test_pure_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let profile = SSHProfile(name: "PureServer", host: "1.2.3.4", port: 22, user: "dev", localPath: tempDir.path)
        let agentsPath = tempDir.appendingPathComponent("AGENTS.md").path
        let claudePath = tempDir.appendingPathComponent("CLAUDE.md").path
        
        AgentInstructionService.shared.injectInstructions(for: profile)
        TestContext.assertTrue(FileManager.default.fileExists(atPath: agentsPath), "AGENTS.md should be created")
        TestContext.assertTrue(FileManager.default.fileExists(atPath: claudePath), "CLAUDE.md should be created")
        
        AgentInstructionService.shared.removeInstructions(for: profile)
        TestContext.assertFalse(FileManager.default.fileExists(atPath: agentsPath), "Pure Integra AGENTS.md must be deleted on unmount")
        TestContext.assertFalse(FileManager.default.fileExists(atPath: claudePath), "Pure Integra CLAUDE.md must be deleted on unmount")
    }
    
    print("")
    
    // ---------------------------------------------------------
    // 4. Network Recovery & Exponential Backoff Tests
    // ---------------------------------------------------------
    print("▶︎ Running Suite: Network Recovery & Backoff Math")
    
    TestContext.runTest(suite: "NetworkRecoveryTests", name: "testIntendedMountRegistrationAndUnmount") {
        let recovery = NetworkRecoveryService.shared
        let profileId = UUID()
        
        recovery.recordIntendedMount(profileId)
        TestContext.assertTrue(recovery.intendedMounts.contains(profileId), "Profile must be in intendedMounts set")
        
        recovery.recordIntendedUnmount(profileId)
        TestContext.assertFalse(recovery.intendedMounts.contains(profileId), "Profile must be removed on explicit unmount")
    }
    
    TestContext.runTest(suite: "NetworkRecoveryTests", name: "testExponentialBackoffIntervalCalculations") {
        func computeDelay(attempt: Int) -> Double {
            return min(30.0, 1.5 * pow(2.0, Double(attempt)))
        }
        
        TestContext.assertEqual(computeDelay(attempt: 0), 1.5, "Attempt 0 backoff")
        TestContext.assertEqual(computeDelay(attempt: 1), 3.0, "Attempt 1 backoff")
        TestContext.assertEqual(computeDelay(attempt: 2), 6.0, "Attempt 2 backoff")
        TestContext.assertEqual(computeDelay(attempt: 3), 12.0, "Attempt 3 backoff")
        TestContext.assertEqual(computeDelay(attempt: 4), 24.0, "Attempt 4 backoff")
        TestContext.assertEqual(computeDelay(attempt: 5), 30.0, "Attempt 5 backoff capped")
        TestContext.assertEqual(computeDelay(attempt: 6), 30.0, "Attempt 6 backoff capped")
    }
    
    print("")
    
    // ---------------------------------------------------------
    // 5. SSH Tunneling & Port Forwarding Tests
    // ---------------------------------------------------------
    print("▶︎ Running Suite: Port Forwarding & Loopback Endpoints")
    
    TestContext.runTest(suite: "SSHTunnelTests", name: "testPortTunnelRuleFormatting") {
        let rule = PortTunnelRule(name: "Ollama LLM", localPort: 11434, remotePort: 11434, remoteHost: "127.0.0.1", isEnabled: true)
        TestContext.assertEqual(rule.name, "Ollama LLM")
        TestContext.assertEqual(rule.localPort, 11434)
        TestContext.assertEqual(rule.remotePort, 11434)
        TestContext.assertEqual(rule.remoteHost, "127.0.0.1")
        TestContext.assertTrue(rule.isEnabled)
    }
    
    TestContext.runTest(suite: "SSHTunnelTests", name: "testPortAvailabilityCheck") {
        let tunnelService = SSHTunnelService.shared
        let isAvailable = tunnelService.checkPortAvailability(port: 54321)
        TestContext.assertNotNil(isAvailable)
    }
    
    print("")
    
    // ---------------------------------------------------------
    // 6. OpenSSH ~/.ssh/config Parser Tests
    // ---------------------------------------------------------
    print("▶︎ Running Suite: OpenSSH Config File Parser")
    
    TestContext.runTest(suite: "SSHConfigParserTests", name: "testParseStandardSSHConfig") {
        let sampleConfig = """
        # Personal Home Server
        Host home-lab
            HostName 192.168.1.100
            User admin
            Port 2222
            IdentityFile ~/.ssh/id_ed25519
        
        # Wildcard settings (should be skipped)
        Host *
            ServerAliveInterval 60
            
        # Work Jump Server
        Host jump-bastion
            HostName bastion.corp.internal
            User deploy
            Port 22
        """
        let entries = SSHConfigParser.parse(content: sampleConfig)
        TestContext.assertEqual(entries.count, 2, "Should parse 2 specific hosts, ignoring wildcard Host *")
        
        let homeLab = entries[0]
        TestContext.assertEqual(homeLab.host, "home-lab")
        TestContext.assertEqual(homeLab.hostName, "192.168.1.100")
        TestContext.assertEqual(homeLab.user, "admin")
        TestContext.assertEqual(homeLab.port, 2222)
        TestContext.assertEqual(homeLab.identityFile, "~/.ssh/id_ed25519")
        
        let jump = entries[1]
        TestContext.assertEqual(jump.host, "jump-bastion")
        TestContext.assertEqual(jump.hostName, "bastion.corp.internal")
        TestContext.assertEqual(jump.user, "deploy")
        TestContext.assertEqual(jump.port, 22)
        TestContext.assertNil(jump.identityFile)
    }
    
    TestContext.runTest(suite: "SSHConfigParserTests", name: "testParseEmptyOrCommentOnlyConfig") {
        let emptyConfig = """
        # Only comments here
        # Nothing else
        """
        let entries = SSHConfigParser.parse(content: emptyConfig)
        TestContext.assertTrue(entries.isEmpty)
    }
    
    // ---------------------------------------------------------
    // 7. Model Context Protocol (MCP) & AI Integration Modes
    // ---------------------------------------------------------
    print("▶︎ Running Suite: Model Context Protocol (MCP) & IDE Auto-Config")
    
    TestContext.runTest(suite: "MCPConfigServiceTests", name: "testSupportedAIClientsConfigPaths") {
        for client in SupportedAIClient.allCases {
            TestContext.assertFalse(client.primaryConfigPath.isEmpty, "Config path for \(client.rawValue) must not be empty")
            TestContext.assertTrue(client.primaryConfigPath.contains(NSHomeDirectory()), "Config path must be within user home directory")
        }
    }
    
    TestContext.runTest(suite: "MCPConfigServiceTests", name: "testJSONMergingPreservesExistingServers") {
        let sampleClaudeJson = """
        {
          "mcpServers": {
            "sqlite": {
              "command": "uvx",
              "args": ["mcp-server-sqlite", "--db-path", "/data/test.db"]
            }
          },
          "preferences": {
            "theme": "dark"
          }
        }
        """
        guard let data = sampleClaudeJson.data(using: .utf8),
              var rootDict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              var mcpServers = rootDict["mcpServers"] as? [String: Any] else {
            TestContext.assertTrue(false, "Failed to parse initial test JSON")
            return
        }
        
        // Simulate adding Integra entry
        mcpServers["integra"] = [
            "command": "/Applications/Integra.app/Contents/MacOS/integra-mcp",
            "args": [] as [String]
        ]
        rootDict["mcpServers"] = mcpServers
        
        TestContext.assertEqual(mcpServers.count, 2, "mcpServers must now contain exactly 2 servers")
        TestContext.assertNotNil(mcpServers["sqlite"], "Existing sqlite server must be preserved")
        TestContext.assertNotNil(mcpServers["integra"], "Integra server must be present")
        TestContext.assertNotNil(rootDict["preferences"], "Existing root preferences must be preserved")
    }
    
    TestContext.runTest(suite: "MCPConfigServiceTests", name: "testZedContextServersFormat") {
        var rootDict: [String: Any] = [:]
        var contextServers = rootDict["context_servers"] as? [String: Any] ?? [:]
        contextServers["integra"] = [
            "command": "/Applications/Integra.app/Contents/MacOS/integra-mcp",
            "args": [] as [String]
        ]
        rootDict["context_servers"] = contextServers
        
        TestContext.assertNotNil(rootDict["context_servers"], "Zed configuration must use context_servers key")
        let updatedServers = rootDict["context_servers"] as? [String: Any]
        TestContext.assertNotNil(updatedServers?["integra"], "Zed context_servers must have integra entry")
    }
    
    TestContext.runTest(suite: "MCPConfigServiceTests", name: "testOpenCodeConfigFormatWithoutTopLevelMCPServers") {
        let tempDir = NSTemporaryDirectory() + "integra_opencode_test_\(UUID().uuidString)"
        let configPath = "\(tempDir)/opencode.json"
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }
        
        // Write initial config with legacy invalid top-level key
        let initialJson = ["mcpServers": ["old": ["command": "test"]]]
        let initialData = try! JSONSerialization.data(withJSONObject: initialJson)
        try! initialData.write(to: URL(fileURLWithPath: configPath))
        
        // Emulate install for OpenCode
        var rootDict = (try? JSONSerialization.jsonObject(with: initialData)) as? [String: Any] ?? [:]
        var mcpDict = rootDict["mcp"] as? [String: Any] ?? ["enabled": true]
        var servers = mcpDict["servers"] as? [String: Any] ?? [:]
        servers["integra"] = [
            "command": "/Applications/Integra.app/Contents/MacOS/integra-mcp",
            "args": [] as [String]
        ]
        mcpDict["servers"] = servers
        mcpDict["enabled"] = true
        rootDict["mcp"] = mcpDict
        rootDict.removeValue(forKey: "mcpServers")
        
        TestContext.assertNil(rootDict["mcpServers"], "OpenCode configuration must NOT contain top-level mcpServers key")
        TestContext.assertNotNil(rootDict["mcp"], "OpenCode configuration must contain mcp dictionary")
        let mcp = rootDict["mcp"] as? [String: Any]
        let mcpServersDict = mcp?["servers"] as? [String: Any]
        TestContext.assertNotNil(mcpServersDict?["integra"], "mcp.servers must contain integra entry")
    }
    
    TestContext.runTest(suite: "MCPConfigServiceTests", name: "testCodexTOMLConfigFormat") {
        let tempDir = NSTemporaryDirectory() + "integra_codex_test_\(UUID().uuidString)"
        let configPath = "\(tempDir)/config.toml"
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }
        
        let initialToml = """
        [features]
        js_repl = false
        """
        try! initialToml.write(to: URL(fileURLWithPath: configPath), atomically: true, encoding: .utf8)
        
        // Emulate install for Codex
        var content = try! String(contentsOf: URL(fileURLWithPath: configPath), encoding: .utf8)
        if !content.contains("[mcp_servers.integra]") {
            let tomlBlock = """
            
            [mcp_servers.integra]
            command = "/Applications/Integra.app/Contents/MacOS/integra-mcp"
            args = []
            """
            content.append(tomlBlock)
            try! content.write(to: URL(fileURLWithPath: configPath), atomically: true, encoding: .utf8)
        }
        
        let updatedContent = try! String(contentsOf: URL(fileURLWithPath: configPath), encoding: .utf8)
        TestContext.assertTrue(updatedContent.contains("[mcp_servers.integra]"), "Codex TOML must contain [mcp_servers.integra]")
        TestContext.assertTrue(updatedContent.contains("command = \"/Applications/Integra.app/Contents/MacOS/integra-mcp\""), "Codex TOML must contain correct binary path")
        TestContext.assertTrue(updatedContent.contains("js_repl = false"), "Codex TOML must preserve existing settings")
    }
    
    print("▶︎ Running Suite: AI Integration Modes & Zero-Pollution Lifecycle")
    
    TestContext.runTest(suite: "AIIntegrationModeTests", name: "testHybridModeGeneratesHierarchicalDirectives") {
        let profile = SSHProfile(name: "Staging", host: "10.0.0.5", port: 22, user: "admin")
        AppSettings.shared.aiIntegrationMode = .hybrid
        
        let instructions = AgentInstructionService.shared.generateInstructions(for: profile)
        TestContext.assertTrue(instructions.contains("INTEGRA DUAL-STACK"), "Hybrid instructions must contain DUAL-STACK header")
        TestContext.assertTrue(instructions.contains("integra_execute_command"), "Hybrid instructions must mention native MCP tool as preferred")
        TestContext.assertTrue(instructions.contains("integra-exec"), "Hybrid instructions must mention integra-exec as fallback")
    }
    
    TestContext.runTest(suite: "AIIntegrationModeTests", name: "testLegacyCLIModeGeneratesClassicDirectives") {
        let profile = SSHProfile(name: "Staging", host: "10.0.0.5", port: 22, user: "admin")
        AppSettings.shared.aiIntegrationMode = .cliAndMarkdown
        
        let instructions = AgentInstructionService.shared.generateInstructions(for: profile)
        TestContext.assertTrue(instructions.contains("INTEGRA AI BRIDGE"), "Legacy instructions must contain INTEGRA AI BRIDGE header")
        TestContext.assertTrue(instructions.contains("integra-exec docker ps"), "Legacy instructions must contain standard CLI examples")
    }
    
    TestContext.runTest(suite: "AIIntegrationModeTests", name: "testMCPOnlyModeLeavesDirectoryClean") {
        let tempDir = NSTemporaryDirectory() + "integra_mcp_clean_test_\(UUID().uuidString)"
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }
        
        var profile = SSHProfile(name: "TestClean", host: "127.0.0.1", port: 22, user: "test")
        profile.localPath = tempDir
        
        AppSettings.shared.aiIntegrationMode = .mcpOnly
        AgentInstructionService.shared.injectInstructions(for: profile)
        
        let agentsPath = "\(tempDir)/AGENTS.md"
        let claudePath = "\(tempDir)/CLAUDE.md"
        TestContext.assertFalse(FileManager.default.fileExists(atPath: agentsPath), "In .mcpOnly mode, AGENTS.md must NOT be created")
        TestContext.assertFalse(FileManager.default.fileExists(atPath: claudePath), "In .mcpOnly mode, CLAUDE.md must NOT be created")
    }
    
    // ---------------------------------------------------------
    // 9. Sudo & Touch ID Privilege Escalation Tests
    // ---------------------------------------------------------
    print("▶︎ Running Suite: Sudo Privilege Escalation & Authorization")
    
    TestContext.runTest(suite: "SudoAuthPolicyTests", name: "testSudoProfileDefaultsAndSessionCache") {
        let profile = SSHProfile(name: "TestServer", host: "192.168.1.10", port: 22, user: "admin")
        TestContext.assertTrue(profile.useSSHPasswordForSudo, "Default useSSHPasswordForSudo must be true")
        TestContext.assertEqual(profile.sudoAuthPolicy, .sessionCache, "Default sudoAuthPolicy must be .sessionCache")
        
        TestContext.assertFalse(SudoAuthManager.shared.isSessionValid(for: profile.id), "Session should not be valid before authorization")
        
        SudoAuthManager.shared.recordAuthorization(for: profile.id)
        TestContext.assertTrue(SudoAuthManager.shared.isSessionValid(for: profile.id), "Session should be valid immediately after recording")
        
        SudoAuthManager.shared.clearAuthorization(for: profile.id)
        TestContext.assertFalse(SudoAuthManager.shared.isSessionValid(for: profile.id), "Session should be invalid after clearing")
    }
    
    TestContext.runTest(suite: "KeychainSudoTests", name: "testKeychainSudoPasswordCRUD") {
        let profileId = UUID()
        let testSudoPass = "SuperSecretSudoPass123!"
        
        _ = KeychainService.shared.deleteSudoPassword(for: profileId)
        TestContext.assertNil(KeychainService.shared.getSudoPassword(for: profileId), "Password must be nil initially")
        
        let saved = KeychainService.shared.saveSudoPassword(for: profileId, password: testSudoPass)
        TestContext.assertTrue(saved, "Saving sudo password to Keychain should succeed")
        
        let retrieved = KeychainService.shared.getSudoPassword(for: profileId)
        TestContext.assertEqual(retrieved, testSudoPass, "Retrieved sudo password must match saved password")
        
        let deleted = KeychainService.shared.deleteSudoPassword(for: profileId)
        TestContext.assertTrue(deleted, "Deleting sudo password should succeed")
        TestContext.assertNil(KeychainService.shared.getSudoPassword(for: profileId), "Password must be nil after deletion")
    }
    
    TestContext.runTest(suite: "KeychainSudoTests", name: "testEffectiveSudoPasswordFallback") {
        let profileId = UUID()
        let sshPass = "LoginSSHPassword999"
        
        _ = KeychainService.shared.savePassword(account: profileId.uuidString, password: sshPass)
        _ = KeychainService.shared.deleteSudoPassword(for: profileId)
        
        var profile = SSHProfile(id: profileId, name: "FallbackServer", host: "10.0.0.1", port: 22, user: "user")
        profile.useSSHPasswordForSudo = true
        
        let effectivePass = KeychainService.shared.getEffectiveSudoPassword(for: profile)
        TestContext.assertEqual(effectivePass, sshPass, "Effective sudo password must fallback to SSH login password when useSSHPasswordForSudo is true")
        
        // When explicit sudo password is set, it takes precedence
        let explicitPass = "DedicatedRootPass777"
        _ = KeychainService.shared.saveSudoPassword(for: profileId, password: explicitPass)
        let overridingPass = KeychainService.shared.getEffectiveSudoPassword(for: profile)
        TestContext.assertEqual(overridingPass, explicitPass, "Explicit sudo password must take precedence over SSH password")
        
        _ = KeychainService.shared.deletePassword(account: profileId.uuidString)
        _ = KeychainService.shared.deleteSudoPassword(for: profileId)
    }
    
    // ---------------------------------------------------------
    // 10. Update Checker & SemVer Comparison Tests
    // ---------------------------------------------------------
    print("▶︎ Running Suite: Update Checker & SemVer Comparison")
    
    TestContext.runTest(suite: "UpdateCheckerTests", name: "testSemVerComparisonNewerVersionDetected") {
        TestContext.assertTrue(UpdateCheckerService.isVersion("0.13.0", newerThan: "0.12.0"), "0.13.0 must be recognized as newer than 0.12.0")
        TestContext.assertTrue(UpdateCheckerService.isVersion("1.0.0", newerThan: "0.99.9"), "1.0.0 must be recognized as newer than 0.99.9")
        TestContext.assertTrue(UpdateCheckerService.isVersion("0.12.1", newerThan: "0.12.0"), "0.12.1 must be recognized as newer than 0.12.0")
        TestContext.assertTrue(UpdateCheckerService.isVersion("v0.14.0", newerThan: "v0.13.0"), "v0.14.0 must be recognized as newer than v0.13.0 with v prefix")
    }
    
    TestContext.runTest(suite: "UpdateCheckerTests", name: "testSemVerComparisonEqualOrOlderIgnored") {
        TestContext.assertFalse(UpdateCheckerService.isVersion("0.12.0", newerThan: "0.12.0"), "Equal versions must return false")
        TestContext.assertFalse(UpdateCheckerService.isVersion("0.11.0", newerThan: "0.12.0"), "Older minor version must return false")
        TestContext.assertFalse(UpdateCheckerService.isVersion("0.9.9", newerThan: "1.0.0"), "Older major version must return false")
        TestContext.assertFalse(UpdateCheckerService.isVersion("0.12.0", newerThan: "0.12.1"), "Older patch version must return false")
    }
    
    TestContext.runTest(suite: "UpdateCheckerTests", name: "testVersionStringSanitization") {
        TestContext.assertEqual(UpdateCheckerService.cleanVersionString("v1.2.3"), "1.2.3", "v prefix must be stripped")
        TestContext.assertEqual(UpdateCheckerService.cleanVersionString(" 0.13.0 \n"), "0.13.0", "Surrounding whitespace must be trimmed")
    }
    
    print("")
    
    let duration = String(format: "%.3f", CFAbsoluteTimeGetCurrent() - startTime)
    print("==========================================================")
    if TestContext.failures.isEmpty {
        print("✅ ALL \(TestContext.totalPassed) TESTS PASSED SUCCESSFULLY! (\(duration)s)")
        print("==========================================================")
        exit(0)
    } else {
        print("❌ \(TestContext.failures.count) OF \(TestContext.totalTestsRun) TESTS FAILED:")
        for (idx, failure) in TestContext.failures.enumerated() {
            print("  [\(idx + 1)] \(failure.testName)")
            print("      \(failure.message)")
            print("      File: \(failure.file):\(failure.line)")
        }
        print("==========================================================")
        exit(1)
    }
}

await main()
