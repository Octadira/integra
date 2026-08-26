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
    
    public var intendedTunnels: Set<UUID> = []
    private var activeReconnectTasks: [UUID: Task<Void, Never>] = [:]
    
    public init() {}
    
    public func isTunnelRunning(for profileId: UUID) -> Bool {
        guard let process = runningProcesses[profileId], process.isRunning else {
            return false
        }
        return activeTunnelsByProfile[profileId]?.isEmpty == false
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
        
        // Stop any existing tunnel process for this profile without clearing intended state
        stopTunnels(for: profile, isUserInitiated: false)
        
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
        
        profile.sanitizeIdentityFilePermissionsIfNeeded()
        
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
        
        // Register termination handler for proactive dead-process cleanup and auto-healing
        let profileId = profile.id
        process.terminationHandler = { [weak self] terminatedProc in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.runningProcesses[profileId] == terminatedProc {
                    self.runningProcesses.removeValue(forKey: profileId)
                    self.activeTunnelsByProfile.removeValue(forKey: profileId)
                    
                    // Auto-reconnect if intended to be active and autoReconnect is enabled
                    if self.intendedTunnels.contains(profileId) && AppSettings.shared.autoReconnectOnRecovery {
                        IntegraLogger.shared.log("[SSHTunnelService] SSH tunnel process for \(profile.name) terminated unexpectedly (exit code \(terminatedProc.terminationStatus)). Scheduling auto-recovery...")
                        self.scheduleTunnelReconnect(for: profile, attempt: 0)
                    }
                }
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
            intendedTunnels.insert(profile.id)
            activeReconnectTasks[profile.id]?.cancel()
            activeReconnectTasks.removeValue(forKey: profile.id)
            
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
    
    public func stopTunnels(for profile: SSHProfile, isUserInitiated: Bool = true) {
        if isUserInitiated {
            intendedTunnels.remove(profile.id)
            activeReconnectTasks[profile.id]?.cancel()
            activeReconnectTasks.removeValue(forKey: profile.id)
        }
        
        if let proc = runningProcesses[profile.id] {
            proc.terminationHandler = nil
            if proc.isRunning {
                proc.terminate()
            }
            runningProcesses.removeValue(forKey: profile.id)
        }
        activeTunnelsByProfile.removeValue(forKey: profile.id)
    }
    
    public func scheduleTunnelReconnect(for profile: SSHProfile, attempt: Int) {
        activeReconnectTasks[profile.id]?.cancel()
        
        let maxAttempts = 6
        guard attempt < maxAttempts else {
            IntegraLogger.shared.log("[SSHTunnelService] Max auto-reconnect attempts reached for tunnels on \(profile.name)")
            activeReconnectTasks.removeValue(forKey: profile.id)
            return
        }
        
        let delaySeconds = min(30.0, 1.5 * pow(2.0, Double(attempt)))
        
        activeReconnectTasks[profile.id] = Task {
            try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            guard self.intendedTunnels.contains(profile.id) else { return }
            
            do {
                try await self.startTunnels(for: profile)
                IntegraLogger.shared.log("[SSHTunnelService] Successfully auto-recovered SSH tunnels for \(profile.name)")
            } catch {
                IntegraLogger.shared.log("[SSHTunnelService] Tunnel auto-recovery attempt \(attempt + 1) failed for \(profile.name): \(error.localizedDescription)")
                self.scheduleTunnelReconnect(for: profile, attempt: attempt + 1)
            }
        }
    }
    
    public func recoverTunnelsIfNeeded(store: ProfileStore) {
        guard AppSettings.shared.autoReconnectOnRecovery else { return }
        
        for profile in store.profiles {
            let hasEnabledRules = profile.portTunnels.contains(where: { $0.isEnabled })
            guard hasEnabledRules else { continue }
            
            let isMounted = SSHFSService.shared.isProfileMounted(profile)
            let isIntended = intendedTunnels.contains(profile.id)
            
            if (isMounted || isIntended) && !isTunnelRunning(for: profile.id) {
                intendedTunnels.insert(profile.id)
                scheduleTunnelReconnect(for: profile, attempt: 0)
            }
        }
    }
}
