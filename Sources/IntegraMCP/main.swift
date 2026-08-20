import Foundation
import IntegraCore

// MARK: - JSON-RPC 2.0 Types

struct JSONRPCRequest: Decodable {
    let jsonrpc: String
    let id: AnyCodableID?
    let method: String
    let params: [String: AnyCodableValue]?
}

enum AnyCodableID: Codable, CustomStringConvertible {
    case string(String)
    case int(Int)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            self = .int(intVal)
        } else if let strVal = try? container.decode(String.self) {
            self = .string(strVal)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ID type")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .int(let i): try container.encode(i)
        }
    }
    
    var description: String {
        switch self {
        case .string(let s): return "\"\(s)\""
        case .int(let i): return "\(i)"
        }
    }
}

enum AnyCodableValue: Codable {
    case string(String)
    case int(Int)
    case bool(Bool)
    case double(Double)
    case dict([String: AnyCodableValue])
    case array([AnyCodableValue])
    case null
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let b = try? container.decode(Bool.self) { self = .bool(b) }
        else if let i = try? container.decode(Int.self) { self = .int(i) }
        else if let d = try? container.decode(Double.self) { self = .double(d) }
        else if let s = try? container.decode(String.self) { self = .string(s) }
        else if let dict = try? container.decode([String: AnyCodableValue].self) { self = .dict(dict) }
        else if let arr = try? container.decode([AnyCodableValue].self) { self = .array(arr) }
        else { self = .null }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .int(let i): try container.encode(i)
        case .bool(let b): try container.encode(b)
        case .double(let d): try container.encode(d)
        case .dict(let d): try container.encode(d)
        case .array(let a): try container.encode(a)
        case .null: try container.encodeNil()
        }
    }
    
    var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }
    
    var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }
    
    var dictValue: [String: AnyCodableValue]? {
        if case .dict(let d) = self { return d }
        return nil
    }
}

// MARK: - Server Implementation

@main
struct IntegraMCPServer {
    static let serverVersion = "0.10.0"
    
    static func main() async {
        let fileHandle = FileHandle.standardInput
        
        while true {
            guard let lineData = readNextLine(from: fileHandle) else {
                break // EOF / Pipe closed
            }
            
            if lineData.isEmpty { continue }
            
            guard let request = try? JSONDecoder().decode(JSONRPCRequest.self, from: lineData) else {
                continue
            }
            
            await handleRequest(request)
        }
    }
    
    private static func readNextLine(from fileHandle: FileHandle) -> Data? {
        var lineData = Data()
        while true {
            let chunk = fileHandle.readData(ofLength: 1)
            if chunk.isEmpty {
                return lineData.isEmpty ? nil : lineData
            }
            if chunk[0] == 0x0A { // \n
                return lineData
            }
            if chunk[0] != 0x0D { // Skip \r
                lineData.append(chunk)
            }
        }
    }
    
    private static func sendResponse(id: AnyCodableID?, result: [String: Any]?, error: [String: Any]?) {
        guard let id = id else { return } // Notifications do not expect a response
        
        var responseDict: [String: Any] = [
            "jsonrpc": "2.0"
        ]
        
        switch id {
        case .string(let s): responseDict["id"] = s
        case .int(let i): responseDict["id"] = i
        }
        
        if let result = result {
            responseDict["result"] = result
        } else if let error = error {
            responseDict["error"] = error
        } else {
            responseDict["result"] = [:]
        }
        
        if let data = try? JSONSerialization.data(withJSONObject: responseDict),
           var line = String(data: data, encoding: .utf8) {
            line.append("\n")
            if let outputData = line.data(using: .utf8) {
                FileHandle.standardOutput.write(outputData)
            }
        }
    }
    
