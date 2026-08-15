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
        
        let sshCmd = "ssh -p \(profile.port) '\(safeUser)'@'\(safeHost)'"
        
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
            // Check for Antigravity, Antigravity IDE, Google Antigravity
            let candidateNames = ["Antigravity", "Antigravity IDE", "Google Antigravity", "Antigravity 2.0"]
            var opened = false
            for name in candidateNames {
                if NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.google.antigravity") != nil ||
                   FileManager.default.fileExists(atPath: "/Applications/\(name).app") {
                    task.arguments = ["-a", name, expanded]
                    opened = true
                    break
                }
            }
            if !opened {
                // Check if CLI 'agy' or 'antigravity' exists
                if FileManager.default.fileExists(atPath: "/usr/local/bin/agy") {
                    let cliTask = Process()
                    cliTask.executableURL = URL(fileURLWithPath: "/usr/local/bin/agy")
                    cliTask.arguments = [expanded]
                    try? cliTask.run()
                    return
                }
                task.arguments = ["-a", "Antigravity", expanded]
            }
        }
        
        try? task.run()
    }
}
