import Foundation
import AppKit

public class TerminalService {
    public static let shared = TerminalService()
    
    private init() {}
    
    public func openInFinder(path: String) {
        let expanded = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded)
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
    }
    
    public func openSSHTerminal(profile: SSHProfile, terminal: TerminalApp = .terminal) {
        let userSpec = profile.effectiveUser
        let safeHost = profile.host.replacingOccurrences(of: "'", with: "'\\''")
        let safeUser = userSpec.replacingOccurrences(of: "'", with: "'\\''")
        let safeTitle = profile.name.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "$", with: "\\$").replacingOccurrences(of: "`", with: "\\`")
        
        var keyArg = ""
        if profile.authMethod == .key {
            let keyPath = (profile.identityFile as NSString).expandingTildeInPath
            if !keyPath.isEmpty {
                let safeKey = keyPath.replacingOccurrences(of: "'", with: "'\\''")
                keyArg = " -i '\(safeKey)'"
            }
        }
        let sshCmd = "ssh -p \(profile.port)\(keyArg) '\(safeUser)'@'\(safeHost)'"
        
        let tempScript = FileManager.default.temporaryDirectory.appendingPathComponent("launch_ssh_\(profile.id.uuidString).command")
        let scriptContent = """
        #!/bin/bash
        echo "=== Connecting to \(safeTitle) via SSH ==="
        exec \(sshCmd)
        """
        try? scriptContent.write(to: tempScript, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempScript.path)
        
        switch terminal {
        case .ghostty:
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            task.arguments = ["-a", "Ghostty", tempScript.path]
            try? task.run()
        case .iTerm2:
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            task.arguments = ["-a", "iTerm", tempScript.path]
            try? task.run()
        case .warp:
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            task.arguments = ["-a", "Warp", tempScript.path]
            try? task.run()
        case .terminal:
            NSWorkspace.shared.open(tempScript)
        }
    }
    
    public func openInEditor(path: String, editor: CodeEditorApp = .vsCode) {
        let expanded = (path as NSString).expandingTildeInPath
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        
        switch editor {
        case .vsCode:
            task.arguments = ["-a", "Visual Studio Code", expanded]
        case .cursor:
            task.arguments = ["-a", "Cursor", expanded]
        case .antigravity:
            // Check for Antigravity IDE (com.google.antigravity-ide / Antigravity IDE.app) first
            if NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.google.antigravity-ide") != nil {
                task.arguments = ["-b", "com.google.antigravity-ide", expanded]
            } else if FileManager.default.fileExists(atPath: "/Applications/Antigravity IDE.app") {
                task.arguments = ["-a", "Antigravity IDE", expanded]
            } else if FileManager.default.fileExists(atPath: "\(NSHomeDirectory())/Applications/Antigravity IDE.app") {
                task.arguments = ["-a", "\(NSHomeDirectory())/Applications/Antigravity IDE.app", expanded]
            } else if NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.google.antigravity") != nil {
                task.arguments = ["-b", "com.google.antigravity", expanded]
            } else if FileManager.default.fileExists(atPath: "/Applications/Antigravity.app") {
                task.arguments = ["-a", "Antigravity", expanded]
            } else {
                let candidateCLIs = [
                    "\(NSHomeDirectory())/.local/bin/agy",
                    "/usr/local/bin/agy",
                    "/opt/homebrew/bin/agy",
                    "\(NSHomeDirectory())/.cargo/bin/agy"
                ]
                for cliPath in candidateCLIs {
                    if FileManager.default.isExecutableFile(atPath: cliPath) {
                        let cliTask = Process()
                        cliTask.executableURL = URL(fileURLWithPath: cliPath)
                        cliTask.arguments = [expanded]
                        try? cliTask.run()
                        return
                    }
                }
                task.arguments = ["-a", "Antigravity IDE", expanded]
            }
        case .codex:
            let candidateCLIs = [
                "/Applications/ChatGPT.app/Contents/Resources/codex",
                "\(NSHomeDirectory())/Applications/ChatGPT.app/Contents/Resources/codex",
                "/Applications/Codex.app/Contents/Resources/codex",
                "/usr/local/bin/codex",
                "/opt/homebrew/bin/codex",
                "\(NSHomeDirectory())/.local/bin/codex",
                "\(NSHomeDirectory())/.cargo/bin/codex"
            ]
            
            for cliPath in candidateCLIs {
                if FileManager.default.isExecutableFile(atPath: cliPath) {
                    let cliTask = Process()
                    cliTask.executableURL = URL(fileURLWithPath: cliPath)
                    cliTask.arguments = ["app", expanded]
                    try? cliTask.run()
                    return
                }
            }
            
            if FileManager.default.fileExists(atPath: "/Applications/Codex.app") {
                task.arguments = ["-a", "Codex", expanded]
            } else if FileManager.default.fileExists(atPath: "/Applications/ChatGPT.app") {
                task.arguments = ["-a", "ChatGPT", expanded]
            } else {
                task.arguments = ["-a", "Codex", expanded]
            }
        case .windsurf:
            let candidateCLIs = [
                "/Applications/Windsurf.app/Contents/Resources/app/bin/windsurf",
                "/usr/local/bin/windsurf",
                "/opt/homebrew/bin/windsurf",
                "\(NSHomeDirectory())/.local/bin/windsurf"
            ]
            for cliPath in candidateCLIs {
                if FileManager.default.isExecutableFile(atPath: cliPath) {
                    let cliTask = Process()
                    cliTask.executableURL = URL(fileURLWithPath: cliPath)
                    cliTask.arguments = [expanded]
                    try? cliTask.run()
                    return
                }
            }
            task.arguments = ["-a", "Windsurf", expanded]
        case .kiro:
            let candidateCLIs = [
                "/Applications/Kiro.app/Contents/Resources/app/bin/kiro",
                "\(NSHomeDirectory())/Applications/Kiro.app/Contents/Resources/app/bin/kiro",
                "/usr/local/bin/kiro",
                "/opt/homebrew/bin/kiro",
                "\(NSHomeDirectory())/.local/bin/kiro"
            ]
            for cliPath in candidateCLIs {
                if FileManager.default.isExecutableFile(atPath: cliPath) {
                    let cliTask = Process()
                    cliTask.executableURL = URL(fileURLWithPath: cliPath)
                    cliTask.arguments = [expanded]
                    try? cliTask.run()
                    return
                }
            }
            task.arguments = ["-a", "Kiro", expanded]
        case .zed:
            let candidateCLIs = [
                "/usr/local/bin/zed",
                "/opt/homebrew/bin/zed",
                "\(NSHomeDirectory())/.local/bin/zed"
            ]
            for cliPath in candidateCLIs {
                if FileManager.default.isExecutableFile(atPath: cliPath) {
                    let cliTask = Process()
                    cliTask.executableURL = URL(fileURLWithPath: cliPath)
                    cliTask.arguments = [expanded]
                    try? cliTask.run()
                    return
                }
            }
            task.arguments = ["-a", "Zed", expanded]
        case .openCode:
            let candidateCLIs = [
                "/usr/local/bin/opencode",
                "/opt/homebrew/bin/opencode",
                "\(NSHomeDirectory())/.local/bin/opencode",
                "\(NSHomeDirectory())/.cargo/bin/opencode"
            ]
            for cliPath in candidateCLIs {
                if FileManager.default.isExecutableFile(atPath: cliPath) {
                    let cliTask = Process()
                    cliTask.executableURL = URL(fileURLWithPath: cliPath)
                    cliTask.arguments = [expanded]
                    try? cliTask.run()
                    return
                }
            }
            task.arguments = ["-a", "OpenCode", expanded]
        }
        
        try? task.run()
    }
}
