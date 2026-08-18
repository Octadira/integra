import SwiftUI
import AppKit

public struct AIToolsModalView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: ProfileStore
    @EnvironmentObject var tunnelService: SSHTunnelService
    @EnvironmentObject var execService: RemoteExecService
    
    @State var profile: SSHProfile
    @State private var selectedTab: AIToolTab = .portTunnels
    
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
    
    enum AIToolTab: String, CaseIterable, Identifiable {
        case portTunnels = "SSH Port Tunnels"
        case remoteExec = "Command Bridge (integra-exec)"
        
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
                    Text("Port forwarding and remote command execution for \(profile.name)")
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
            
            // Tab Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedTab {
                    case .portTunnels:
                        portTunnelsView
                    case .remoteExec:
                        remoteExecView
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 620, height: 600)
        .alert("Tunnel Error", isPresented: $showTunnelErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(tunnelErrorMessage ?? "Failed to manage SSH Port Tunnel.")
        }
    }
    
    // MARK: - Port Tunnels Tab
    private var portTunnelsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Master Action Banner
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(tunnelService.isTunnelRunning(for: profile.id) ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                        Text(tunnelService.isTunnelRunning(for: profile.id) ? "Tunnels Active" : "Tunnels Inactive")
                            .font(.headline)
                            .foregroundColor(tunnelService.isTunnelRunning(for: profile.id) ? .green : .primary)
                    }
                    Text(tunnelService.isTunnelRunning(for: profile.id) ? "Forwarding ports to local loopback (127.0.0.1)" : "Start forwarding to allow AI agents to connect to remote APIs & DBs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if tunnelService.isTunnelRunning(for: profile.id) {
                    Button(action: stopTunnels) {
                        Label("Stop Tunnels", systemImage: "stop.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                } else {
                    Button(action: startTunnels) {
                        Label("Start Tunnels", systemImage: "bolt.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(profile.portTunnels.filter { $0.isEnabled }.isEmpty)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            
            // Quick Presets
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Add Presets")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    presetButton(name: "Ollama AI", localPort: 11434, remotePort: 11434, icon: "atom")
                    presetButton(name: "PostgreSQL", localPort: 5432, remotePort: 5432, icon: "cylinder.split.1x2")
                    presetButton(name: "Redis", localPort: 6379, remotePort: 6379, icon: "bolt.horizontal")
                    presetButton(name: "Web (8080)", localPort: 8080, remotePort: 8080, icon: "globe")
                }
            }
            
            // Active Endpoints List
            if tunnelService.isTunnelRunning(for: profile.id) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Live Local Endpoints (Copy for AI Agents)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                    
                    ForEach(profile.portTunnels.filter { $0.isEnabled }) { rule in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rule.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("http://127.0.0.1:\(rule.localPort)  ➔  remote :\(rule.remotePort)")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                let ep = "http://127.0.0.1:\(rule.localPort)"
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(ep, forType: .string)
                                copiedEndpoint = rule.name
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                    copiedEndpoint = nil
                                }
                            }) {
                                Label(copiedEndpoint == rule.name ? "Copied!" : "Copy Endpoint", systemImage: copiedEndpoint == rule.name ? "checkmark" : "doc.on.doc")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(10)
                        .background(Color.green.opacity(0.08))
                        .cornerRadius(8)
                    }
                }
            }
            
            // Configured Rules
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Configured Port Rules (\(profile.portTunnels.count))")
                        .font(.headline)
                    Spacer()
                    Button(action: { showingAddRuleSheet = true }) {
                        Label("Add Custom Rule", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                if profile.portTunnels.isEmpty {
                    Text("No port forwarding rules configured. Add a preset above or click 'Add Custom Rule'.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(profile.portTunnels) { rule in
                        HStack(spacing: 12) {
                            Toggle("", isOn: Binding(
                                get: { rule.isEnabled },
                                set: { newVal in
                                    toggleRule(rule.id, enabled: newVal)
                                }
                            ))
                            .labelsHidden()
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rule.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("Local: \(rule.localPort)  ➔  \(rule.remoteHost):\(rule.remotePort)")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button(role: .destructive, action: { deleteRule(rule.id) }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(10)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddRuleSheet) {
            addRuleSheet
        }
    }
    
    // MARK: - Remote Command Exec Tab
    private var remoteExecView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Control Socket Status
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(execService.isSocketActive(for: profile) ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                        Text(execService.isSocketActive(for: profile) ? "SSH Control Master Socket Active" : "Control Socket Inactive")
                            .font(.headline)
                            .foregroundColor(execService.isSocketActive(for: profile) ? .green : .primary)
                    }
                    Text(execService.isSocketActive(for: profile) ? "Persistent zero-latency command multiplexing ready for integra-exec." : "Connect socket to enable sub-5ms command execution without repeated SSH handshakes.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if execService.isSocketActive(for: profile) {
                    Button("Disconnect Socket") {
                        execService.stopControlSocket(for: profile)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Connect Socket") {
                        Task { @MainActor in
                            do {
                                try await execService.startControlSocket(for: profile)
                            } catch {
                                testOutput = "Socket Connection Error: \(error.localizedDescription)"
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            
            // Agent Instruction Snippet Card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("AI Agent Integration Guide", systemImage: "text.book.closed.fill")
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
                        Label(copiedAgentGuide ? "Copied Guide!" : "Copy Instructions for Agent", systemImage: copiedAgentGuide ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                Text("When working inside \(profile.defaultMountPath), your AI agent (Antigravity 2.0, Cursor, CLI) can run commands on the remote Linux host simply with:")
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
