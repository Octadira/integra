import SwiftUI
import AppKit

public struct ProfileEditView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: ProfileStore
    
    var existingProfile: SSHProfile?
    
    @State private var name: String = ""
    @State private var host: String = ""
    @State private var portString: String = "22"
    @State private var user: String = ""
    @State private var authMethod: AuthMethod = .none
    @State private var remotePath: String = "/"
    @State private var localPath: String = ""
    @State private var identityFile: String = "~/.ssh/id_rsa"
    @State private var passwordInput: String = ""
    @State private var autoMount: Bool = false
    @State private var createDesktopShortcut: Bool = false
    @State private var isShowingRemoteBrowser: Bool = false
    
    @State private var validationError: String?
    
    public init(profile: SSHProfile? = nil) {
        self.existingProfile = profile
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Modal Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(existingProfile == nil ? "New Connection Profile" : "Edit Connection Profile")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("Configure SSHFS remote server connection parameters")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button("Save Profile") {
                    save()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(16)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Section 1: Server Connection Info
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Server Connection Info", systemImage: "server.rack")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Profile Name")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("e.g. My Tailscale Server, Production Web", text: $name)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Host / IP Address *")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                TextField("e.g. 100.x.y.z or server.example.com", text: $host)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Port")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("22", text: $portString)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 70)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Username (Optional)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("Leave empty to use current macOS user (\(NSUserName()))", text: $user)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(10)
                    
                    // Section 2: Authentication Method
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Authentication Method", systemImage: "key.fill")
                            .font(.headline)
                        
                        Picker("Authentication Mode", selection: $authMethod) {
                            ForEach(AuthMethod.allCases) { method in
                                Text(method.rawValue).tag(method)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        switch authMethod {
                        case .none:
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.shield.fill")
                                    .foregroundColor(.accentColor)
                                Text("Ideal for Tailscale SSH networks or active local SSH Agent. No passwords or private key files required.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 4)
                            
                        case .key:
                            VStack(alignment: .leading, spacing: 8) {
                                Text("SSH Private Key Path")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                HStack {
                                    TextField("~/.ssh/id_rsa", text: $identityFile)
                                        .textFieldStyle(.roundedBorder)
                                    Button("Browse...") {
                                        selectKeyFile()
                                    }
                                    .buttonStyle(.bordered)
                                }
                                
                                Text("Key Passphrase (Optional, saved securely in Keychain)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                SecureField("Enter passphrase if your key is encrypted", text: $passwordInput)
                                    .textFieldStyle(.roundedBorder)
                            }
                            .padding(.top, 4)
                            
                        case .password:
                            VStack(alignment: .leading, spacing: 6) {
                                Text("SSH Password (Saved securely in macOS Keychain)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                SecureField("Enter SSH remote login password", text: $passwordInput)
                                    .textFieldStyle(.roundedBorder)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(10)
                    
                    // Section 3: Filesystem Paths
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Filesystem Paths", systemImage: "folder.fill")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Remote Path on Server")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack {
                                TextField("/ (Root) or /var/www, /home/user", text: $remotePath)
                                    .textFieldStyle(.roundedBorder)
                                
                                Button {
                                    isShowingRemoteBrowser = true
                                } label: {
                                    Label("Browse...", systemImage: "folder.badge.gearshape")
                                }
                                .buttonStyle(.bordered)
                                .disabled(host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                .help(host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Enter Server Host before browsing" : "Browse remote directories on server")
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Custom Local Mount Path (Optional)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack {
                                TextField("Defaults to \(AppSettings.currentMountsFolder)/\(name.isEmpty ? "Server" : name)", text: $localPath)
                                    .textFieldStyle(.roundedBorder)
                                Button("Browse...") {
                                    selectMountFolder()
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(10)
                    
                    // Section 4: Options
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Mount & Desktop Options", systemImage: "gearshape.fill")
                            .font(.headline)
                        
                        Toggle(isOn: $createDesktopShortcut) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Create Desktop Shortcut when mounted")
                                    .font(.subheadline)
                                Text("Automatically places ~/Desktop/\(name.isEmpty ? "Server" : name) on mount and cleans it up on unmount.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Divider()
                        
                        Toggle(isOn: $autoMount) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Auto-mount on Integra startup")
                                    .font(.subheadline)
                                Text("Automatically mounts this connection whenever Integra launches.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(10)
                    
                    if let error = validationError {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 560, height: 600)
        .sheet(isPresented: $isShowingRemoteBrowser) {
            RemoteDirectoryPickerView(
                host: host,
                port: Int(portString) ?? 22,
                user: user,
                authMethod: authMethod,
                identityFile: identityFile,
                password: passwordInput.isEmpty ? nil : passwordInput,
                selectedPath: $remotePath
            )
        }
        .onAppear {
            if let p = existingProfile {
                name = p.name
                host = p.host
                portString = "\(p.port)"
                user = p.user
                authMethod = p.authMethod
                remotePath = p.remotePath
                localPath = p.localPath
                identityFile = p.identityFile
                autoMount = p.autoMount
                createDesktopShortcut = p.createDesktopShortcut
                if p.authMethod == .password || p.authMethod == .key {
                    passwordInput = KeychainService.shared.getPassword(account: p.id.uuidString) ?? ""
                }
            }
        }
    }
    
    private func save() {
        guard !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            validationError = "Please enter a valid Host or Tailscale IP address."
            return
        }
        
        let port = Int(portString) ?? 22
        let profileName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? host : name
        
        var profile = existingProfile ?? SSHProfile()
        profile.name = profileName
        profile.host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.port = port
        profile.user = user.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.authMethod = authMethod
        profile.remotePath = remotePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "/" : remotePath
        profile.localPath = localPath.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.identityFile = identityFile
        profile.autoMount = autoMount
        profile.createDesktopShortcut = createDesktopShortcut
        
        if existingProfile != nil {
            store.updateProfile(profile)
        } else {
            store.addProfile(profile)
        }
        
        if (authMethod == .password || authMethod == .key) && !passwordInput.isEmpty {
            _ = KeychainService.shared.savePassword(account: profile.id.uuidString, password: passwordInput)
        }
        
        dismiss()
    }
    
    private func selectKeyFile() {
        let panel = NSOpenPanel()
        panel.title = "Select SSH Private Key"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        if panel.runModal() == .OK, let url = panel.url {
            identityFile = url.path
        }
    }
    
    private func selectMountFolder() {
        let panel = NSOpenPanel()
        panel.title = "Select Local Mount Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            localPath = url.path
        }
    }
}
