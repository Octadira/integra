import SwiftUI

public struct ProfileListView: View {
    @EnvironmentObject var store: ProfileStore
    @EnvironmentObject var sshfsService: SSHFSService
    @EnvironmentObject var depService: DependencyService
    @EnvironmentObject var settings: AppSettings
    
    @State private var showingAddSheet = false
    @State private var editingProfile: SSHProfile?
    @State private var aiToolsProfile: SSHProfile?
    @State private var mountingProfileId: UUID?
    @State private var errorMessage: String?
    @State private var showErrorAlert = false
    
    // Search & Filter State
    @State private var searchText = ""
    @State private var selectedAuthFilter: AuthFilterCategory = .all
    
    enum AuthFilterCategory: String, CaseIterable, Identifiable {
        case all = "All"
        case tailscale = "Tailscale"
        case sshKey = "SSH Key"
        case password = "Password"
        
        var id: String { self.rawValue }
    }
    
    private var filteredProfiles: [SSHProfile] {
        store.profiles.filter { profile in
            // Search filter
            let matchesSearch: Bool
            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                matchesSearch = true
            } else {
                let query = searchText.lowercased()
                matchesSearch = profile.name.lowercased().contains(query) ||
                                profile.host.lowercased().contains(query) ||
                                profile.user.lowercased().contains(query)
            }
            
            // Category filter
            let matchesCategory: Bool
            switch selectedAuthFilter {
            case .all:
                matchesCategory = true
            case .tailscale:
                matchesCategory = (profile.authMethod == .none)
            case .sshKey:
                matchesCategory = (profile.authMethod == .key)
            case .password:
                matchesCategory = (profile.authMethod == .password)
            }
            
            return matchesSearch && matchesCategory
        }
    }
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Bar
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connections")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("\(store.profiles.count) saved servers")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { showingAddSheet = true }) {
                    Label("Add Server", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            .padding(.top)
            .padding(.bottom, 8)
            
            // Search & Filter Controls
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search by name, host IP, or user...", text: $searchText)
                        .textFieldStyle(.plain)
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                
                // Auth Category Segmented Filter
                Picker("Filter", selection: $selectedAuthFilter) {
                    ForEach(AuthFilterCategory.allCases) { cat in
                        Text(cat.rawValue).tag(cat)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            Divider()
            
            // Main List Area
            if store.profiles.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.1))
                            .frame(width: 80, height: 80)
                        Image(systemName: "server.rack")
                            .font(.system(size: 36))
                            .foregroundColor(.accentColor)
                    }
                    
                    Text("No Servers Added Yet")
                        .font(.headline)
                    Text("Click 'Add Server' or import your existing SSH hosts from ~/.ssh/config to get started.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 360)
                    
                    HStack(spacing: 12) {
                        Button("Import ~/.ssh/config") {
                            store.importSSHConfigEntries()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Add Server") {
                            showingAddSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredProfiles.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No connections match '\(searchText)'")
                        .font(.headline)
                    Button("Clear Search") {
                        searchText = ""
                        selectedAuthFilter = .all
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredProfiles) { profile in
                            ProfileCardView(
                                profile: profile,
                                isMounted: sshfsService.isProfileMounted(profile),
                                isConnecting: mountingProfileId == profile.id,
                                onMount: { mount(profile) },
                                onUnmount: { unmount(profile, force: false) },
                                onForceUnmount: { unmount(profile, force: true) },
                                onToggleDesktopShortcut: { toggleDesktopShortcut(profile) },
                                onOpenAITools: { aiToolsProfile = profile },
                                onEdit: { editingProfile = profile },
                                onDelete: { store.deleteProfile(id: profile.id) }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            ProfileEditView()
        }
        .sheet(item: $editingProfile) { profile in
            ProfileEditView(profile: profile)
        }
        .sheet(item: $aiToolsProfile) { profile in
            AIToolsModalView(profile: profile)
        }
        .alert("Mount Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Failed to perform SSHFS operation.")
        }
    }
    
    private func toggleDesktopShortcut(_ profile: SSHProfile) {
        var updated = profile
        updated.createDesktopShortcut.toggle()
        store.updateProfile(updated)
        
        if sshfsService.isProfileMounted(profile) {
            if updated.createDesktopShortcut {
                DesktopShortcutService.shared.createShortcut(for: updated)
            } else {
                DesktopShortcutService.shared.removeShortcut(for: updated)
            }
        }
    }
    
    private func mount(_ profile: SSHProfile) {
        mountingProfileId = profile.id
        Task {
            do {
                try await sshfsService.mount(profile: profile)
                mountingProfileId = nil
            } catch {
                mountingProfileId = nil
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
    }
    
    private func unmount(_ profile: SSHProfile, force: Bool) {
        mountingProfileId = profile.id
        Task {
            do {
                try await sshfsService.unmount(profile: profile, force: force)
                mountingProfileId = nil
            } catch {
                mountingProfileId = nil
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
    }
}

public struct ProfileCardView: View {
    @EnvironmentObject var settings: AppSettings
    
    let profile: SSHProfile
    let isMounted: Bool
    let isConnecting: Bool
    let onMount: () -> Void
    let onUnmount: () -> Void
    let onForceUnmount: () -> Void
    let onToggleDesktopShortcut: () -> Void
    let onOpenAITools: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    public var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(isMounted ? Color.green.opacity(0.15) : Color.gray.opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: isMounted ? "externaldrive.fill.badge.checkmark" : "server.rack")
                    .font(.headline)
                    .foregroundColor(isMounted ? .green : .secondary)
            }
            .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(profile.name)
                        .font(.headline)
                    
                    Spacer()
                    
                    Text(profile.authMethod.rawValue)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.12))
                        .foregroundColor(.accentColor)
                        .clipShape(Capsule())
                    
                    if isMounted {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
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
                }
                
                Text("\(profile.user.isEmpty ? "default" : profile.user)@\(profile.host):\(profile.port)\(profile.remotePath)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(profile.defaultMountPath)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.top, 2)
                
                Divider()
                    .padding(.vertical, 4)
                
                HStack(spacing: 10) {
                    if isMounted {
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
                    }
                    
                    // Desktop shortcut button
                    Button(action: onToggleDesktopShortcut) {
                        Label(
                            profile.createDesktopShortcut ? "Desktop: ON" : "Desktop",
                            systemImage: "display"
                        )
                    }
                    .buttonStyle(.bordered)
                    .tint(profile.createDesktopShortcut ? .accentColor : .secondary)
                    .help(profile.createDesktopShortcut ? "Desktop shortcut is active. Click to disable." : "Click to automatically create a Desktop shortcut when mounted.")
                    
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
                        
                        if isMounted {
                            Menu("Open in Terminal...") {
                                ForEach(TerminalApp.allCases) { terminal in
                                    Button(terminal.rawValue) {
                                        TerminalService.shared.openSSHTerminal(profile: profile, terminal: terminal)
                                    }
                                }
                            }
                            
                            Menu("Open in IDE / Editor...") {
                                ForEach(CodeEditorApp.allCases) { editor in
                                    Button(editor.rawValue) {
                                        TerminalService.shared.openInEditor(path: profile.defaultMountPath, editor: editor)
                                    }
                                }
                            }
                            
                            Divider()
                            Button("Force Unmount", action: onForceUnmount)
                            Divider()
                        }
                        
                        Button("Edit Profile", action: onEdit)
                        Divider()
                        Button("Delete Profile", role: .destructive, action: onDelete)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 24)
                    
                    if isConnecting {
                        ProgressView()
                            .controlSize(.small)
                    } else if isMounted {
                        Button(action: onUnmount) {
                            Label("Unmount", systemImage: "eject.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    } else {
                        Button(action: onMount) {
                            Label("Mount", systemImage: "externaldrive.badge.plus")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isMounted ? Color.green.opacity(0.4) : Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}
