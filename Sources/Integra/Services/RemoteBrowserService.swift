import Foundation

public struct RemoteDirectoryItem: Identifiable, Hashable {
    public var id: String { fullPath }
    public let name: String
    public let fullPath: String
    public let isDirectory: Bool
    
    public init(name: String, fullPath: String, isDirectory: Bool = true) {
        self.name = name
        self.fullPath = fullPath
        self.isDirectory = isDirectory
    }
}

public class RemoteBrowserService {
    public static let shared = RemoteBrowserService()
    
    private init() {}
    
    public func listDirectories(
        host: String,
        port: Int,
        user: String,
        authMethod: AuthMethod,
        identityFile: String,
        password: String?,
        currentPath: String
    ) async throws -> (currentNormalizedPath: String, items: [RemoteDirectoryItem]) {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUser = user.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedHost.isEmpty else {
            throw NSError(
                domain: "RemoteBrowserService",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Server Host cannot be empty."]
            )
        }
        
        guard !trimmedHost.hasPrefix("-") && !trimmedUser.hasPrefix("-") else {
            throw NSError(
                domain: "RemoteBrowserService",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Invalid host or username: cannot start with '-'."]
            )
        }
        
        let destination = trimmedUser.isEmpty ? trimmedHost : "\(trimmedUser)@\(trimmedHost)"
        let targetPath = currentPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "/" : currentPath
        
        return try await Task.detached(priority: .userInitiated) {
            var args: [String] = [
                "-p", "\(port)",
                "-o", "ConnectTimeout=8",
                "-o", "StrictHostKeyChecking=accept-new"
            ]
            
            var askPassScript: URL? = nil
            var env: [String: String] = ProcessInfo.processInfo.environment
            
            switch authMethod {
            case .none:
                args.append(contentsOf: ["-o", "BatchMode=yes"])
            case .key:
                args.append(contentsOf: ["-o", "BatchMode=yes"])
                let keyPath = (identityFile as NSString).expandingTildeInPath
                if !keyPath.isEmpty {
                    args.append(contentsOf: ["-i", keyPath])
                }
            case .password:
                if let pass = password, !pass.isEmpty {
                    let askpassDir = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".ssh/integra/askpass", isDirectory: true)
                    try? FileManager.default.createDirectory(at: askpassDir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
                    
                    let tempScript = askpassDir.appendingPathComponent("askpass_\(UUID().uuidString).sh")
                    
                    // Use quoted EOF delimiter in /bin/sh to prevent ANY shell parameter, backtick, or dollar expansion (M-2 Fix)
                    let scriptContent = """
                    #!/bin/sh
                    /bin/cat << 'INTEGRA_ASKPASS_EOF'
                    \(pass)
                    INTEGRA_ASKPASS_EOF
                    """
                    try? scriptContent.write(to: tempScript, atomically: true, encoding: .utf8)
                    try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: tempScript.path)
                    askPassScript = tempScript
                    
                    env["SSH_ASKPASS"] = tempScript.path
                    env["SSH_ASKPASS_REQUIRE"] = "force"
                    env["DISPLAY"] = ":0"
                } else {
                    args.append(contentsOf: ["-o", "BatchMode=yes"])
                }
            }
            
            // Build safe remote command to list directories and print normalized pwd
            let escapedPath = targetPath.replacingOccurrences(of: "'", with: "'\\''")
            let remoteCommand = """
            if [ -d '\(escapedPath)' ]; then cd -- '\(escapedPath)' 2>/dev/null || exit 1; else cd /; fi; pwd -P; ls -1pa
            """
            
            args.append(destination)
            args.append(remoteCommand)
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
            process.arguments = args
            process.environment = env
            
            let outPipe = Pipe()
            let errPipe = Pipe()
            let inPipe = Pipe()
            
            process.standardOutput = outPipe
            process.standardError = errPipe
            process.standardInput = inPipe
            try? inPipe.fileHandleForWriting.close()
            
            defer {
                if let script = askPassScript {
                    try? FileManager.default.removeItem(at: script)
                }
            }
            
            do {
                try process.run()
            } catch {
                throw NSError(
                    domain: "RemoteBrowserService",
                    code: 500,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to launch SSH process: \(error.localizedDescription)"]
                )
            }
            
            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: 12_000_000_000)
                if process.isRunning {
                    process.terminate()
                }
            }
            
            process.waitUntilExit()
            timeoutTask.cancel()
            
            let outData = (try? outPipe.fileHandleForReading.readToEnd()) ?? Data()
            let errData = (try? errPipe.fileHandleForReading.readToEnd()) ?? Data()
            
            let outString = String(data: outData, encoding: .utf8) ?? ""
            let errString = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            if process.terminationStatus != 0 {
                var message = errString
                if message.isEmpty {
                    message = "SSH connection failed with exit code \(process.terminationStatus)."
                }
                if message.lowercased().contains("permission denied") {
                    message = "Permission Denied: Invalid credentials or insufficient permissions on remote path."
                } else if message.lowercased().contains("connection timed out") || message.lowercased().contains("timed out") {
                    message = "Connection Timed Out: Server \(destination) is unreachable on port \(port)."
                } else if message.lowercased().contains("no route to host") {
                    message = "Network Error: No route to host \(destination)."
                }
                throw NSError(
                    domain: "RemoteBrowserService",
                    code: Int(process.terminationStatus),
                    userInfo: [NSLocalizedDescriptionKey: message]
                )
            }
            
            var lines = outString.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            
            guard !lines.isEmpty else {
                return ("/", [])
            }
            
            // First line is the normalized pwd
            let normalizedPwd = lines.removeFirst()
            let basePath = normalizedPwd.hasSuffix("/") && normalizedPwd.count > 1 ? String(normalizedPwd.dropLast()) : normalizedPwd
            
            var directoryItems: [RemoteDirectoryItem] = []
            
            for line in lines {
                // Directories in ls -1pa end with a trailing slash '/'
                guard line.hasSuffix("/") else { continue }
                
                let rawName = String(line.dropLast())
                // Skip self '.' and parent '..' (we handle parent via breadcrumb/Up button)
                if rawName == "." || rawName == ".." || rawName.isEmpty {
                    continue
                }
                
                let itemFullPath = basePath == "/" ? "/\(rawName)" : "\(basePath)/\(rawName)"
                directoryItems.append(RemoteDirectoryItem(name: rawName, fullPath: itemFullPath, isDirectory: true))
            }
            
            // Sort directories: visible first alphabetically, then hidden dot-folders
            directoryItems.sort { a, b in
                let aHidden = a.name.hasPrefix(".")
                let bHidden = b.name.hasPrefix(".")
                if aHidden != bHidden {
                    return !aHidden && bHidden
                }
                return a.name.localizedStandardCompare(b.name) == .orderedAscending
            }
            
            return (normalizedPwd, directoryItems)
        }.value
    }
}
