import Foundation
import AppKit

public enum SupportedAIClient: String, CaseIterable, Identifiable {
    case claudeDesktop = "Claude Desktop"
    case cursor = "Cursor"
    case antigravity = "Antigravity 2.0 (Google)"
    case vsCode = "VS Code"
    case windsurf = "Windsurf"
    case cline = "Cline"
    case rooCode = "Roo Code"
    case continueDev = "Continue.dev"
    case piDev = "Pi.dev"
    case zed = "Zed"
    
    public var id: String { self.rawValue }
    
    public var icon: String {
        switch self {
        case .claudeDesktop: return "message.badge.filled.fill"
        case .cursor: return "cursorarrow.rays"
        case .antigravity: return "atom"
        case .vsCode: return "chevron.left.forwardslash.chevron.right"
        case .windsurf: return "wind"
        case .cline: return "terminal.fill"
        case .rooCode: return "hare.fill"
        case .continueDev: return "play.circle.fill"
        case .piDev: return "number.circle.fill"
        case .zed: return "z.circle.fill"
        }
    }
    
    public var configPath: String {
        let home = NSHomeDirectory()
        switch self {
        case .claudeDesktop:
            return "\(home)/Library/Application Support/Claude/claude_desktop_config.json"
        case .cursor:
            return "\(home)/.cursor/mcp.json"
        case .antigravity:
            return "\(home)/.gemini/config/mcp_config.json"
        case .vsCode:
            return "\(home)/Library/Application Support/Code/User/globalStorage/mcp.json"
        case .windsurf:
            return "\(home)/.codeium/windsurf/mcp_config.json"
        case .cline:
            return "\(home)/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json"
        case .rooCode:
            return "\(home)/Library/Application Support/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/cline_mcp_settings.json"
        case .continueDev:
            return "\(home)/.continue/config.json"
        case .piDev:
            return "\(home)/.pi/mcp.json"
        case .zed:
            return "\(home)/.config/zed/settings.json"
        }
    }
    
    public var isInstalledOrConfigPresent: Bool {
        let path = configPath
        let parentDir = (path as NSString).deletingLastPathComponent
        return FileManager.default.fileExists(atPath: path) || FileManager.default.fileExists(atPath: parentDir)
    }
}

@MainActor
public class MCPConfigService: ObservableObject {
    public static let shared = MCPConfigService()
    
    @Published public var clientStatus: [SupportedAIClient: Bool] = [:]
    
    public static var binaryPath: String {
        let appBundlePath = "/Applications/Integra.app/Contents/MacOS/integra-mcp"
        if FileManager.default.fileExists(atPath: appBundlePath) {
            return appBundlePath
        }
        let localBin = "\(NSHomeDirectory())/.local/bin/integra-mcp"
        if FileManager.default.fileExists(atPath: localBin) {
            return localBin
        }
        return appBundlePath
    }
    
    public init() {
        refreshAllStatus()
    }
    
    public func refreshAllStatus() {
        for client in SupportedAIClient.allCases {
            clientStatus[client] = isClientConfigured(client)
        }
    }
    
    public func isClientConfigured(_ client: SupportedAIClient) -> Bool {
        let path = client.configPath
        guard FileManager.default.fileExists(atPath: path),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        
        if client == .zed {
            if let servers = json["context_servers"] as? [String: Any], servers["integra"] != nil {
                return true
            }
            return false
        }
        
        if let servers = json["mcpServers"] as? [String: Any], servers["integra"] != nil {
            return true
        }
        return false
    }
    
    public func installMCPConfig(for client: SupportedAIClient) -> Result<Void, Error> {
        let path = client.configPath
        let parentDir = (path as NSString).deletingLastPathComponent
        
        do {
            if !FileManager.default.fileExists(atPath: parentDir) {
                try FileManager.default.createDirectory(atPath: parentDir, withIntermediateDirectories: true)
            }
            
            var rootDict: [String: Any] = [:]
            if FileManager.default.fileExists(atPath: path),
               let existingData = try? Data(contentsOf: URL(fileURLWithPath: path)),
               let existingJson = try? JSONSerialization.jsonObject(with: existingData) as? [String: Any] {
                rootDict = existingJson
            }
            
            let integraEntry: [String: Any] = [
                "command": MCPConfigService.binaryPath,
                "args": [] as [String]
            ]
            
            if client == .zed {
                var contextServers = rootDict["context_servers"] as? [String: Any] ?? [:]
                contextServers["integra"] = [
                    "command": MCPConfigService.binaryPath,
                    "args": [] as [String]
                ]
                rootDict["context_servers"] = contextServers
            } else {
                var mcpServers = rootDict["mcpServers"] as? [String: Any] ?? [:]
                mcpServers["integra"] = integraEntry
                rootDict["mcpServers"] = mcpServers
            }
            
            let updatedData = try JSONSerialization.data(withJSONObject: rootDict, options: [.prettyPrinted, .sortedKeys])
            try updatedData.write(to: URL(fileURLWithPath: path), options: .atomic)
            
            if client == .antigravity {
                let secondaryPath = "\(NSHomeDirectory())/.gemini/antigravity/mcp_config.json"
                try? updatedData.write(to: URL(fileURLWithPath: secondaryPath), options: .atomic)
            }
            
            clientStatus[client] = true
            return .success(())
        } catch {
            return .failure(error)
        }
    }
    
    public func removeMCPConfig(for client: SupportedAIClient) -> Result<Void, Error> {
        let path = client.configPath
        guard FileManager.default.fileExists(atPath: path),
              let existingData = try? Data(contentsOf: URL(fileURLWithPath: path)),
              var rootDict = (try? JSONSerialization.jsonObject(with: existingData)) as? [String: Any] else {
            clientStatus[client] = false
            return .success(())
        }
        
        do {
            if client == .zed {
                if var contextServers = rootDict["context_servers"] as? [String: Any] {
                    contextServers.removeValue(forKey: "integra")
                    rootDict["context_servers"] = contextServers
                }
            } else {
                if var mcpServers = rootDict["mcpServers"] as? [String: Any] {
                    mcpServers.removeValue(forKey: "integra")
                    rootDict["mcpServers"] = mcpServers
                }
            }
            
            let updatedData = try JSONSerialization.data(withJSONObject: rootDict, options: [.prettyPrinted, .sortedKeys])
            try updatedData.write(to: URL(fileURLWithPath: path), options: .atomic)
            
            clientStatus[client] = false
            return .success(())
        } catch {
            return .failure(error)
        }
    }
    
    public func installAllDetectedClients() {
        for client in SupportedAIClient.allCases {
            if client.isInstalledOrConfigPresent {
                _ = installMCPConfig(for: client)
            }
        }
    }
}
