import Foundation

public enum AuthMethod: String, Codable, CaseIterable, Identifiable {
    case none = "Tailscale / SSH Agent"
    case key = "SSH Key"
    case password = "Password"
    
    public var id: String { self.rawValue }
}

public struct PortTunnelRule: Identifiable, Codable, Equatable {
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

public struct SSHProfile: Identifiable, Codable, Equatable {
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
        self.createdAt = createdAt
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
    
    public var controlSocketPath: String {
        let socketDir = "\(NSHomeDirectory())/.ssh/integra/sockets"
        return "\(socketDir)/integra_\(id.uuidString.lowercased()).sock"
    }
    
    public var controlMountMapPath: String {
        let socketDir = "\(NSHomeDirectory())/.ssh/integra/sockets"
        return "\(socketDir)/integra_\(id.uuidString.lowercased()).mount"
    }
}