    private static func handleRequest(_ req: JSONRPCRequest) async {
        switch req.method {
        case "initialize":
            let result: [String: Any] = [
                "protocolVersion": "2024-11-05",
                "capabilities": [
                    "tools": [
                        "listChanged": false
                    ]
                ],
                "serverInfo": [
                    "name": "integra-mcp",
                    "version": serverVersion
                ]
            ]
            sendResponse(id: req.id, result: result, error: nil)
            
        case "notifications/initialized":
            // Notification; no response needed
            break
            
        case "ping":
            sendResponse(id: req.id, result: [:], error: nil)
            
        case "tools/list":
            let tools: [[String: Any]] = [
                [
                    "name": "integra_execute_command",
                    "description": "Executes a shell command directly on a remote Linux/SSH server mounted via Integra with sub-5ms latency through persistent OpenSSH ControlMaster sockets.",
                    "inputSchema": [
                        "type": "object",
                        "properties": [
                            "server": [
                                "type": "string",
                                "description": "Name, hostname, IP, or short ID of the remote server profile configured in Integra (e.g. 'Ubuntu-Prod', '192.168.1.50')."
                            ],
                            "command": [
                                "type": "string",
                                "description": "The exact shell command to execute on the remote server (e.g. 'docker ps', 'npm test', 'git status', 'uname -a')."
                            ],
                            "working_dir": [
                                "type": "string",
                                "description": "Optional remote working directory or local mount subpath to execute the command inside."
                            ],
                            "sudo": [
                                "type": "boolean",
                                "description": "Set to true if command requires administrator / superuser privileges."
                            ]
                        ],
                        "required": ["server", "command"]
                    ]
                ],
                [
                    "name": "integra_list_servers",
                    "description": "Lists all configured and active remote SSHFS server mounts in Integra, including connection status, mount paths, hostnames, and loopback port tunnels.",
                    "inputSchema": [
                        "type": "object",
                        "properties": [:] as [String: Any]
                    ]
                ],
                [
                    "name": "integra_get_tunnels",
                    "description": "Lists active SSH loopback port forwarding tunnels (e.g. Ollama LLM endpoint, PostgreSQL, Redis) configured in Integra for remote servers.",
                    "inputSchema": [
                        "type": "object",
                        "properties": [:] as [String: Any]
                    ]
                ]
            ]
            sendResponse(id: req.id, result: ["tools": tools], error: nil)
            
        case "tools/call":
            guard let params = req.params,
                  let toolName = params["name"]?.stringValue else {
                sendResponse(id: req.id, result: nil, error: ["code": -32602, "message": "Missing tool name in params"])
                return
            }
            
            let args = params["arguments"]?.dictValue ?? [:]
            await handleToolCall(id: req.id, name: toolName, arguments: args)
            
        default:
            sendResponse(id: req.id, result: nil, error: ["code": -32601, "message": "Method not found: \(req.method)"])
        }
    }
    
    private static func handleToolCall(id: AnyCodableID?, name: String, arguments: [String: AnyCodableValue]) async {
        let profiles = loadProfilesFromDisk()
        
        switch name {
        case "integra_list_servers":
            var list: [[String: Any]] = []
            for p in profiles {
                let isMounted = isProfileMounted(p)
                list.append([
                    "name": p.name,
                    "host": p.host,
                    "user": p.effectiveUser,
                    "port": p.port,
                    "mount_path": p.defaultMountPath,
                    "is_mounted": isMounted,
                    "tunnels_count": p.portTunnels.count
                ])
            }
            
            let formattedJson = (try? JSONSerialization.data(withJSONObject: list, options: .prettyPrinted))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
            
            let result: [String: Any] = [
                "content": [
                    [
                        "type": "text",
                        "text": formattedJson
                    ]
                ],
                "isError": false
            ]
            sendResponse(id: id, result: result, error: nil)
            
        case "integra_get_tunnels":
            var tunnelsList: [[String: Any]] = []
            for p in profiles {
                for t in p.portTunnels where t.isEnabled {
                    tunnelsList.append([
                        "server": p.name,
                        "tunnel_name": t.name,
                        "local_endpoint": "http://127.0.0.1:\(t.localPort)",
                        "remote_port": t.remotePort,
                        "remote_host": t.remoteHost
                    ])
                }
            }
            
            let formatted = (try? JSONSerialization.data(withJSONObject: tunnelsList, options: .prettyPrinted))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
            
            let result: [String: Any] = [
                "content": [
                    [
                        "type": "text",
                        "text": formatted
                    ]
                ],
                "isError": false
            ]
            sendResponse(id: id, result: result, error: nil)
            
        case "integra_execute_command":
            guard let serverQuery = arguments["server"]?.stringValue,
                  let command = arguments["command"]?.stringValue else {
                sendResponse(id: id, result: nil, error: ["code": -32602, "message": "Missing 'server' or 'command' argument"])
                return
            }
            
            let targetSubpath = arguments["working_dir"]?.stringValue
            let explicitSudo = arguments["sudo"]?.boolValue ?? false
            let startsWithSudo = command.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("sudo ")
            let requiresSudo = explicitSudo || startsWithSudo
            
            // Find matching profile
            guard let matchedProfile = profiles.first(where: {
                $0.name.localizedCaseInsensitiveContains(serverQuery) ||
                $0.host.localizedCaseInsensitiveContains(serverQuery) ||
                $0.shortId.localizedCaseInsensitiveContains(serverQuery)
            }) else {
                let errorResult: [String: Any] = [
                    "content": [
                        [
                            "type": "text",
                            "text": "Error: No configured Integra server found matching query '\(serverQuery)'. Use 'integra_list_servers' to see available profiles."
                        ]
                    ],
                    "isError": true
                ]
                sendResponse(id: id, result: errorResult, error: nil)
                return
            }
            
            var sudoPasswordToInject: String? = nil
            if requiresSudo {
                let authResult = await SudoAuthManager.shared.authorizeAndGetPassword(profile: matchedProfile, command: command)
                guard authResult.isGranted else {
                    let deniedResult: [String: Any] = [
                        "content": [
                            [
                                "type": "text",
                                "text": "Sudo Authorization Denied: \(authResult.errorMessage ?? "User cancelled administrative authorization.")"
                            ]
                        ],
                        "isError": true
                    ]
                    sendResponse(id: id, result: deniedResult, error: nil)
                    return
                }
                sudoPasswordToInject = authResult.sudoPassword
            }
            
            let output = await executeRemoteCommand(
                profile: matchedProfile,
                command: command,
                workingDir: targetSubpath,
                requiresSudo: requiresSudo,
                sudoPassword: sudoPasswordToInject
            )
            
            let result: [String: Any] = [
                "content": [
                    [
                        "type": "text",
                        "text": output
                    ]
                ],
                "isError": false
            ]
            sendResponse(id: id, result: result, error: nil)
            
        default:
            sendResponse(id: id, result: nil, error: ["code": -32601, "message": "Unknown tool: \(name)"])
        }
    }
    
