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

public struct SettingsData: Codable {
    public var launchAtLogin: Bool
    public var preferredTerminal: TerminalApp
    public var preferredEditor: CodeEditorApp
    public var autoReconnectOnRecovery: Bool
    public var enableDeveloperAITools: Bool
    public var defaultMountsFolder: String
    
    public init(
        launchAtLogin: Bool = true,
        preferredTerminal: TerminalApp = .terminal,
        preferredEditor: CodeEditorApp = .vsCode,
        autoReconnectOnRecovery: Bool = true,
        enableDeveloperAITools: Bool = false,
        defaultMountsFolder: String = "\(NSHomeDirectory())/Mounts"
    ) {
        self.launchAtLogin = launchAtLogin
        self.preferredTerminal = preferredTerminal
        self.preferredEditor = preferredEditor
        self.autoReconnectOnRecovery = autoReconnectOnRecovery
        self.enableDeveloperAITools = enableDeveloperAITools
        self.defaultMountsFolder = defaultMountsFolder
    }
}

@MainActor
public class AppSettings: ObservableObject {
    public static let shared = AppSettings()
    
    // Thread-safe lock and cache for background processes accessing mount base directory
    private nonisolated static let lock = NSLock()
    private nonisolated(unsafe) static var _cachedMountsFolder: String = "\(NSHomeDirectory())/Mounts"
    
    public nonisolated static var currentMountsFolder: String {
        lock.lock()
        defer { lock.unlock() }
        return _cachedMountsFolder
    }
    
    @Published public var launchAtLogin: Bool {
        didSet {
            saveSettings()
            LaunchAtLoginService.shared.setLaunchAtLogin(enabled: launchAtLogin)
        }
    }
    
    @Published public var preferredTerminal: TerminalApp {
        didSet {
            saveSettings()
        }
    }
    
    @Published public var preferredEditor: CodeEditorApp {
        didSet {
            saveSettings()
        }
    }
    
    @Published public var autoReconnectOnRecovery: Bool {
        didSet {
            saveSettings()
        }
    }
    
    @Published public var enableDeveloperAITools: Bool {
        didSet {
            saveSettings()
        }
    }
    
    @Published public var defaultMountsFolder: String {
        didSet {
            AppSettings.lock.lock()
            AppSettings._cachedMountsFolder = defaultMountsFolder
            AppSettings.lock.unlock()
            saveSettings()
        }
    }
    
    private var applicationSupportURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let integraDir = appSupport.appendingPathComponent("Integra", isDirectory: true)
        if !FileManager.default.fileExists(atPath: integraDir.path) {
            try? FileManager.default.createDirectory(at: integraDir, withIntermediateDirectories: true)
        }
        return integraDir.appendingPathComponent("settings.json")
    }
    
    public init() {
        let defaultPath = "\(NSHomeDirectory())/Mounts"
        
        // 1. Try loading from persistent Application Support settings.json
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let fileURL = appSupport.appendingPathComponent("Integra", isDirectory: true).appendingPathComponent("settings.json")
        
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(SettingsData.self, from: data) {
            self.launchAtLogin = decoded.launchAtLogin
            self.preferredTerminal = decoded.preferredTerminal
            self.preferredEditor = decoded.preferredEditor
            self.autoReconnectOnRecovery = decoded.autoReconnectOnRecovery
            self.enableDeveloperAITools = decoded.enableDeveloperAITools
            self.defaultMountsFolder = decoded.defaultMountsFolder
            
            AppSettings.lock.lock()
            AppSettings._cachedMountsFolder = decoded.defaultMountsFolder
            AppSettings.lock.unlock()
            return
        }
        
        // 2. Fallback to UserDefaults for legacy migration
        if UserDefaults.standard.object(forKey: "Integra_launchAtLogin") != nil {
            self.launchAtLogin = UserDefaults.standard.bool(forKey: "Integra_launchAtLogin")
        } else {
            self.launchAtLogin = true
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
        
        let savedMount = UserDefaults.standard.string(forKey: "Integra_defaultMountsFolder") ?? defaultPath
        self.defaultMountsFolder = savedMount
        
        AppSettings.lock.lock()
        AppSettings._cachedMountsFolder = savedMount
        AppSettings.lock.unlock()
        
        saveSettings() // Migrate to JSON file immediately
    }
    
    private func saveSettings() {
        let data = SettingsData(
            launchAtLogin: launchAtLogin,
            preferredTerminal: preferredTerminal,
            preferredEditor: preferredEditor,
            autoReconnectOnRecovery: autoReconnectOnRecovery,
            enableDeveloperAITools: enableDeveloperAITools,
            defaultMountsFolder: defaultMountsFolder
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let encoded = try? encoder.encode(data) {
            try? encoded.write(to: applicationSupportURL, options: .atomic)
        }
        
        // Also sync to UserDefaults as secondary backup
        UserDefaults.standard.set(launchAtLogin, forKey: "Integra_launchAtLogin")
        UserDefaults.standard.set(preferredTerminal.rawValue, forKey: "Integra_preferredTerminal")
        UserDefaults.standard.set(preferredEditor.rawValue, forKey: "Integra_preferredEditor")
        UserDefaults.standard.set(autoReconnectOnRecovery, forKey: "Integra_autoReconnectOnRecovery")
        UserDefaults.standard.set(enableDeveloperAITools, forKey: "Integra_enableDeveloperAITools")
        UserDefaults.standard.set(defaultMountsFolder, forKey: "Integra_defaultMountsFolder")
    }
}
