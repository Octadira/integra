import SwiftUI
import AppKit

public struct RemoteDirectoryPickerView: View {
    public let host: String
    public let port: Int
    public let user: String
    public let authMethod: AuthMethod
    public let identityFile: String
    public let password: String?
    
    @Binding public var selectedPath: String
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentPath: String
    @State private var items: [RemoteDirectoryItem] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var searchText: String = ""
    @State private var showHiddenFolders: Bool = false
    
    public init(
        host: String,
        port: Int,
        user: String,
        authMethod: AuthMethod,
        identityFile: String,
        password: String?,
        selectedPath: Binding<String>
    ) {
        self.host = host
        self.port = port
        self.user = user
        self.authMethod = authMethod
        self.identityFile = identityFile
        self.password = password
        self._selectedPath = selectedPath
        
        let initial = selectedPath.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        self._currentPath = State(initialValue: initial.isEmpty ? "/" : initial)
    }
    
    private var filteredItems: [RemoteDirectoryItem] {
        items.filter { item in
            if !showHiddenFolders && item.name.hasPrefix(".") {
                return false
            }
            if searchText.isEmpty {
                return true
            }
            return item.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerBar
            
            Divider()
            
            // Path Navigation & Quick Jump Toolbar
            navigationToolbar
            
            Divider()
            
            // Main Directory Content
            mainContentArea
            
            Divider()
            
            // Bottom Action Footer
            footerBar
        }
        .frame(width: 580, height: 480)
        .onAppear {
            loadDirectory(path: currentPath)
        }
    }
    
    // MARK: - Header Bar
    private var headerBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "server.rack")
                .font(.title2)
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Browse Remote Server")
                    .font(.headline)
                
                Text("\(user.isEmpty ? "default" : user)@\(host):\(port)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Navigation Toolbar
    private var navigationToolbar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                // Quick Jump: Root
                Button {
                    loadDirectory(path: "/")
                } label: {
                    Label("Root /", systemImage: "globe")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                // Quick Jump: Home
                Button {
                    loadDirectory(path: "~")
                } label: {
                    Label("Home ~", systemImage: "house")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                // Quick Jump: Parent Directory (Up)
                Button {
                    navigateUp()
                } label: {
                    Label("Up", systemImage: "arrow.up")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(currentPath == "/" || currentPath.isEmpty)
                
                Spacer()
                
                // Toggle Hidden Folders
                Toggle(isOn: $showHiddenFolders) {
                    Text("Hidden")
                        .font(.caption)
                }
                .toggleStyle(.checkbox)
                
                // Refresh Button
                Button {
                    loadDirectory(path: currentPath)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            // Path Breadcrumb / Current Path Display
            HStack(spacing: 6) {
                Image(systemName: "folder.fill")
                    .foregroundColor(.accentColor)
                    .font(.caption)
                
                TextField("Path", text: $currentPath)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit {
                        loadDirectory(path: currentPath)
                    }
                
                Button("Go") {
                    loadDirectory(path: currentPath)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            // Search / Filter bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.caption)
                
                TextField("Filter folders in current directory...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.caption)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
    
    // MARK: - Main Content Area
    private var mainContentArea: some View {
        ZStack {
            Color(NSColor.textBackgroundColor)
            
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading remote directories...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    
                    Text("Unable to list directory")
                        .font(.headline)
                    
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    
                    Button("Retry") {
                        loadDirectory(path: currentPath)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding()
            } else if filteredItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "folder")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No subdirectories found in this path")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text(currentPath)
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.8))
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(filteredItems) { item in
                            directoryRow(for: item)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    // MARK: - Directory Row
    private func directoryRow(for item: RemoteDirectoryItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.name.hasPrefix(".") ? "folder.badge.gearshape" : "folder.fill")
                .foregroundColor(item.name.hasPrefix(".") ? .secondary : .accentColor)
                .font(.body)
            
            Text(item.name)
                .font(.system(.body, design: .default))
                .foregroundColor(item.name.hasPrefix(".") ? .secondary : .primary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            // Double click: open folder
            loadDirectory(path: item.fullPath)
        }
        .onTapGesture(count: 1) {
            // Single click: update current path and open
            loadDirectory(path: item.fullPath)
        }
        .hoverEffect()
    }
    
    // MARK: - Footer Bar
    private var footerBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Selected Remote Mount Path:")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(currentPath)
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
            
            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            
            Button("Select This Path") {
                selectedPath = currentPath
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Directory Navigation Actions
    private func loadDirectory(path: String) {
        isLoading = true
        errorMessage = nil
        
        Task { @MainActor in
            do {
                let result = try await RemoteBrowserService.shared.listDirectories(
                    host: host,
                    port: port,
                    user: user,
                    authMethod: authMethod,
                    identityFile: identityFile,
                    password: password,
                    currentPath: path
                )
                self.currentPath = result.currentNormalizedPath
                self.items = result.items
                self.isLoading = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func navigateUp() {
        guard currentPath != "/" && !currentPath.isEmpty else { return }
        let parent = (currentPath as NSString).deletingLastPathComponent
        let target = parent.isEmpty ? "/" : parent
        loadDirectory(path: target)
    }
}

// Simple hover effect modifier for macOS
private struct HoverEffectModifier: ViewModifier {
    @State private var isHovered = false
    
    func body(content: Content) -> some View {
        content
            .background(isHovered ? Color.accentColor.opacity(0.12) : Color.clear)
            .cornerRadius(4)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

private extension View {
    func hoverEffect() -> some View {
        self.modifier(HoverEffectModifier())
    }
}