    // MARK: - Helpers
    
    private static func loadProfilesFromDisk() -> [SSHProfile] {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let fileURL = appSupport.appendingPathComponent("Integra", isDirectory: true).appendingPathComponent("profiles.json")
        
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([SSHProfile].self, from: data) else {
            return []
        }
        return decoded
    }
    
    private static func isProfileMounted(_ profile: SSHProfile) -> Bool {
        let mountPath = (profile.defaultMountPath as NSString).standardizingPath
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: mountPath, isDirectory: &isDir), isDir.boolValue else {
            return false
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/mount")
        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let mountOutput = String(data: data, encoding: .utf8) ?? ""
        return mountOutput.contains(mountPath)
    }
    
    private static func executeRemoteCommand(
        profile: SSHProfile,
        command: String,
        workingDir: String?,
        requiresSudo: Bool = false,
        sudoPassword: String? = nil
    ) async -> String {
        let socketPath = profile.controlSocketPath
        let destination = "\(profile.effectiveUser)@\(profile.host)"
        
        return await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
            
            var remoteCmd = command
            if requiresSudo {
                var innerCmd = command.trimmingCharacters(in: .whitespacesAndNewlines)
                if innerCmd.hasPrefix("sudo ") {
                    innerCmd = String(innerCmd.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                if profile.effectiveUser.lowercased() == "root" {
                    remoteCmd = innerCmd
                } else if let pass = sudoPassword, !pass.isEmpty {
                    let escapedPass = pass.replacingOccurrences(of: "'", with: "'\\''")
                    let escapedInner = innerCmd.replacingOccurrences(of: "'", with: "'\\''")
                    remoteCmd = "printf '%s\\n' '\(escapedPass)' | sudo -S -p '' sh -c '\(escapedInner)'"
                } else {
                    remoteCmd = "sudo \(innerCmd)"
                }
            }
            
            if let subpath = workingDir, !subpath.isEmpty {
                let escaped = subpath.replacingOccurrences(of: "'", with: "'\\''")
                remoteCmd = "if [ -d '\(escaped)' ]; then cd '\(escaped)'; fi && \(remoteCmd)"
            }
            
            var args: [String] = []
            var askPassScript: URL? = nil
            var env: [String: String] = ProcessInfo.processInfo.environment
            
            if FileManager.default.fileExists(atPath: socketPath) {
                args = [
                    "-S", socketPath,
                    "-p", "\(profile.port)",
                    "-o", "BatchMode=yes",
                    "-o", "ConnectTimeout=8",
                    destination,
                    remoteCmd
                ]
            } else {
                args = [
                    "-p", "\(profile.port)",
                    "-o", "StrictHostKeyChecking=accept-new",
                    "-o", "ConnectTimeout=8"
                ]
                
                switch profile.authMethod {
                case .none:
                    args.append(contentsOf: ["-o", "BatchMode=yes"])
                case .key:
                    args.append(contentsOf: ["-o", "BatchMode=yes"])
                    let keyPath = (profile.identityFile as NSString).expandingTildeInPath
                    if !keyPath.isEmpty {
                        args.append(contentsOf: ["-i", keyPath])
                    }
                case .password:
                    let savedPassword = KeychainService.shared.getPassword(account: profile.id.uuidString)
                    if let pass = savedPassword, !pass.isEmpty {
                        let askpassDir = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".ssh/integra/askpass", isDirectory: true)
                        try? FileManager.default.createDirectory(at: askpassDir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
                        
                        let tempScript = askpassDir.appendingPathComponent("askpass_\(UUID().uuidString).sh")
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
                
                args.append(destination)
                args.append(remoteCmd)
            }
            
            process.arguments = args
            process.environment = env
            
            let finalAskPass = askPassScript
            defer {
                if let scriptURL = finalAskPass {
                    try? FileManager.default.removeItem(at: scriptURL)
                }
            }
            
            let pipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = pipe
            process.standardError = errPipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let outData = pipe.fileHandleForReading.readDataToEndOfFile()
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                
                let stdout = String(data: outData, encoding: .utf8) ?? ""
                let stderr = String(data: errData, encoding: .utf8) ?? ""
                
                if process.terminationStatus != 0 && stdout.isEmpty {
                    return "Exit Code \(process.terminationStatus):\n\(stderr)"
                }
                
                return stdout.isEmpty ? stderr : stdout
            } catch {
                return "Error executing remote command: \(error.localizedDescription)"
            }
        }.value
    }
}
