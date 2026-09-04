import Foundation

/// Centralized helper for generating secure, isolated SSH_ASKPASS scripts for OpenSSH processes.
public struct AskPassScriptSession {
    public let scriptURL: URL
    public let environment: [String: String]
    
    public func cleanup() {
        try? FileManager.default.removeItem(at: scriptURL)
    }
}

public final class AskPassHelper: @unchecked Sendable {
    public static let shared = AskPassHelper()
    
    private init() {}
    
    /// Generates a temporary shell script in `~/.ssh/integra/askpass` with `0700` permissions
    /// using a dynamically generated UUID EOF delimiter to prevent heredoc breakouts (SEC-02).
    public func createSession(password: String) -> AskPassScriptSession? {
        guard !password.isEmpty else { return nil }
        
        let home = NSHomeDirectory()
        let askpassDir = URL(fileURLWithPath: home).appendingPathComponent(".ssh/integra/askpass", isDirectory: true)
        
        do {
            try FileManager.default.createDirectory(at: askpassDir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        } catch {
            return nil
        }
        
        let scriptId = UUID().uuidString
        let tempScript = askpassDir.appendingPathComponent("askpass_\(scriptId).sh")
        let delimiter = "INTEGRA_EOF_" + scriptId.replacingOccurrences(of: "-", with: "")
        
        let scriptContent = """
        #!/bin/sh
        /bin/cat << '\(delimiter)'
        \(password)
        \(delimiter)
        """
        
        do {
            try scriptContent.write(to: tempScript, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: tempScript.path)
        } catch {
            return nil
        }
        
        var env = ProcessInfo.processInfo.environment
        env["SSH_ASKPASS"] = tempScript.path
        env["SSH_ASKPASS_REQUIRE"] = "force"
        env["DISPLAY"] = ":0"
        
        return AskPassScriptSession(scriptURL: tempScript, environment: env)
    }
}
