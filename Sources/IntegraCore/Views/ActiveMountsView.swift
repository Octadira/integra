import SwiftUI

public struct ActiveMountsView: View {
    @EnvironmentObject var store: ProfileStore
    @EnvironmentObject var sshfsService: SSHFSService
    @EnvironmentObject var settings: AppSettings
    
    @State private var unmountingProfileId: UUID?
    @State private var aiToolsProfile: SSHProfile?
    @State private var errorMessage: String?
    @State private var showErrorAlert = false
    
    private var mountedProfiles: [SSHProfile] {
        store.profiles.filter { sshfsService.isProfileMounted($0) }
    }
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Active Mounts")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("\(mountedProfiles.count) active")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(mountedProfiles.isEmpty ? Color.gray.opacity(0.15) : Color.green.opacity(0.15))
                            .foregroundColor(mountedProfiles.isEmpty ? .secondary : .green)
                            .clipShape(Capsule())
                    }
                    
                    Text("Live mounted filesystems currently accessible on your Mac")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                if !mountedProfiles.isEmpty {
                    Button(role: .destructive, action: unmountAll) {
                        Label("Unmount All", systemImage: "eject.circle.fill")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            
            Divider()
            
            if mountedProfiles.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 80, height: 80)
                        Image(systemName: "externaldrive.badge.xmark")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary)
                    }
                    
                    Text("No Active Mounts")
                        .font(.headline)
                    Text("Connect to any of your saved SSH servers from the Connections tab to view and manage active mounts here.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(mountedProfiles) { profile in
                            ActiveMountCardView(
                                profile: profile,
                                isUnmounting: unmountingProfileId == profile.id,
                                onUnmount: { unmount(profile, force: false) },
                                onForceUnmount: { unmount(profile, force: true) },
                                onToggleDesktopShortcut: { toggleDesktopShortcut(profile) },
                                onOpenAITools: { aiToolsProfile = profile }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .sheet(item: $aiToolsProfile) { profile in
            AIToolsModalView(profile: profile)
        }
        .alert("Mount Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An error occurred during unmount.")
        }
    }
    
    private func toggleDesktopShortcut(_ profile: SSHProfile) {
        var updated = profile
        updated.createDesktopShortcut.toggle()
        store.updateProfile(updated)
        
        if updated.createDesktopShortcut {
            DesktopShortcutService.shared.createShortcut(for: updated)
        } else {
            DesktopShortcutService.shared.removeShortcut(for: updated)
        }
    }
    
    private func unmount(_ profile: SSHProfile, force: Bool) {
        unmountingProfileId = profile.id
        Task {
            do {
                try await sshfsService.unmount(profile: profile, force: force)
                unmountingProfileId = nil
            } catch {
                unmountingProfileId = nil
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
    }
    
    private func unmountAll() {
        Task {
            for profile in mountedProfiles {
                try? await sshfsService.unmount(profile: profile, force: false)
            }
        }
    }
}

public struct ActiveMountCardView: View {
    @EnvironmentObject var settings: AppSettings
    let profile: SSHProfile
    let isUnmounting: Bool
    let onUnmount: () -> Void
    let onForceUnmount: () -> Void
    let onToggleDesktopShortcut: () -> Void
    let onOpenAITools: () -> Void
    
    public var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: "externaldrive.fill.badge.checkmark")
                    .font(.headline)
                    .foregroundColor(.green)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(profile.name)
                        .font(.headline)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Mounted")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.12))
                    .clipShape(Capsule())
                }
                
                Text("Local Path: \(profile.defaultMountPath)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                
                Text("Remote: \(profile.effectiveUser)@\(profile.host):\(profile.remotePath)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                
                Divider()
                    .padding(.vertical, 4)
                
                HStack(spacing: 10) {
                    Button(action: { TerminalService.shared.openInFinder(path: profile.defaultMountPath) }) {
                        Label("Finder", systemImage: "folder.fill")
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: { TerminalService.shared.openSSHTerminal(profile: profile, terminal: settings.preferredTerminal) }) {
                        Label(settings.preferredTerminal.rawValue, systemImage: settings.preferredTerminal.icon)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: { TerminalService.shared.openInEditor(path: profile.defaultMountPath, editor: settings.preferredEditor) }) {
                        Label(settings.preferredEditor.rawValue, systemImage: settings.preferredEditor.icon)
                    }
                    .buttonStyle(.bordered)
                    
                    // Desktop shortcut button
                    Button(action: onToggleDesktopShortcut) {
                        Label(
                            profile.createDesktopShortcut ? "Desktop: ON" : "Desktop",
                            systemImage: "display"
                        )
                    }
                    .buttonStyle(.bordered)
                    .tint(profile.createDesktopShortcut ? .accentColor : .secondary)
                    .help(profile.createDesktopShortcut ? "Desktop shortcut is active. Click to remove." : "Click to create a Desktop shortcut for this server.")
                    
                    // AI Tools Button (Visible when Developer Tools enabled in Settings)
                    if settings.enableDeveloperAITools {
                        Button(action: onOpenAITools) {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.accentColor)
                                Text("AI Tools")
                            }
                        }
                        .buttonStyle(.bordered)
                        .help("Manage SSH Port Tunnels and remote command execution for AI agents")
                    }
                    
                    Spacer()
                    
                    Menu {
                        if settings.enableDeveloperAITools {
                            Button("AI Tools & Port Tunnels...", action: onOpenAITools)
                            Divider()
                        }
                        
                        Menu("Open in Terminal...") {
                            ForEach(TerminalApp.allCases) { terminal in
                                Button(terminal.rawValue) {
                                    TerminalService.shared.openSSHTerminal(profile: profile, terminal: terminal)
                                }
                            }
                        }
                        
                        Menu("Open in Editor / IDE...") {
                            ForEach(CodeEditorApp.allCases) { editor in
                                Button(editor.rawValue) {
                                    TerminalService.shared.openInEditor(path: profile.defaultMountPath, editor: editor)
                                }
                            }
                        }
                        
                        Divider()
                        Button("Force Unmount", action: onForceUnmount)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 24)
                    
                    if isUnmounting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Button(action: onUnmount) {
                            Label("Unmount", systemImage: "eject.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(0.4), lineWidth: 1)
        )
    }
}
