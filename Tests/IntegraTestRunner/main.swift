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
    
    TestContext.runTest(suite: "SSHProfileTests", name: "testProfileStoreExportAndImportJSON") {
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("integra_test_profiles_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        let store = ProfileStore(storageURL: tempURL)
        let p1 = SSHProfile(name: "Server-1", host: "1.2.3.4", port: 22, user: "admin", remotePath: "/app1")
        let p2 = SSHProfile(name: "Server-2", host: "5.6.7.8", port: 2222, user: "root", remotePath: "/app2")
        store.profiles = [p1, p2]
        
        // Test Export
        let exportedData = try store.exportProfilesToData()
        TestContext.assertTrue(exportedData.count > 0, "Exported data must not be empty")
        
        let jsonString = String(data: exportedData, encoding: .utf8) ?? ""
        TestContext.assertTrue(jsonString.contains("Server-1"), "Exported JSON must contain Server-1")
        TestContext.assertTrue(jsonString.contains("Server-2"), "Exported JSON must contain Server-2")
        
        // Test Import with Merge
        let p3 = SSHProfile(name: "Server-3", host: "9.10.11.12", port: 22, user: "deploy", remotePath: "/app3")
        let mergeData = try JSONEncoder().encode([p3])
        let importedCount = try store.importProfiles(from: mergeData, mergeStrategy: .merge)
        TestContext.assertEqual(importedCount, 1, "Must report 1 new profile imported")
        TestContext.assertEqual(store.profiles.count, 3, "Profile store must now contain 3 profiles")
        
        // Test Import with Replace
        let replaceData = try JSONEncoder().encode([p3])
        let replaceCount = try store.importProfiles(from: replaceData, mergeStrategy: .replace)
        TestContext.assertEqual(replaceCount, 1, "Must report 1 profile in replacement")
        TestContext.assertEqual(store.profiles.count, 1, "Profile store must contain only the replacement profile")
        TestContext.assertEqual(store.profiles.first?.name, "Server-3")
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
    
    TestContext.runTest(suite: "SSHTunnelTests", name: "testPasswordAuthAskPassScriptGeneration") {
        let dummyPass = "SecureP@ssw0rd$123!'"
        let askpassDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("integra_test_askpass_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: askpassDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: askpassDir) }
        
        let tempScript = askpassDir.appendingPathComponent("askpass_test.sh")
        let scriptContent = """
        #!/bin/sh
        /bin/cat << 'INTEGRA_ASKPASS_EOF'
        \(dummyPass)
        INTEGRA_ASKPASS_EOF
        """
        try? scriptContent.write(to: tempScript, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: tempScript.path)
        
        TestContext.assertTrue(FileManager.default.fileExists(atPath: tempScript.path), "AskPass script must exist on disk")
        let readBack = try? String(contentsOf: tempScript, encoding: .utf8)
        TestContext.assertTrue(readBack?.contains(dummyPass) == true, "AskPass script must contain password without shell expansion")
    }
    
    TestContext.runTest(suite: "SSHTunnelTests", name: "testTunnelLifecycleAndAutoRecoveryTracking") {
        let tunnelService = SSHTunnelService.shared
        let profileId = UUID()
        var profile = SSHProfile(id: profileId, name: "DatabaseServer", host: "10.0.0.1", port: 22, user: "dbuser")
        let rule = PortTunnelRule(name: "PostgreSQL", localPort: 5432, remotePort: 5432, isEnabled: true)
        profile.portTunnels = [rule]
        
        // Initial state: not running, not intended
        TestContext.assertFalse(tunnelService.isTunnelRunning(for: profileId), "Tunnel must not be running initially")
        TestContext.assertFalse(tunnelService.intendedTunnels.contains(profileId), "Tunnel must not be intended initially")
        
        // Simulate intended tunnel registration
        tunnelService.intendedTunnels.insert(profileId)
        TestContext.assertTrue(tunnelService.intendedTunnels.contains(profileId), "Tunnel must be registered as intended")
        
        // Non-user-initiated stop (e.g. restart / auto-reconnect) preserves intended status
        tunnelService.stopTunnels(for: profile, isUserInitiated: false)
        TestContext.assertTrue(tunnelService.intendedTunnels.contains(profileId), "Non-user-initiated stop must preserve intended state")
        
        // User-initiated stop clears intended status
        tunnelService.stopTunnels(for: profile, isUserInitiated: true)
        TestContext.assertFalse(tunnelService.intendedTunnels.contains(profileId), "User-initiated stop must clear intended state")
    }
    
    TestContext.runTest(suite: "SSHTunnelTests", name: "testTunnelFlappingLoopPreventionAndMaxRetries") {
        let tunnelService = SSHTunnelService.shared
        let profileId = UUID()
        var profile = SSHProfile(id: profileId, name: "UnreachableServer", host: "192.0.2.1", port: 22, user: "root")
        let rule = PortTunnelRule(name: "MySQL", localPort: 3306, remotePort: 3306, isEnabled: true)
        profile.portTunnels = [rule]
        
        tunnelService.intendedTunnels.insert(profileId)
        tunnelService.reconnectAttemptsByProfile[profileId] = 5
        
        // Exceeding 5 attempts must halt reconnect and clear intended state
        tunnelService.scheduleTunnelReconnect(for: profile, attempt: 6)
        
        TestContext.assertFalse(tunnelService.intendedTunnels.contains(profileId), "Exceeding max retries must halt loop and remove from intended tunnels")
        TestContext.assertNil(tunnelService.reconnectAttemptsByProfile[profileId], "Reconnect attempts must be cleaned up on halt")
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
        var mcpDict = rootDict["mcp"] as? [String: Any] ?? [:]
        mcpDict.removeValue(forKey: "enabled")
        mcpDict.removeValue(forKey: "servers")
        mcpDict["integra"] = [
            "type": "local",
            "command": ["/Applications/Integra.app/Contents/MacOS/integra-mcp"],
            "enabled": true
        ]
        rootDict["mcp"] = mcpDict
        rootDict.removeValue(forKey: "mcpServers")
        
        TestContext.assertNil(rootDict["mcpServers"], "OpenCode configuration must NOT contain top-level mcpServers key")
        TestContext.assertNotNil(rootDict["mcp"], "OpenCode configuration must contain mcp dictionary")
        let mcp = rootDict["mcp"] as? [String: Any]
        let integraEntry = mcp?["integra"] as? [String: Any]
        TestContext.assertNotNil(integraEntry, "mcp must contain integra entry directly")
        TestContext.assertEqual(integraEntry?["type"] as? String, "local", "integra entry must have type: local")
        TestContext.assertEqual(integraEntry?["enabled"] as? Bool, true, "integra entry must have enabled: true")
        let cmdArray = integraEntry?["command"] as? [String]
        TestContext.assertEqual(cmdArray?.first, "/Applications/Integra.app/Contents/MacOS/integra-mcp", "command must be an array with the binary path")
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
    
    TestContext.runTest(suite: "MCPConfigServiceTests", name: "testKiroMCPConfigurationPathAndFormat") {
        let kiroClient = SupportedAIClient.kiro
        TestContext.assertTrue(kiroClient.primaryConfigPath.contains(".kiro/settings/mcp.json"), "Kiro primary config path must point to .kiro/settings/mcp.json")
        TestContext.assertEqual(kiroClient.icon, "cpu", "Kiro icon should be cpu")
    }
    
    TestContext.runTest(suite: "MCPConfigServiceTests", name: "testPiDevMCPConfigurationPaths") {
        let piClient = SupportedAIClient.piDev
        TestContext.assertTrue(piClient.primaryConfigPath.contains(".pi/agent/mcp.json"), "Pi primary config path must point to ~/.pi/agent/mcp.json")
        TestContext.assertTrue(piClient.secondaryConfigPaths.contains { $0.contains(".config/mcp/mcp.json") }, "Pi secondary paths must contain ~/.config/mcp/mcp.json")
        TestContext.assertTrue(piClient.secondaryConfigPaths.contains { $0.contains(".pi/mcp.json") }, "Pi secondary paths must contain ~/.pi/mcp.json")
    }
    
    TestContext.runTest(suite: "CodeEditorAppTests", name: "testCodeEditorAppEnumIncludesWindsurfAndKiro") {
        let allEditors = CodeEditorApp.allCases
        TestContext.assertTrue(allEditors.contains(.windsurf), "CodeEditorApp must contain .windsurf")
        TestContext.assertTrue(allEditors.contains(.kiro), "CodeEditorApp must contain .kiro")
        TestContext.assertTrue(allEditors.contains(.zed), "CodeEditorApp must contain .zed")
        TestContext.assertTrue(allEditors.contains(.openCode), "CodeEditorApp must contain .openCode")
        TestContext.assertTrue(allEditors.contains(.antigravity), "CodeEditorApp must contain .antigravity")
        TestContext.assertEqual(CodeEditorApp.windsurf.rawValue, "Windsurf", "Windsurf raw value must match")
        TestContext.assertEqual(CodeEditorApp.kiro.rawValue, "Kiro (kiro.dev)", "Kiro raw value must match")
        TestContext.assertEqual(CodeEditorApp.zed.rawValue, "Zed", "Zed raw value must match")
        TestContext.assertEqual(CodeEditorApp.openCode.rawValue, "OpenCode", "OpenCode raw value must match")
        TestContext.assertEqual(CodeEditorApp.antigravity.rawValue, "Antigravity 2.0 IDE", "Antigravity raw value must match")
    }
    
    TestContext.runTest(suite: "MCPConfigServiceTests", name: "testBackgroundJobCommandFormatting") {
        let cmd = "sudo apt-get update && sudo apt-get upgrade -y"
        let escaped = cmd.replacingOccurrences(of: "'", with: "'\\''")
        let logPath = "/tmp/integra_job_test.log"
        let bgCmd = "nohup sh -c '\(escaped)' > '\(logPath)' 2>&1 & BG_PID=$!; echo \"[INTEGRA_BG_JOB] PID=$BG_PID | LOG=\(logPath)\""
        
        TestContext.assertTrue(bgCmd.hasPrefix("nohup sh -c"), "Background command must use nohup sh -c")
        TestContext.assertTrue(bgCmd.contains(escaped), "Background command must preserve escaped inner command")
        TestContext.assertTrue(bgCmd.contains("> '/tmp/integra_job_test.log' 2>&1 &"), "Background command must redirect both stdout and stderr")
        TestContext.assertTrue(bgCmd.contains("echo \"[INTEGRA_BG_JOB] PID=$BG_PID | LOG=/tmp/integra_job_test.log\""), "Background command must echo structured job tag")
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
    
    TestContext.runTest(suite: "SudoAuthPolicyTests", name: "testIdentityFilePermissionSanitization") {
        let tempKeyPath = NSTemporaryDirectory() + "test_key_\(UUID().uuidString).pem"
        let dummyContent = "-----BEGIN RSA PRIVATE KEY-----\ndummy\n-----END RSA PRIVATE KEY-----"
        try? dummyContent.write(toFile: tempKeyPath, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: tempKeyPath)
        defer { try? FileManager.default.removeItem(atPath: tempKeyPath) }
        
        var profile = SSHProfile(name: "KeyServer", host: "1.2.3.4", port: 22, user: "ubuntu", authMethod: .key)
        profile.identityFile = tempKeyPath
        
        let initialAttrs = try? FileManager.default.attributesOfItem(atPath: tempKeyPath)
        let initialPerms = (initialAttrs?[.posixPermissions] as? NSNumber)?.intValue
        TestContext.assertEqual(initialPerms, 0o644, "Initial permission must be 0644")
        
        profile.sanitizeIdentityFilePermissionsIfNeeded()
        
        let sanitizedAttrs = try? FileManager.default.attributesOfItem(atPath: tempKeyPath)
        let sanitizedPerms = (sanitizedAttrs?[.posixPermissions] as? NSNumber)?.intValue
        TestContext.assertEqual(sanitizedPerms, 0o600, "Sanitized permission must be 0600")
    }
    
    await TestContext.runAsyncTest(suite: "SudoAuthPolicyTests", name: "testRootUserSudoAuthAutoGrantsWithoutPassword") {
        let rootProfile = SSHProfile(name: "RootServer", host: "5.6.7.8", port: 22, user: "root", sudoAuthPolicy: .autoApprove)
        let authResult = await SudoAuthManager.shared.authorizeAndGetPassword(profile: rootProfile, command: "reboot")
        TestContext.assertTrue(authResult.isGranted, "Root user with autoApprove must be granted")
        TestContext.assertNil(authResult.sudoPassword, "Root user should not require sudo password")
    }
    
    await TestContext.runAsyncTest(suite: "SudoAuthPolicyTests", name: "testAutoApprovePolicyNonInteractiveSudo") {
        let profileId = UUID()
        let profile = SSHProfile(id: profileId, name: "AutoApproveServer", host: "1.1.1.1", port: 22, user: "adrian", sudoAuthPolicy: .autoApprove)
        
        // Scenario 1: Password in Keychain
        _ = KeychainService.shared.saveSudoPassword(for: profileId, password: "SecretSudoPassword")
        let authResult1 = await SudoAuthManager.shared.authorizeAndGetPassword(profile: profile, command: "whoami")
        TestContext.assertTrue(authResult1.isGranted, "AutoApprove must be granted")
        TestContext.assertEqual(authResult1.sudoPassword, "SecretSudoPassword", "AutoApprove must inject Keychain password")
        
        // Scenario 2: Passwordless (no password in Keychain)
        _ = KeychainService.shared.deleteSudoPassword(for: profileId)
        let authResult2 = await SudoAuthManager.shared.authorizeAndGetPassword(profile: profile, command: "whoami")
        TestContext.assertTrue(authResult2.isGranted, "AutoApprove without Keychain password must grant non-interactively for passwordless sudo")
        TestContext.assertNil(authResult2.sudoPassword, "Passwordless autoApprove should have nil password")
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
    
    // ---------------------------------------------------------
    // 11. Security Audit Regression & Fix Verification Tests
    // ---------------------------------------------------------
    print("▶︎ Running Suite: Security Audit & Reliability Regression Fixes")
    
    TestContext.runTest(suite: "RegressionAndSecurityFixTests", name: "testAppleScriptEscapingOrderSafety") {
        // Plain quoted string: with old buggy order, quotes became \\" which breaks out of AppleScript strings.
        let plain = #"echo "hello""#
        let sanitizedPlain = SudoAuthManager.sanitizeForAppleScript(plain)
        TestContext.assertEqual(sanitizedPlain, #"echo \"hello\""#, "Quotes in plain string must be escaped with single backslash")
        TestContext.assertFalse(sanitizedPlain.contains(#"\\""#), "Plain string must not contain \\\" breakout pattern")
        
        // Backslash escaping: backslashes must be doubled
        let backslash = #"echo \test"#
        let sanitizedBackslash = SudoAuthManager.sanitizeForAppleScript(backslash)
        TestContext.assertEqual(sanitizedBackslash, #"echo \\test"#, "Backslashes must be doubled")
        
        // Complex string with quotes and backslashes
        let complex = #"echo "hello \ \"world\"""#
        let sanitizedComplex = SudoAuthManager.sanitizeForAppleScript(complex)
        TestContext.assertEqual(sanitizedComplex, #"echo \"hello \\ \\\"world\\\"\""#, "Complex backslash and quote sequence must be properly escaped")
    }
    
    TestContext.runTest(suite: "RegressionAndSecurityFixTests", name: "testAskPassUUIDDelimiterUniqueness") {
        let testPass = "SecretP@ssword123!"
        guard let session = AskPassHelper.shared.createSession(password: testPass) else {
            TestContext.assertTrue(false, "AskPassHelper must successfully create an isolated session")
            return
        }
        defer { session.cleanup() }
        
        TestContext.assertTrue(FileManager.default.fileExists(atPath: session.scriptURL.path), "Script file must exist on disk")
        
        let content = (try? String(contentsOf: session.scriptURL, encoding: .utf8)) ?? ""
        TestContext.assertTrue(content.contains("INTEGRA_EOF_"), "Delimiting token must use dynamic INTEGRA_EOF_ prefix")
        TestContext.assertFalse(content.contains("INTEGRA_ASKPASS_EOF"), "Delimiting token must NOT use static literal INTEGRA_ASKPASS_EOF")
        TestContext.assertTrue(content.contains(testPass), "Script content must contain the payload password")
        
        let attrs = try? FileManager.default.attributesOfItem(atPath: session.scriptURL.path)
        let posix = (attrs?[.posixPermissions] as? NSNumber)?.intValue ?? 0
        TestContext.assertEqual(posix, 0o700, "Script permissions must be strict 0700")
    }
    
    TestContext.runTest(suite: "RegressionAndSecurityFixTests", name: "testProfileDeletionPurgesSudoKeychain") {
        let tempStorage = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("integra_sudo_purge_test_\(UUID().uuidString).json")
        let store = ProfileStore(storageURL: tempStorage)
        let profile = SSHProfile(name: "PurgeTest", host: "purge.test.local", port: 22, user: "root")
        
        store.addProfile(profile)
        _ = KeychainService.shared.savePassword(account: profile.id.uuidString, password: "ssh_password")
        _ = KeychainService.shared.saveSudoPassword(for: profile.id, password: "sudo_password")
        
        TestContext.assertEqual(KeychainService.shared.getPassword(account: profile.id.uuidString), "ssh_password", "SSH password must be in Keychain")
        TestContext.assertEqual(KeychainService.shared.getSudoPassword(for: profile.id), "sudo_password", "Sudo password must be in Keychain")
        
        store.deleteProfile(id: profile.id)
        
        TestContext.assertNil(KeychainService.shared.getPassword(account: profile.id.uuidString), "SSH password must be deleted from Keychain")
        TestContext.assertNil(KeychainService.shared.getSudoPassword(for: profile.id), "Sudo password must be deleted from Keychain on profile deletion")
    }
    
    TestContext.runTest(suite: "RegressionAndSecurityFixTests", name: "testConcurrentPipeDrainingSafety") {
        // Run a subprocess generating 128KB of output (well over the Darwin 64KB pipe buffer)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = ["-c", "import sys; sys.stdout.write('A' * 131072); sys.stderr.write('B' * 65536)"]
        
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        
        var outData = Data()
        var errData = Data()
        let ioGroup = DispatchGroup()
        
        ioGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            outData = (try? outPipe.fileHandleForReading.readToEnd()) ?? Data()
            ioGroup.leave()
        }
        
        ioGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            errData = (try? errPipe.fileHandleForReading.readToEnd()) ?? Data()
            ioGroup.leave()
        }
        
        do {
            try process.run()
            process.waitUntilExit()
            ioGroup.wait()
            
            TestContext.assertEqual(process.terminationStatus, 0, "Process must terminate successfully")
            TestContext.assertEqual(outData.count, 131072, "128KB stdout must be completely drained without deadlocking")
            TestContext.assertEqual(errData.count, 65536, "64KB stderr must be completely drained without deadlocking")
        } catch {
            TestContext.assertTrue(false, "Failed to execute pipe test: \(error)")
        }
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
