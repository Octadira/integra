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
    @Published public var tunnelErrors: [UUID: String] = [:]
    
    public var intendedTunnels: Set<UUID> = []
    public var reconnectAttemptsByProfile: [UUID: Int] = [:]
    private var activeReconnectTasks: [UUID: Task<Void, Never>] = [:]
    private var activeAskPassScripts: [UUID: URL] = [:]
    
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
    
    public func reclaimPortIfStaleSSHProcess(port: Int, host: String) -> Bool {
        guard !checkPortAvailability(port: port) else { return true }
        
        let lsofProc = Process()
        lsofProc.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        lsofProc.arguments = ["-nP", "-iTCP:\(port)", "-sTCP:LISTEN", "-t"]
        let pipe = Pipe()
        lsofProc.standardOutput = pipe
        do {
            try lsofProc.run()
            lsofProc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !output.isEmpty {
                let pids = output.components(separatedBy: .newlines).compactMap { Int32($0.trimmingCharacters(in: .whitespaces)) }
                for pid in pids {
                    let psProc = Process()
                    psProc.executableURL = URL(fileURLWithPath: "/bin/ps")
                    psProc.arguments = ["-p", "\(pid)", "-o", "command="]
                    let psPipe = Pipe()
                    psProc.standardOutput = psPipe
                    try? psProc.run()
                    psProc.waitUntilExit()
                    
                    let psData = psPipe.fileHandleForReading.readDataToEndOfFile()
                    let command = String(data: psData, encoding: .utf8) ?? ""
                    
                    if command.contains("ssh") && (command.contains("-L") || command.contains(":\(port):") || command.contains(host)) {
                        IntegraLogger.shared.log("[SSHTunnelService] Reclaiming port \(port) from orphaned SSH tunnel process (PID \(pid))...")
                        kill(pid, SIGTERM)
                        usleep(250_000)
                        if kill(pid, 0) == 0 {
                            kill(pid, SIGKILL)
                            usleep(100_000)
                        }
                    }
                }
            }
        } catch {
            // Continue to port check
        }
        
        return checkPortAvailability(port: port)
    }
    
    public func startTunnels(for profile: SSHProfile) async throws {
        let enabledRules = profile.portTunnels.filter { $0.isEnabled }
        guard !enabledRules.isEmpty else {
            throw NSError(domain: "SSHTunnelService", code: 400, userInfo: [NSLocalizedDescriptionKey: "No port tunnel rules enabled for this server."])
        }
        
        // Stop any existing tunnel process for this profile without clearing intended state
        stopTunnels(for: profile, isUserInitiated: false)
        
        // Check port availability and auto-reclaim orphaned SSH processes
        for rule in enabledRules {
            if !reclaimPortIfStaleSSHProcess(port: rule.localPort, host: profile.host) {
                let err = "Local port \(rule.localPort) is already in use by another application."
                tunnelErrors[profile.id] = err
                throw NSError(
                    domain: "SSHTunnelService",
                    code: 409,
                    userInfo: [NSLocalizedDescriptionKey: err]
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
            if let pass = savedPassword, !pass.isEmpty,
               let session = AskPassHelper.shared.createSession(password: pass) {
                activeAskPassScripts[profile.id] = session.scriptURL
                env = session.environment
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
        
        // Register termination handler for proactive dead-process cleanup and throttled auto-healing
        let profileId = profile.id
        process.terminationHandler = { [weak self] terminatedProc in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.runningProcesses[profileId] == terminatedProc {
                    self.runningProcesses.removeValue(forKey: profileId)
                    let previousInfos = self.activeTunnelsByProfile.removeValue(forKey: profileId)
                    
                    if let scriptURL = self.activeAskPassScripts.removeValue(forKey: profileId) {
                        try? FileManager.default.removeItem(at: scriptURL)
                    }
                    
                    // Check stability: if tunnel was connected for >60s, reset attempt counter
                    let uptime = previousInfos?.first?.startedAt.timeIntervalSinceNow ?? 0
                    if abs(uptime) > 60 {
                        self.reconnectAttemptsByProfile[profileId] = 0
                    }
                    
                    let currentAttempt = (self.reconnectAttemptsByProfile[profileId] ?? 0) + 1
                    
                    // Throttled Auto-Reconnect Guard (Max 5 attempts to prevent infinite flapping loops)
                    if self.intendedTunnels.contains(profileId) && AppSettings.shared.autoReconnectOnRecovery {
                        if currentAttempt > 5 {
                            IntegraLogger.shared.log("[SSHTunnelService] Max auto-reconnect attempts reached (5/5) for \(profile.name). Halting auto-reconnect loop to prevent flapping.")
                            self.intendedTunnels.remove(profileId)
                            self.reconnectAttemptsByProfile.removeValue(forKey: profileId)
                            self.tunnelErrors[profileId] = "SSH tunnel connection to \(profile.host) dropped. Host unreachable or timed out."
                        } else {
                            self.reconnectAttemptsByProfile[profileId] = currentAttempt
                            IntegraLogger.shared.log("[SSHTunnelService] SSH tunnel process for \(profile.name) terminated (exit code \(terminatedProc.terminationStatus)). Scheduling auto-recovery attempt \(currentAttempt)/5...")
                            self.scheduleTunnelReconnect(for: profile, attempt: currentAttempt)
                        }
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
                let finalErr = errStr?.isEmpty == false ? errStr! : "SSH Tunnel failed to start (exit code \(process.terminationStatus))"
                tunnelErrors[profile.id] = finalErr
                throw NSError(domain: "SSHTunnelService", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: finalErr])
            }
            
            runningProcesses[profile.id] = process
            intendedTunnels.insert(profile.id)
            tunnelErrors.removeValue(forKey: profile.id)
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
            if let scriptURL = activeAskPassScripts.removeValue(forKey: profile.id) {
                try? FileManager.default.removeItem(at: scriptURL)
            }
            throw error
        }
    }
    
    public func stopTunnels(for profile: SSHProfile, isUserInitiated: Bool = true) {
        if isUserInitiated {
            intendedTunnels.remove(profile.id)
            reconnectAttemptsByProfile.removeValue(forKey: profile.id)
            activeReconnectTasks[profile.id]?.cancel()
            activeReconnectTasks.removeValue(forKey: profile.id)
            tunnelErrors.removeValue(forKey: profile.id)
        }
        
        if let scriptURL = activeAskPassScripts.removeValue(forKey: profile.id) {
            try? FileManager.default.removeItem(at: scriptURL)
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
        
        guard attempt <= 5 else {
            IntegraLogger.shared.log("[SSHTunnelService] Max auto-reconnect attempts reached for tunnels on \(profile.name)")
            intendedTunnels.remove(profile.id)
            reconnectAttemptsByProfile.removeValue(forKey: profile.id)
            activeReconnectTasks.removeValue(forKey: profile.id)
            return
        }
        
        // Exponential backoff: 2s, 4s, 8s, 16s, 30s
        let delaySeconds = min(30.0, 2.0 * pow(2.0, Double(max(0, attempt - 1))))
        
        activeReconnectTasks[profile.id] = Task {
            try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            guard self.intendedTunnels.contains(profile.id) else { return }
            
            do {
                try await self.startTunnels(for: profile)
                IntegraLogger.shared.log("[SSHTunnelService] Successfully auto-recovered SSH tunnels for \(profile.name)")
                self.reconnectAttemptsByProfile.removeValue(forKey: profile.id)
                self.tunnelErrors.removeValue(forKey: profile.id)
            } catch {
                IntegraLogger.shared.log("[SSHTunnelService] Tunnel auto-recovery attempt \(attempt)/5 failed for \(profile.name): \(error.localizedDescription)")
                self.tunnelErrors[profile.id] = error.localizedDescription
                let nextAttempt = attempt + 1
                if nextAttempt <= 5 {
                    self.reconnectAttemptsByProfile[profile.id] = nextAttempt
                    self.scheduleTunnelReconnect(for: profile, attempt: nextAttempt)
                } else {
                    self.intendedTunnels.remove(profile.id)
                    self.reconnectAttemptsByProfile.removeValue(forKey: profile.id)
                }
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
                reconnectAttemptsByProfile[profile.id] = 0
                scheduleTunnelReconnect(for: profile, attempt: 1)
            }
        }
    }
    
    public func stopAllTunnels() {
        for (_, proc) in runningProcesses {
            proc.terminationHandler = nil
            if proc.isRunning {
                proc.terminate()
            }
        }
        runningProcesses.removeAll()
        activeTunnelsByProfile.removeAll()
        for scriptURL in activeAskPassScripts.values {
            try? FileManager.default.removeItem(at: scriptURL)
        }
        activeAskPassScripts.removeAll()
        activeReconnectTasks.values.forEach { $0.cancel() }
        activeReconnectTasks.removeAll()
    }
}
