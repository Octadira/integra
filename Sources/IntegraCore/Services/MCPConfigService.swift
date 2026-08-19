import Foundation
import AppKit

public enum SupportedAIClient: String, CaseIterable, Identifiable {
    case claudeCode = "Claude Code CLI"
    case claudeDesktop = "Claude Desktop"
    case cursor = "Cursor"
    case antigravity = "Antigravity 2.0 (Google)"
    case openCodeCLI = "OpenCode CLI"
    case openCodeDesktop = "OpenCode Desktop"
    case vsCode = "VS Code (Copilot / MCP)"
    case windsurf = "Windsurf"
    case cline = "Cline"
    case rooCode = "Roo Code"
    case continueDev = "Continue.dev"
    case piDev = "Pi.dev"
    case zed = "Zed"
    
    public var id: String { self.rawValue }
    
    public var icon: String {
        switch self {
        case .claudeCode: return "terminal.fill"
        case .claudeDesktop: return "message.badge.filled.fill"
        case .cursor: return "cursorarrow.rays"
        case .antigravity: return "atom"
        case .openCodeCLI: return "chevron.left.forwardslash.chevron.right"
        case .openCodeDesktop: return "macwindow"
        case .vsCode: return "chevron.left.forwardslash.chevron.right"
        case .windsurf: return "wind"
        case .cline: return "terminal.fill"
        case .rooCode: return "hare.fill"
        case .continueDev: return "play.circle.fill"
        case .piDev: return "number.circle.fill"
        case .zed: return "z.circle.fill"
        }
    }
    
    public var primaryConfigPath: String {
        let home = NSHomeDirectory()
        switch self {
        case .claudeCode:
            return "\(home)/.claude.json"
        case .claudeDesktop:
            return "\(home)/Library/Application Support/Claude/claude_desktop_config.json"
        case .cursor:
            return "\(home)/.cursor/mcp.json"
        case .antigravity:
            return "\(home)/.gemini/config/mcp_config.json"
        case .openCodeCLI:
            return "\(home)/.config/opencode/opencode.json"
        case .openCodeDesktop:
            return "\(home)/Library/Application Support/OpenCode/opencode.json"
        case .vsCode:
            return "\(home)/Library/Application Support/Code/User/mcp.json"
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
    
    public var secondaryConfigPaths: [String] {
        let home = NSHomeDirectory()
        switch self {
        case .antigravity:
            return ["\(home)/.gemini/antigravity/mcp_config.json"]
        case .claudeCode:
            return ["\(home)/.claude/settings.json"]
        case .vsCode:
            return ["\(home)/Library/Application Support/Code/User/globalStorage/mcp.json"]
        case .cursor:
            return ["\(home)/Library/Application Support/Cursor/User/globalStorage/cursor.mcp/mcp.json"]
        default:
            return []
        }
    }
    
    public var isInstalledOrConfigPresent: Bool {
        let path = primaryConfigPath
        let parentDir = (path as NSString).deletingLastPathComponent
        if FileManager.default.fileExists(atPath: path) || FileManager.default.fileExists(atPath: parentDir) {
            return true
        }
        for sec in secondaryConfigPaths {
            let secParent = (sec as NSString).deletingLastPathComponent
            if FileManager.default.fileExists(atPath: sec) || FileManager.default.fileExists(atPath: secParent) {
                return true
            }
        }
        return false
    }
}

@MainActor
public class MCPConfigService: ObservableObject {
    public static let shared = MCPConfigService()
    
    @Published public var clientStatus: [SupportedAIClient: Bool] = [:]
    @Published public var isConfiguring: Bool = false
    @Published public var lastSuccessMessage: String?
    @Published public var configuredCount: Int = 0
    
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
        let pathsToCheck = [client.primaryConfigPath] + client.secondaryConfigPaths
        
        for path in pathsToCheck {
            guard FileManager.default.fileExists(atPath: path),
                  let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }
            
            if client == .zed {
                if let servers = json["context_servers"] as? [String: Any], servers["integra"] != nil {
                    return true
                }
            } else if client == .vsCode {
                if let servers = json["servers"] as? [String: Any], servers["integra"] != nil {
                    return true
                }
                if let servers = json["mcpServers"] as? [String: Any], servers["integra"] != nil {
                    return true
                }
            } else if client == .openCodeCLI || client == .openCodeDesktop {
                if let mcp = json["mcp"] as? [String: Any],
                   let servers = mcp["servers"] as? [String: Any],
                   servers["integra"] != nil {
                    return true
                }
                return false
            } else {
                if let servers = json["mcpServers"] as? [String: Any], servers["integra"] != nil {
                    return true
                }
            }
        }
        return false
    }
    
