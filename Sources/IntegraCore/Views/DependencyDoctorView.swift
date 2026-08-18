import SwiftUI
import AppKit

public struct DependencyDoctorView: View {
    @EnvironmentObject var depService: DependencyService
    @State private var copiedToClipboard = false
    @State private var showAdvancedOptions = false
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("Dependency Doctor")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text(depService.allInstalled ? "All Systems Ready" : "Setup Required")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(depService.allInstalled ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                                .foregroundColor(depService.allInstalled ? .green : .orange)
                                .clipShape(Capsule())
                        }
                        
                        Text("Integra uses the kernel-free FUSE-T engine and SSHFS to mount remote filesystems.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    Button(action: {
                        Task {
                            await depService.checkAllDependencies()
                        }
                    }) {
                        Label("Check Status", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .disabled(depService.isInstalling)
                }
                .padding(.bottom, 4)
                
                Divider()
                
                // Diagnostic Cards
                VStack(spacing: 12) {
                    ForEach(depService.items) { item in
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(item.state.isInstalled ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                                    .frame(width: 42, height: 42)
                                Image(systemName: item.type.icon)
                                    .font(.headline)
                                    .foregroundColor(item.state.isInstalled ? .green : .orange)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(item.type.rawValue)
                                        .font(.headline)
                                    if item.type == .homebrew {
                                        Text("(Optional Helper)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Text(item.type.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            switch item.state {
                            case .checking:
                                ProgressView()
                                    .controlSize(.small)
                            case .installed(let path):
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Installed")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.green)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(6)
                                .help(path)
                            case .missing:
                                HStack(spacing: 6) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                    Text("Missing")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.red)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(6)
                            case .error(let msg):
                                Text("Error: \(msg)")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(12)
                    }
                }
                
                // Action Banner
                if !depService.allInstalled {
                    VStack(alignment: .leading, spacing: 14) {
                        if let err = depService.installErrorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "xmark.octagon.fill")
                                    .foregroundColor(.red)
                                Text(err)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        if depService.isInstalling {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 12) {
                                    ProgressView()
                                        .controlSize(.regular)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(depService.installStatusMessage ?? "Installing dependencies...")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text("Touch ID or password authorization will be requested by macOS.")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(10)
                        } else {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.accentColor)
                                Text("Automated 1-Click Installation")
                                    .font(.headline)
                            }
                            
                            Text("Download and install verified official FUSE-T and SSHFS packages directly in the app without opening Terminal.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 12) {
                                Button(action: {
                                    Task {
                                        await depService.installDependenciesAutomatically()
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.down.circle.fill")
                                        Text("Install Dependencies (1-Click)")
                                    }
                                    .fontWeight(.semibold)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                                
                                Button(action: {
                                    showAdvancedOptions.toggle()
                                }) {
                                    Label(showAdvancedOptions ? "Hide Advanced" : "Advanced Options", systemImage: "chevron.right")
                                }
                                .buttonStyle(.bordered)
                            }
                            
                            if showAdvancedOptions {
                                VStack(alignment: .leading, spacing: 10) {
                                    Divider()
                                    Text("Manual Terminal Fallback:")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                    
                                    HStack(spacing: 12) {
                                        Button(action: {
                                            runCommandScriptInTerminal()
                                        }) {
                                            Label("Open Script in Terminal", systemImage: "terminal")
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                        
                                        Button(action: {
                                            let script = depService.generateInstallScript()
                                            NSPasteboard.general.clearContents()
                                            NSPasteboard.general.setString(script, forType: .string)
                                            copiedToClipboard = true
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                                copiedToClipboard = false
                                            }
                                        }) {
                                            Label(copiedToClipboard ? "Copied!" : "Copy Raw Script", systemImage: copiedToClipboard ? "checkmark" : "doc.on.doc")
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.08))
                    .cornerRadius(12)
                } else {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("All system dependencies are installed and ready!")
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                            Text("Your Mac is fully configured to mount remote SSH & Tailscale filesystems seamlessly.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                }
                
                Spacer()
            }
            .padding(24)
        }
        .task {
            await depService.checkAllDependencies()
        }
    }
    
    private func runCommandScriptInTerminal() {
        let script = depService.generateInstallScript()
        let downloadsDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        let commandURL = downloadsDirectory.appendingPathComponent("Install_Integra_Dependencies.command")
        
        do {
            try script.write(to: commandURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: commandURL.path)
            NSWorkspace.shared.open(commandURL)
        } catch {
            print("[DependencyDoctorView] Error opening script: \(error)")
        }
    }
}
