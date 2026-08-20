import Foundation

public enum AuthMethod: String, Codable, CaseIterable, Identifiable, Sendable {
    case none = "Tailscale / SSH Agent"
    case key = "SSH Key"
    case password = "Password"
    
    public var id: String { self.rawValue }
}

public enum SudoAuthPolicy: String, Codable, CaseIterable, Identifiable, Sendable {
    case sessionCache = "Ask Once per Session (15m Cache)"
    case touchIDOrPrompt = "Always Ask (Touch ID / Prompt)"
    case autoApprove = "Auto-Approve from Keychain"
    
    public var id: String { self.rawValue }
    
    public var icon: String {
        switch self {
        case .sessionCache: return "timer"
        case .touchIDOrPrompt: return "touchid"
        case .autoApprove: return "bolt.shield.fill"
        }
    }
}

public struct PortTunnelRule: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var localPort: Int
    public var remotePort: Int
    public var remoteHost: String
    public var isEnabled: Bool
    
    public init(
        id: UUID = UUID(),
        name: String = "",
        localPort: Int = 8080,
        remotePort: Int = 8080,
        remoteHost: String = "127.0.0.1",
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.localPort = localPort
        self.remotePort = remotePort
        self.remoteHost = remoteHost
        self.isEnabled = isEnabled
    }
}

public struct SSHProfile: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var host: String
    public var port: Int
    public var user: String
    public var authMethod: AuthMethod
    public var remotePath: String
    public var localPath: String
    public var identityFile: String
    public var autoMount: Bool
    public var createDesktopShortcut: Bool
    public var portTunnels: [PortTunnelRule]
    public var useSSHPasswordForSudo: Bool
    public var sudoAuthPolicy: SudoAuthPolicy
    public var createdAt: Date
    
    public init(
        id: UUID = UUID(),
        name: String = "",
        host: String = "",
        port: Int = 22,
        user: String = "",
        authMethod: AuthMethod = .none,
        remotePath: String = "/",
        localPath: String = "",
        identityFile: String = "~/.ssh/id_rsa",
        autoMount: Bool = false,
        createDesktopShortcut: Bool = false,
        portTunnels: [PortTunnelRule] = [],
        useSSHPasswordForSudo: Bool = true,
        sudoAuthPolicy: SudoAuthPolicy = .sessionCache,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.user = user
        self.authMethod = authMethod
        self.remotePath = remotePath
        self.localPath = localPath
        self.identityFile = identityFile
        self.autoMount = autoMount
        self.createDesktopShortcut = createDesktopShortcut
        self.portTunnels = portTunnels
        self.useSSHPasswordForSudo = useSSHPasswordForSudo
        self.sudoAuthPolicy = sudoAuthPolicy
        self.createdAt = createdAt
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        host = try container.decodeIfPresent(String.self, forKey: .host) ?? ""
        port = try container.decodeIfPresent(Int.self, forKey: .port) ?? 22
        user = try container.decodeIfPresent(String.self, forKey: .user) ?? ""
        authMethod = try container.decodeIfPresent(AuthMethod.self, forKey: .authMethod) ?? .none
        remotePath = try container.decodeIfPresent(String.self, forKey: .remotePath) ?? "/"
        localPath = try container.decodeIfPresent(String.self, forKey: .localPath) ?? ""
        identityFile = try container.decodeIfPresent(String.self, forKey: .identityFile) ?? "~/.ssh/id_rsa"
        autoMount = try container.decodeIfPresent(Bool.self, forKey: .autoMount) ?? false
        createDesktopShortcut = try container.decodeIfPresent(Bool.self, forKey: .createDesktopShortcut) ?? false
        portTunnels = try container.decodeIfPresent([PortTunnelRule].self, forKey: .portTunnels) ?? []
        useSSHPasswordForSudo = try container.decodeIfPresent(Bool.self, forKey: .useSSHPasswordForSudo) ?? true
        sudoAuthPolicy = try container.decodeIfPresent(SudoAuthPolicy.self, forKey: .sudoAuthPolicy) ?? .sessionCache
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
    
    public var effectiveUser: String {
        let trimmed = user.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? NSUserName() : trimmed
    }
    
    public var defaultMountPath: String {
        if !localPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return (localPath as NSString).expandingTildeInPath
        }
        let sanitizedName = name.isEmpty ? host : name
        let safeName = sanitizedName.components(separatedBy: CharacterSet.alphanumerics.inverted).joined(separator: "_")
        let baseDir = AppSettings.currentMountsFolder
        return "\(baseDir)/\(safeName)"
    }
    
    public var desktopShortcutPath: String {
        let sanitizedName = name.isEmpty ? host : name
        let safeName = sanitizedName.replacingOccurrences(of: "/", with: "-").trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(NSHomeDirectory())/Desktop/\(safeName.isEmpty ? "Remote_Server" : safeName)"
    }
    
    public var shortId: String {
        return id.uuidString.replacingOccurrences(of: "-", with: "").prefix(12).lowercased()
    }
    
    public var controlSocketPath: String {
        let socketDir = "\(NSHomeDirectory())/.ssh/integra/sock"
        return "\(socketDir)/i_\(shortId).sock"
    }
    
    public var controlMountMapPath: String {
        let socketDir = "\(NSHomeDirectory())/.ssh/integra/sock"
        return "\(socketDir)/i_\(shortId).mount"
    }
    
    public func sanitizeIdentityFilePermissionsIfNeeded() {
        guard authMethod == .key else { return }
        let keyPath = (identityFile as NSString).expandingTildeInPath
        guard !keyPath.isEmpty, FileManager.default.fileExists(atPath: keyPath) else { return }
        
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: keyPath)
            if let posix = attrs[.posixPermissions] as? NSNumber, posix.intValue != 0o600 {
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: keyPath)
            }
        } catch {
            // Ignore if file cannot be modified (e.g. read-only volume or permission error)
        }
    }
}
