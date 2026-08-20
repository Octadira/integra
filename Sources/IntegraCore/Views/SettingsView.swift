import SwiftUI
import AppKit

public struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var depService: DependencyService
    @EnvironmentObject var recoveryService: NetworkRecoveryService
    @ObservedObject var mcpConfig = MCPConfigService.shared
    @ObservedObject var updateChecker = UpdateCheckerService.shared
    
    @State private var autoUnmountOnSleep = true
    @State private var showSavedToast = false
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Hero Header
                HStack(spacing: 16) {
                    Image(nsImage: NSImage(contentsOfFile: (Bundle.main.resourcePath ?? "") + "/AppIcon.icns") ?? NSImage(named: NSImage.applicationIconName) ?? NSImage())
                        .resizable()
                        .frame(width: 54, height: 54)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("Integra Settings")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("v0.15.1")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.15))
                                .foregroundColor(.accentColor)
                                .clipShape(Capsule())
                        }
                        Text("Configure your default development tools, network recovery, mount points, and system engine.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.bottom, 4)
                
                Divider()
                
                // Section: System & Startup Preferences
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("System & Startup Preferences", systemImage: "macwindow")
                            .font(.headline)
                        Spacer()
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(isOn: $settings.launchAtLogin) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Launch Integra at macOS Login")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("Automatically start Integra in the background when you log into your Mac so your remote drives, tunnels, and AI bridge are immediately ready.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(10)
                }
                
                // Section: Network Recovery & Auto-Healing
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Network Recovery & Auto-Healing", systemImage: "network.badge.shield.half.filled")
                            .font(.headline)
                        Spacer()
                        
                        HStack(spacing: 6) {
                            Circle()
                                .fill(recoveryService.isRecovering ? Color.orange : (recoveryService.isNetworkAvailable ? Color.green : Color.red))
                                .frame(width: 8, height: 8)
                            Text(recoveryService.isRecovering ? (recoveryService.recoveryStatusMessage ?? "Recovering...") : (recoveryService.isNetworkAvailable ? "Network Active (Monitoring)" : "Network Offline"))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(recoveryService.isRecovering ? .orange : (recoveryService.isNetworkAvailable ? .green : .red))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(Capsule())
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(isOn: $settings.autoReconnectOnRecovery) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Automatic Exponential Backoff Reconnection")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("Automatically restores active SSHFS connections when your Mac wakes from sleep, recovers from signal drops, or switches between Wi-Fi networks.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(10)
                }
                
                // Section: Developer & AI Agent Tools
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Developer & AI Agent Tools", systemImage: "sparkles")
                            .font(.headline)
                        Spacer()
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $settings.enableDeveloperAITools) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Enable AI Bridge & Model Context Protocol (MCP)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("Exposes native MCP tools for Claude Desktop, Cursor, Antigravity 2.0, VS Code, and Pi.dev, plus SSH Port Forwarding for local LLMs and databases.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if settings.enableDeveloperAITools {
                            Divider()
                                .padding(.vertical, 2)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("AI Integration Mode")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Picker("", selection: $settings.aiIntegrationMode) {
                                    ForEach(AIIntegrationMode.allCases) { mode in
                                        HStack {
                                            Image(systemName: mode.icon)
                                            Text(mode.rawValue)
                                        }
                                        .tag(mode)
                                    }
                                }
                                .pickerStyle(.menu)
                                
                                Text(settings.aiIntegrationMode.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Divider()
                                .padding(.vertical, 2)
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("1-Click MCP Client Auto-Configuration")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text("Registers the 'integra-mcp' tool provider with all installed AI assistants on your Mac.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button(action: {
                                    withAnimation(.spring()) {
                                        mcpConfig.installAllDetectedClients()
                                    }
                                }) {
                                    if mcpConfig.isConfiguring {
                                        HStack(spacing: 4) {
                                            ProgressView()
                                                .controlSize(.small)
                                            Text("Configuring...")
                                        }
                                    } else {
                                        Label("Auto-Configure All", systemImage: "bolt.fill")
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .disabled(mcpConfig.isConfiguring)
                            }
                            
                            if let success = mcpConfig.lastSuccessMessage {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(.green)
                                        .font(.body)
                                    Text(success)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Button(action: {
                                        withAnimation {
                                            mcpConfig.lastSuccessMessage = nil
                                        }
                                    }) {
                                        Image(systemName: "xmark")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(10)
                                .background(Color.green.opacity(0.12))
                                .cornerRadius(8)
                                .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
                            }
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(10)
                }
                
                // Section: Default Terminal
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Default Terminal Application", systemImage: "terminal.fill")
                            .font(.headline)
                        Spacer()
                    }
                    
                    Text("Select the terminal emulator launched when opening SSH terminal sessions.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                        ForEach(TerminalApp.allCases) { terminal in
                            AppSelectionCard(
                                title: terminal.rawValue,
                                subtitle: terminalSubtitle(for: terminal),
                                icon: terminal.icon,
                                isSelected: settings.preferredTerminal == terminal
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    settings.preferredTerminal = terminal
                                }
                            }
                        }
                    }
                }
                
                // Section: Default Code Editor / IDE
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Default Code Editor / IDE", systemImage: "chevron.left.forwardslash.chevron.right")
                            .font(.headline)
                        Spacer()
                    }
                    
                    Text("Select the IDE opened when clicking the Editor quick action on mounted servers.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                        ForEach(CodeEditorApp.allCases) { editor in
                            AppSelectionCard(
                                title: editor.rawValue,
                                subtitle: editorSubtitle(for: editor),
                                icon: editor.icon,
                                isSelected: settings.preferredEditor == editor
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    settings.preferredEditor = editor
                                }
                            }
                        }
                    }
                }
                
                // Section: Mount Preferences
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Filesystem & Mount Directory", systemImage: "externaldrive.fill")
                            .font(.headline)
                        Spacer()
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Default Local Mount Base Path")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text(settings.defaultMountsFolder)
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                            
                            Button("Browse...") {
                                selectFolder { path in
                                    settings.defaultMountsFolder = path
                                    withAnimation {
                                        showSavedToast = true
                                    }
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(10)
                }
                
                // Section: Engine & Architecture Status Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Filesystem Engine Status", systemImage: "shield.checkerboard")
                            .font(.headline)
                        Spacer()
                    }
                    
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(depService.allInstalled ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: depService.allInstalled ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .font(.title2)
                                .foregroundColor(depService.allInstalled ? .green : .orange)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(depService.allInstalled ? "FUSE-T Engine Ready (KEXT-free)" : "FUSE-T Dependencies Incomplete")
                                .font(.headline)
                            Text("User-space NFS server emulation. Works seamlessly without Kernel Extensions or SIP degradation on Apple Silicon & Intel.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(10)
                }
                
                // Section: Software Updates
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Software Updates", systemImage: "arrow.triangle.2.circlepath.circle")
                            .font(.headline)
                        Spacer()
                        
                        Button(action: {
                            Task {
                                await updateChecker.checkForUpdates(manual: true)
                            }
                        }) {
                            if updateChecker.isChecking {
                                HStack(spacing: 4) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Checking...")
                                }
                            } else {
                                Label("Check for Updates", systemImage: "arrow.clockwise")
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(updateChecker.isChecking)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(updateChecker.updateAvailable ? Color.blue.opacity(0.15) : Color.green.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Image(systemName: updateChecker.updateAvailable ? "sparkles" : "checkmark.seal.fill")
                                    .font(.title3)
                                    .foregroundColor(updateChecker.updateAvailable ? .blue : .green)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                if let msg = updateChecker.statusMessage {
                                    Text(msg)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                } else {
                                    Text("Integra is up to date (v\(UpdateCheckerService.currentVersion)).")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                
                                if let lastDate = updateChecker.lastCheckDate {
                                    Text("Last checked: \(lastDate.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Automatic background checks run daily.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            if updateChecker.updateAvailable, let newVer = updateChecker.latestVersion {
                                Text(newVer)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.blue.opacity(0.15))
                                    .foregroundColor(.blue)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(10)
                }
            }
            .padding(28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func terminalSubtitle(for app: TerminalApp) -> String {
        switch app {
        case .terminal: return "macOS Native"
        case .ghostty: return "GPU Accelerated"
        case .iTerm2: return "Power User Terminal"
        case .warp: return "Modern Terminal"
        }
    }
    
    private func editorSubtitle(for app: CodeEditorApp) -> String {
        switch app {
        case .vsCode: return "Microsoft VS Code"
        case .cursor: return "AI Code Editor"
        case .antigravity: return "Google AI Agent IDE"
        case .codex: return "OpenAI / ChatGPT Code Agent"
        case .windsurf: return "Codeium AI Code Editor"
        case .kiro: return "AWS Spec-Driven AI IDE"
        case .zed: return "High-Performance Code Editor"
        case .openCode: return "Autonomous AI Coding Agent"
        }
    }
    
    private func selectFolder(completion: @escaping (String) -> Void) {
        let panel = NSOpenPanel()
        panel.title = "Select Default Mount Directory"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            completion(url.path)
        }
    }
}

public struct AppSelectionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    let onSelect: () -> Void
    
    public var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .accentColor)
                    .frame(width: 32, height: 32)
                    .background(isSelected ? Color.accentColor : Color.accentColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(isSelected ? .primary : .primary)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.headline)
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
