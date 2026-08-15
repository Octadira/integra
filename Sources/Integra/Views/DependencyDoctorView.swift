import SwiftUI
import AppKit

public struct DependencyDoctorView: View {
    @EnvironmentObject var depService: DependencyService
    @State private var copiedToClipboard = false
    
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
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Automatic Installation via Universal PKG")
                                .font(.headline)
                        }
                        Text("Click 'Open Installer Script in Terminal' to automatically download and install official FUSE-T and SSHFS packages on macOS.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 12) {
                            Button(action: {
                                runCommandScriptInTerminal()
                            }) {
                                Label("Open Installer Script in Terminal", systemImage: "terminal.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button(action: {
                                let script = depService.generateInstallScript()
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(script, forType: .string)
                                copiedToClipboard = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    copiedToClipboard = false
                                }
                            }) {
                                Label(copiedToClipboard ? "Copied!" : "Copy Install Script", systemImage: copiedToClipboard ? "checkmark" : "doc.on.doc")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
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
