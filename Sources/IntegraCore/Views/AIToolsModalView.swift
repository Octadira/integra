import SwiftUI
import AppKit

public struct AIToolsModalView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: ProfileStore
    @EnvironmentObject var tunnelService: SSHTunnelService
    @EnvironmentObject var execService: RemoteExecService
    @ObservedObject var mcpConfig = MCPConfigService.shared
    
    @State var profile: SSHProfile
    @State private var selectedTab: AIToolTab = .mcpServer
    
    // Port Tunnel State
    @State private var newRuleName: String = ""
    @State private var newRuleLocalPort: String = "8080"
    @State private var newRuleRemotePort: String = "8080"
    @State private var newRuleRemoteHost: String = "127.0.0.1"
    @State private var showingAddRuleSheet = false
    
    @State private var tunnelErrorMessage: String?
    @State private var showTunnelErrorAlert = false
    @State private var copiedEndpoint: String?
    
    // Command Exec State
    @State private var testCommand: String = "uname -a"
    @State private var testOutput: String = ""
    @State private var isExecutingTest: Bool = false
    @State private var copiedAgentGuide: Bool = false
    @State private var copiedMCPJson: Bool = false
    
    enum AIToolTab: String, CaseIterable, Identifiable {
        case mcpServer = "Model Context Protocol (MCP)"
        case portTunnels = "SSH Port Tunnels"
        case remoteExec = "CLI Bridge (integra-exec)"
        
        var id: String { self.rawValue }
    }
    
    public init(profile: SSHProfile) {
        self._profile = State(initialValue: profile)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Modal Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.accentColor)
                            .font(.title3)
                        Text("AI Bridge & Developer Tools")
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                    Text("MCP server, port forwarding, and remote execution for \(profile.name)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(16)
            
            Divider()
            
            // Tab Selector
            Picker("Mode", selection: $selectedTab) {
                ForEach(AIToolTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
            // Content
            ScrollView {
                VStack(spacing: 16) {
                    switch selectedTab {
                    case .mcpServer:
                        mcpServerTab
                    case .portTunnels:
                        portTunnelsTab
                    case .remoteExec:
                        remoteExecTab
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 660, height: 600)
        .sheet(isPresented: $showingAddRuleSheet) {
            addRuleSheet
        }
        .alert("Tunnel Error", isPresented: $showTunnelErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(tunnelErrorMessage ?? "Failed to configure SSH port forwarding.")
        }
    }
    
    // MARK: - Tab 1: MCP Server
    private var mcpServerTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Hero info
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "atom")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Native MCP Server (Model Context Protocol)")
                        .font(.headline)
                    Text("Connects Claude Desktop, Cursor, Antigravity 2.0, VS Code, and Pi.dev directly to Integra with zero project file modifications.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            // 1-Click Auto Configure Section
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("1-Click IDE Configuration", systemImage: "bolt.fill")
                        .font(.headline)
                    Spacer()
                    Button(action: {
                        mcpConfig.installAllDetectedClients()
                    }) {
                        Label("Auto-Configure All", systemImage: "sparkles")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                
                Text("Select your AI coding assistants to automatically install the Integra MCP tool provider:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 8) {
                    ForEach(SupportedAIClient.allCases) { client in
                        clientRow(client)
                    }
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            // Exposed Tools Preview
            VStack(alignment: .leading, spacing: 8) {
                Label("Exposed Native AI Tools", systemImage: "wrench.and.screwdriver.fill")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 6) {
                    toolItem(name: "integra_execute_command", desc: "Executes shell commands on remote Linux servers with sub-5ms latency.")
                    toolItem(name: "integra_list_servers", desc: "Lists all configured and mounted SSHFS workspaces and paths.")
                    toolItem(name: "integra_get_tunnels", desc: "Provides active loopback endpoints (Ollama LLM, DBs, services).")
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            // Manual Configuration Snippet
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Manual JSON Configuration", systemImage: "curlybraces")
                        .font(.headline)
                    Spacer()
                    Button(action: {
                        let json = """
                        {
                          "mcpServers": {
                            "integra": {
                              "command": "\(MCPConfigService.binaryPath)",
                              "args": []
                            }
                          }
                        }
                        """
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(json, forType: .string)
                        copiedMCPJson = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            copiedMCPJson = false
                        }
                    }) {
                        Label(copiedMCPJson ? "Copied JSON!" : "Copy JSON Snippet", systemImage: copiedMCPJson ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                Text("For custom MCP clients, add this entry to your client configuration:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("{\n  \"mcpServers\": {\n    \"integra\": {\n      \"command\": \"\(MCPConfigService.binaryPath)\"\n    }\n  }\n}")
                    .font(.system(.caption, design: .monospaced))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(6)
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
    
    private func clientRow(_ client: SupportedAIClient) -> some View {
        let isConfigured = mcpConfig.isClientConfigured(client)
        let isPresent = client.isInstalledOrConfigPresent
        
        return HStack {
            Image(systemName: client.icon)
                .font(.body)
                .frame(width: 20)
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(client.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(client.configPath)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
            
            if isConfigured {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Configured")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                
                Button("Remove") {
                    _ = mcpConfig.removeMCPConfig(for: client)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            } else {
                Button(action: {
                    _ = mcpConfig.installMCPConfig(for: client)
                }) {
                    Text(isPresent ? "Install" : "Setup")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func toolItem(name: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "chevron.right.circle.fill")
                .foregroundColor(.accentColor)
                .font(.caption)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.semibold)
                Text(desc)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Tab 2: Port Tunnels
    private var portTunnelsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status & Action Banner
            HStack {
                let isMounted = SSHFSService.shared.isProfileMounted(profile)
                let isTunnelRunning = tunnelService.isTunnelRunning(for: profile.id)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isTunnelRunning ? Color.green : (isMounted ? Color.orange : Color.secondary))
                            .frame(width: 8, height: 8)
                        Text(isTunnelRunning ? "Port Forwarding Active" : (isMounted ? "Ready to forward ports" : "Mount server to forward ports"))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    Text("Tunnel remote AI and DB services securely to your local Mac.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                if isMounted {
                    if isTunnelRunning {
                        Button("Stop Tunnels") {
                            stopTunnels()
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    } else {
                        Button("Start Tunnels") {
                            startTunnels()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(profile.portTunnels.filter { $0.isEnabled }.isEmpty)
                    }
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            
            // AI Presets Bar
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Add Popular AI & Database Presets:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    presetButton(name: "Ollama (11434)", localPort: 11434, remotePort: 11434, icon: "atom")
                    presetButton(name: "vLLM / TGI (8000)", localPort: 8000, remotePort: 8000, icon: "cpu")
                    presetButton(name: "Postgres (5432)", localPort: 5432, remotePort: 5432, icon: "cylinder.split.1x2")
                    presetButton(name: "Redis (6379)", localPort: 6379, remotePort: 6379, icon: "memorychip")
                }
            }
            .padding(.vertical, 4)
            
            // Rules List
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Forwarding Rules (\(profile.portTunnels.count))", systemImage: "arrow.triangle.swap")
                        .font(.headline)
                    Spacer()
                    Button(action: { showingAddRuleSheet = true }) {
                        Label("Add Custom Rule", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                if profile.portTunnels.isEmpty {
                    Text("No port forwarding rules configured. Add a preset above or create a custom rule.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                } else {
                    ForEach(profile.portTunnels) { rule in
                        HStack {
                            Toggle("", isOn: Binding(
                                get: { rule.isEnabled },
                                set: { toggleRule(rule.id, enabled: $0) }
                            ))
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rule.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("127.0.0.1:\(rule.localPort) ➔ Remote :\(rule.remotePort) (\(rule.remoteHost))")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if tunnelService.isTunnelRunning(for: profile.id) && rule.isEnabled {
                                Button(action: {
                                    let url = "http://127.0.0.1:\(rule.localPort)"
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(url, forType: .string)
                                    copiedEndpoint = url
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        copiedEndpoint = nil
                                    }
                                }) {
                                    Image(systemName: copiedEndpoint == "http://127.0.0.1:\(rule.localPort)" ? "checkmark" : "doc.on.doc")
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                                .help("Copy local endpoint URL")
                            }
                            
                            Button(action: { deleteRule(rule.id) }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                }
            }
        }
    }
    
    // MARK: - Tab 3: CLI Remote Exec
    private var remoteExecTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("CLI Execution Bridge", systemImage: "terminal.fill")
                        .font(.headline)
                    Spacer()
                    Button(action: {
                        let guide = AgentInstructionService.shared.generateInstructions(for: profile)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(guide, forType: .string)
                        copiedAgentGuide = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            copiedAgentGuide = false
                        }
                    }) {
                        Label(copiedAgentGuide ? "Copied Guide!" : "Copy Instructions", systemImage: copiedAgentGuide ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                Text("For non-MCP terminal assistants, prefix local commands inside \(profile.defaultMountPath) with:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("integra-exec <command...>")
                    .font(.system(.subheadline, design: .monospaced))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(6)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            
            // Test Command Console Runner
            VStack(alignment: .leading, spacing: 8) {
                Label("Test Remote Command", systemImage: "play.circle.fill")
                    .font(.headline)
                
                HStack {
                    TextField("e.g. uname -a, docker ps, uptime, whoami", text: $testCommand)
                        .textFieldStyle(.roundedBorder)
                    
                    Button(action: executeTestCommand) {
                        if isExecutingTest {
                            HStack(spacing: 4) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Running...")
                            }
                        } else {
                            Text("Run")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(testCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isExecutingTest)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Terminal Console Output:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        if !testOutput.isEmpty {
                            Button("Clear") {
                                testOutput = ""
                            }
                            .buttonStyle(.plain)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        }
                    }
                    
                    ScrollView {
                        Text(testOutput.isEmpty ? "Click 'Run' to execute the command on \(profile.host)..." : testOutput)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(testOutput.isEmpty ? .secondary : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                    }
                    .frame(minHeight: 90, maxHeight: 150)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                }
                .padding(.top, 4)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
        }
    }
    
    // MARK: - Helpers & Actions
    private func presetButton(name: String, localPort: Int, remotePort: Int, icon: String) -> some View {
        Button(action: {
            addPresetRule(name: name, localPort: localPort, remotePort: remotePort)
        }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(name)
            }
            .font(.caption)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
    
    private func addPresetRule(name: String, localPort: Int, remotePort: Int) {
        let rule = PortTunnelRule(name: name, localPort: localPort, remotePort: remotePort, remoteHost: "127.0.0.1", isEnabled: true)
        profile.portTunnels.append(rule)
        store.updateProfile(profile)
    }
    
    private func toggleRule(_ id: UUID, enabled: Bool) {
        if let idx = profile.portTunnels.firstIndex(where: { $0.id == id }) {
            profile.portTunnels[idx].isEnabled = enabled
            store.updateProfile(profile)
        }
    }
    
    private func deleteRule(_ id: UUID) {
        profile.portTunnels.removeAll { $0.id == id }
        store.updateProfile(profile)
    }
    
    private func startTunnels() {
        Task {
            do {
                try await tunnelService.startTunnels(for: profile)
            } catch {
                tunnelErrorMessage = error.localizedDescription
                showTunnelErrorAlert = true
            }
        }
    }
    
    private func stopTunnels() {
        tunnelService.stopTunnels(for: profile)
    }
    
    private func executeTestCommand() {
        isExecutingTest = true
        testOutput = "Executing '\(testCommand)' on \(profile.host)..."
        Task { @MainActor in
            defer {
                self.isExecutingTest = false
            }
            let out = await execService.executeCommand(profile: profile, command: testCommand)
            self.testOutput = out
        }
    }
    
    private var addRuleSheet: some View {
        VStack(spacing: 16) {
            Text("Add Custom Port Forwarding Rule")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                TextField("Rule Name (e.g. FastAPI Backend)", text: $newRuleName)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    TextField("Local Port (e.g. 8000)", text: $newRuleLocalPort)
                        .textFieldStyle(.roundedBorder)
                    TextField("Remote Port", text: $newRuleRemotePort)
                        .textFieldStyle(.roundedBorder)
                }
                TextField("Remote Host (defaults to 127.0.0.1)", text: $newRuleRemoteHost)
                    .textFieldStyle(.roundedBorder)
            }
            
            HStack {
                Button("Cancel") { showingAddRuleSheet = false }
                    .buttonStyle(.bordered)
                Spacer()
                Button("Add Rule") {
                    let lp = Int(newRuleLocalPort) ?? 8080
                    let rp = Int(newRuleRemotePort) ?? lp
                    let rName = newRuleName.isEmpty ? "Port \(lp)" : newRuleName
                    let host = newRuleRemoteHost.isEmpty ? "127.0.0.1" : newRuleRemoteHost
                    let rule = PortTunnelRule(name: rName, localPort: lp, remotePort: rp, remoteHost: host, isEnabled: true)
                    profile.portTunnels.append(rule)
                    store.updateProfile(profile)
                    showingAddRuleSheet = false
                    newRuleName = ""
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 400)
    }
}
