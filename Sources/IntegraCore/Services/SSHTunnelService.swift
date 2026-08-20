import Foundation
import Network
import Combine

public struct ActiveTunnelInfo: Identifiable, Equatable {
    public var id: UUID
    public var profileId: UUID
    public var rule: PortTunnelRule
    public var localEndpoint: String
    public var startedAt: Date
}

@MainActor
public class SSHTunnelService: ObservableObject {
    public static let shared = SSHTunnelService()
    
    @Published public var activeTunnelsByProfile: [UUID: [ActiveTunnelInfo]] = [:]
    @Published public var runningProcesses: [UUID: Process] = [:]
    
    public init() {}
    
    public func isTunnelRunning(for profileId: UUID) -> Bool {
        return runningProcesses[profileId] != nil && (activeTunnelsByProfile[profileId]?.isEmpty == false)
    }
    
    public func checkPortAvailability(port: Int) -> Bool {
        var sin = sockaddr_in()
        sin.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        sin.sin_family = sa_family_t(AF_INET)
        sin.sin_port = in_port_t(UInt16(port).bigEndian)
        sin.sin_addr.s_addr = inet_addr("127.0.0.1")
        
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else { return false }
        defer { close(sock) }
        
        var reuse: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))
        
        let bindResult = withUnsafePointer(to: &sin) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        return bindResult == 0
    }
    
    public func startTunnels(for profile: SSHProfile) async throws {
        let enabledRules = profile.portTunnels.filter { $0.isEnabled }
        guard !enabledRules.isEmpty else {
            throw NSError(domain: "SSHTunnelService", code: 400, userInfo: [NSLocalizedDescriptionKey: "No port tunnel rules enabled for this server."])
        }
        
        // Stop any existing tunnel process for this profile
        stopTunnels(for: profile)
        
        // Check port availability
        for rule in enabledRules {
            if !checkPortAvailability(port: rule.localPort) {
                throw NSError(
                    domain: "SSHTunnelService",
                    code: 409,
                    userInfo: [NSLocalizedDescriptionKey: "Local port \(rule.localPort) is already in use by another application."]
                )
            }
        }
        
        var args: [String] = [
            "-N", // Do not execute a remote command (port forwarding only)
            "-p", "\(profile.port)",
            "-o", "ServerAliveInterval=15",
            "-o", "ServerAliveCountMax=3",
            "-o", "StrictHostKeyChecking=accept-new",
            "-o", "ConnectTimeout=10",
            "-o", "ExitOnForwardFailure=yes"
        ]
        
        for rule in enabledRules {
            let remoteHost = rule.remoteHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "127.0.0.1" : rule.remoteHost
            args.append("-L")
            args.append("\(rule.localPort):\(remoteHost):\(rule.remotePort)")
        }
        
        var askPassScript: URL? = nil
        var env: [String: String] = ProcessInfo.processInfo.environment
        
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
        
        let userSpec = profile.effectiveUser
        let destination = "\(userSpec)@\(profile.host)"
        args.append(destination)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        process.arguments = args
        process.environment = env
        
        let errPipe = Pipe()
        process.standardError = errPipe
        
        let finalAskPass = askPassScript
        defer {
            if let scriptURL = finalAskPass {
                try? FileManager.default.removeItem(at: scriptURL)
            }
        }
        
        do {
            try process.run()
            
            // Brief sleep to verify process didn't exit immediately due to error
            try await Task.sleep(nanoseconds: 800_000_000)
            
            if !process.isRunning && process.terminationStatus != 0 {
                let errData = (try? errPipe.fileHandleForReading.readToEnd()) ?? Data()
                let errStr = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                throw NSError(domain: "SSHTunnelService", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: errStr?.isEmpty == false ? errStr! : "SSH Tunnel failed to start (exit code \(process.terminationStatus))"])
            }
            
            runningProcesses[profile.id] = process
            
            var activeInfos: [ActiveTunnelInfo] = []
            for rule in enabledRules {
                activeInfos.append(ActiveTunnelInfo(
                    id: UUID(),
                    profileId: profile.id,
                    rule: rule,
                    localEndpoint: "http://127.0.0.1:\(rule.localPort)",
                    startedAt: Date()
                ))
            }
            activeTunnelsByProfile[profile.id] = activeInfos
            
        } catch {
            throw error
        }
    }
    
    public func stopTunnels(for profile: SSHProfile) {
        if let proc = runningProcesses[profile.id] {
            if proc.isRunning {
                proc.terminate()
            }
            runningProcesses.removeValue(forKey: profile.id)
        }
        activeTunnelsByProfile.removeValue(forKey: profile.id)
    }
}
