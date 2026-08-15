import Foundation
import SwiftUI

public enum TerminalApp: String, CaseIterable, Identifiable, Codable {
    case terminal = "Terminal"
    case ghostty = "Ghostty"
    case iTerm2 = "iTerm2"
    case warp = "Warp"
    
    public var id: String { self.rawValue }
    
    public var icon: String {
        switch self {
        case .terminal: return "terminal"
        case .ghostty: return "terminal.fill"
        case .iTerm2: return "terminal.circle"
        case .warp: return "bolt.horizontal"
        }
    }
}

public enum CodeEditorApp: String, CaseIterable, Identifiable, Codable {
    case vsCode = "VS Code"
    case cursor = "Cursor"
    case antigravity = "Antigravity 2.0 IDE"
    
    public var id: String { self.rawValue }
    
    public var icon: String {
        switch self {
        case .vsCode: return "chevron.left.forwardslash.chevron.right"
        case .cursor: return "cursorarrow.rays"
        case .antigravity: return "atom"
        }
    }
}

@MainActor
public class AppSettings: ObservableObject {
    public static let shared = AppSettings()
    
    @Published public var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "Integra_launchAtLogin")
            LaunchAtLoginService.shared.setLaunchAtLogin(enabled: launchAtLogin)
        }
    }
    
    @Published public var preferredTerminal: TerminalApp {
        didSet {
            UserDefaults.standard.set(preferredTerminal.rawValue, forKey: "Integra_preferredTerminal")
        }
    }
    
    @Published public var preferredEditor: CodeEditorApp {
        didSet {
            UserDefaults.standard.set(preferredEditor.rawValue, forKey: "Integra_preferredEditor")
        }
    }
    
    @Published public var autoReconnectOnRecovery: Bool {
        didSet {
            UserDefaults.standard.set(autoReconnectOnRecovery, forKey: "Integra_autoReconnectOnRecovery")
        }
    }
    
    @Published public var enableDeveloperAITools: Bool {
        didSet {
            UserDefaults.standard.set(enableDeveloperAITools, forKey: "Integra_enableDeveloperAITools")
        }
    }
    
    public init() {
        if UserDefaults.standard.object(forKey: "Integra_launchAtLogin") != nil {
            self.launchAtLogin = UserDefaults.standard.bool(forKey: "Integra_launchAtLogin")
        } else {
            self.launchAtLogin = true // Default ON as requested
            LaunchAtLoginService.shared.setLaunchAtLogin(enabled: true)
        }
        
        let savedTerminal = UserDefaults.standard.string(forKey: "Integra_preferredTerminal") ?? TerminalApp.terminal.rawValue
        self.preferredTerminal = TerminalApp(rawValue: savedTerminal) ?? .terminal
        
        let savedEditor = UserDefaults.standard.string(forKey: "Integra_preferredEditor") ?? CodeEditorApp.vsCode.rawValue
        self.preferredEditor = CodeEditorApp(rawValue: savedEditor) ?? .vsCode
        
        if UserDefaults.standard.object(forKey: "Integra_autoReconnectOnRecovery") != nil {
            self.autoReconnectOnRecovery = UserDefaults.standard.bool(forKey: "Integra_autoReconnectOnRecovery")
        } else {
            self.autoReconnectOnRecovery = true
        }
        
        self.enableDeveloperAITools = UserDefaults.standard.bool(forKey: "Integra_enableDeveloperAITools")
    }
}