    public func installMCPConfig(for client: SupportedAIClient) -> Result<Void, Error> {
        let allPaths = [client.primaryConfigPath] + client.secondaryConfigPaths
        var lastError: Error?
        
        for path in allPaths {
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
                
                let standardEntry: [String: Any] = [
                    "type": "stdio",
                    "command": MCPConfigService.binaryPath,
                    "args": [] as [String]
                ]
                
                if client == .zed {
                    var contextServers = rootDict["context_servers"] as? [String: Any] ?? [:]
                    contextServers["integra"] = standardEntry
                    rootDict["context_servers"] = contextServers
                } else if client == .vsCode {
                    var servers = rootDict["servers"] as? [String: Any] ?? [:]
                    servers["integra"] = standardEntry
                    rootDict["servers"] = servers
                    
                    var mcpServers = rootDict["mcpServers"] as? [String: Any] ?? [:]
                    mcpServers["integra"] = standardEntry
                    rootDict["mcpServers"] = mcpServers
                } else if client == .openCodeCLI || client == .openCodeDesktop {
                    var mcpDict = rootDict["mcp"] as? [String: Any] ?? ["enabled": true]
                    var servers = mcpDict["servers"] as? [String: Any] ?? [:]
                    servers["integra"] = [
                        "command": MCPConfigService.binaryPath,
                        "args": [] as [String]
                    ]
                    mcpDict["servers"] = servers
                    mcpDict["enabled"] = true
                    rootDict["mcp"] = mcpDict
                    rootDict.removeValue(forKey: "mcpServers")
                } else {
                    var mcpServers = rootDict["mcpServers"] as? [String: Any] ?? [:]
                    mcpServers["integra"] = standardEntry
                    rootDict["mcpServers"] = mcpServers
                }
                
                let updatedData = try JSONSerialization.data(withJSONObject: rootDict, options: [.prettyPrinted, .sortedKeys])
                try updatedData.write(to: URL(fileURLWithPath: path), options: .atomic)
            } catch {
                lastError = error
            }
        }
        
        clientStatus[client] = true
        if let err = lastError, !isClientConfigured(client) {
            return .failure(err)
        }
        return .success(())
    }
    
    public func removeMCPConfig(for client: SupportedAIClient) -> Result<Void, Error> {
        let allPaths = [client.primaryConfigPath] + client.secondaryConfigPaths
        
        for path in allPaths {
            guard FileManager.default.fileExists(atPath: path),
                  let existingData = try? Data(contentsOf: URL(fileURLWithPath: path)),
                  var rootDict = (try? JSONSerialization.jsonObject(with: existingData)) as? [String: Any] else {
                continue
            }
            
            if client == .zed {
                if var contextServers = rootDict["context_servers"] as? [String: Any] {
                    contextServers.removeValue(forKey: "integra")
                    rootDict["context_servers"] = contextServers
                }
            } else if client == .vsCode {
                if var servers = rootDict["servers"] as? [String: Any] {
                    servers.removeValue(forKey: "integra")
                    rootDict["servers"] = servers
                }
                if var mcpServers = rootDict["mcpServers"] as? [String: Any] {
                    mcpServers.removeValue(forKey: "integra")
                    rootDict["mcpServers"] = mcpServers
                }
            } else if client == .openCodeCLI || client == .openCodeDesktop {
                if var mcpDict = rootDict["mcp"] as? [String: Any],
                   var servers = mcpDict["servers"] as? [String: Any] {
                    servers.removeValue(forKey: "integra")
                    mcpDict["servers"] = servers
                    rootDict["mcp"] = mcpDict
                }
                rootDict.removeValue(forKey: "mcpServers")
            } else {
                if var mcpServers = rootDict["mcpServers"] as? [String: Any] {
                    mcpServers.removeValue(forKey: "integra")
                    rootDict["mcpServers"] = mcpServers
                }
            }
            
            let updatedData = try? JSONSerialization.data(withJSONObject: rootDict, options: [.prettyPrinted, .sortedKeys])
            try? updatedData?.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
        
        clientStatus[client] = false
        return .success(())
    }
    
    public func installAllDetectedClients() {
        isConfiguring = true
        lastSuccessMessage = nil
        var configuredNames: [String] = []
        
        Task { @MainActor in
            // Small simulated delay for smooth UI feedback
            try? await Task.sleep(nanoseconds: 350_000_000)
            
            for client in SupportedAIClient.allCases {
                if client.isInstalledOrConfigPresent {
                    let res = installMCPConfig(for: client)
                    if case .success = res {
                        configuredNames.append(client.rawValue)
                    }
                }
            }
            
            self.refreshAllStatus()
            self.configuredCount = configuredNames.count
            self.isConfiguring = false
            
            if !configuredNames.isEmpty {
                self.lastSuccessMessage = "Successfully configured Integra MCP across \(configuredNames.count) AI assistants: \(configuredNames.joined(separator: ", "))!"
            } else {
                self.lastSuccessMessage = "All supported AI assistant configurations are already up to date."
            }
        }
    }
}
