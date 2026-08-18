import Foundation

public struct SSHConfigEntry: Equatable {
    public let host: String
    public let hostName: String?
    public let user: String?
    public let port: Int?
    public let identityFile: String?
    
    public init(
        host: String,
        hostName: String? = nil,
        user: String? = nil,
        port: Int? = nil,
        identityFile: String? = nil
    ) {
        self.host = host
        self.hostName = hostName
        self.user = user
        self.port = port
        self.identityFile = identityFile
    }
}

public class SSHConfigParser {
    public static func parseUserSSHConfig() -> [SSHConfigEntry] {
        let home = NSString(string: "~").expandingTildeInPath
        let configPath = "\(home)/.ssh/config"
        
        guard FileManager.default.fileExists(atPath: configPath),
              let content = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            return []
        }
        
        return parse(content: content)
    }
    
    public static func parse(content: String) -> [SSHConfigEntry] {
        var entries: [SSHConfigEntry] = []
        var currentHost: String?
        var hostName: String?
        var user: String?
        var port: Int?
        var identityFile: String?
        
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            
            let parts = trimmed.components(separatedBy: CharacterSet.whitespaces).filter { !$0.isEmpty }
            guard parts.count >= 2 else { continue }
            
            let key = parts[0].lowercased()
            let val = parts[1]
            
            if key == "host" {
                if let h = currentHost, h != "*" {
                    entries.append(SSHConfigEntry(host: h, hostName: hostName, user: user, port: port, identityFile: identityFile))
                }
                currentHost = val
                hostName = nil
                user = nil
                port = nil
                identityFile = nil
            } else if key == "hostname" {
                hostName = val
            } else if key == "user" {
                user = val
            } else if key == "port" {
                port = Int(val)
            } else if key == "identityfile" {
                identityFile = val
            }
        }
        
        if let h = currentHost, h != "*" {
            entries.append(SSHConfigEntry(host: h, hostName: hostName, user: user, port: port, identityFile: identityFile))
        }
        
        return entries
    }
}
