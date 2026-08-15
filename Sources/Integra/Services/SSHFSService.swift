import Foundation
import Combine

@MainActor
public class SSHFSService: ObservableObject {
    public static let shared = SSHFSService()
    
    @Published public var activeMounts: [ActiveMountInfo] = []
    @Published public var mountStatuses: [UUID: MountStatus] = [:]
    
    private var timer: AnyCancellable?
    
    public init() {
        startPolling()
    }
    
    deinit {
        timer?.cancel()
    }
    
    public func startPolling() {
        refreshActiveMounts()
        timer = Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.refreshActiveMounts()
                }
            }
    }
    
    public func refreshActiveMounts() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/sbin/mount")
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            
            if let output = String(data: data, encoding: .utf8) {
                var mounts: [ActiveMountInfo] = []
                let lines = output.components(separatedBy: .newlines)
                for line in lines {
                    let parts = line.components(separatedBy: " on ")
                    if parts.count >= 2 {
                        let source = parts[0].trimmingCharacters(in: .whitespaces)
                        let rest = parts[1]
                        let localPath: String
                        if let parenIndex = rest.range(of: " (") {
                            localPath = String(rest[..<parenIndex.lowerBound]).trimmingCharacters(in: .whitespaces)
                        } else {
                            localPath = rest.trimmingCharacters(in: .whitespaces)
                        }
                        
                        let lowerLine = line.lowercased()
                        let lowerPath = localPath.lowercased()
                        
                        if lowerLine.contains("fuse") || lowerLine.contains("sshfs") || lowerLine.contains("nfs") ||
                           lowerPath.contains("/mounts/") {
                            let standardPath = (localPath as NSString).standardizingPath
                            if !mounts.contains(where: { ($0.localPath as NSString).standardizingPath.lowercased() == standardPath.lowercased() }) {
                                mounts.append(ActiveMountInfo(source: source, localPath: standardPath))
                            }
                        }
                    }
                }
                self.activeMounts = mounts
            }
        } catch {
            print("[SSHFSService] Error running mount: \(error)")
        }
    }
    
    public func isProfileMounted(_ profile: SSHProfile) -> Bool {
        let mountPath = (profile.defaultMountPath as NSString).standardizingPath.lowercased()
        return activeMounts.contains {
            let candidate = ($0.localPath as NSString).standardizingPath.lowercased()
            return candidate == mountPath
        }
    }
    
    public func mount(profile: SSHProfile, password: String? = nil) async throws {
        refreshActiveMounts()
        if isProfileMounted(profile) {
            NetworkRecoveryService.shared.recordIntendedMount(profile.id)
            if profile.createDesktopShortcut {
                DesktopShortcutService.shared.createShortcut(for: profile)
            }
            return
        }
        
        guard let sshfsBin = findSshfsBinary() else {
            throw NSError(
                domain: "SSHFSService",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "SSHFS binary is not installed. Please open 'Dependency Doctor' in Integra and run the installer in Terminal."]
            )
        }
        
        let targetPath = (profile.defaultMountPath as NSString).standardizingPath
        
        if !FileManager.default.fileExists(atPath: targetPath) {
            try FileManager.default.createDirectory(atPath: targetPath, withIntermediateDirectories: true)
        }
        
        let userSpec = profile.effectiveUser
        let trimmedHost = profile.host.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedHost.hasPrefix("-") && !userSpec.hasPrefix("-") else {
            throw NSError(
                domain: "SSHFSService",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Invalid host or username: cannot start with leading dash '-'."]
            )
        }
        
        let remoteSpec = "\(userSpec)@\(trimmedHost):\(profile.remotePath)"
        
        let rawVolName = profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? profile.host : profile.name
        let volName = rawVolName.replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: "/", with: "-")
        
        var args: [String] = [
            remoteSpec,
            targetPath,
            "-p", "\(profile.port)",
            "-o", "reconnect",
            "-o", "ServerAliveInterval=15",
            "-o", "ServerAliveCountMax=3",
            "-o", "StrictHostKeyChecking=accept-new",
            "-o", "ConnectTimeout=10",
            "-o", "volname=\(volName)",
            "-o", "defer_permissions",
            "-o", "follow_symlinks"
        ]
        
        switch profile.authMethod {
        case .none:
            break
        case .key:
            let keyPath = (profile.identityFile as NSString).expandingTildeInPath
            if !keyPath.isEmpty {
                args.append(contentsOf: ["-o", "IdentityFile=\(keyPath)"])
            }
            if let keyPassphrase = password, !keyPassphrase.isEmpty {
                args.append("-o")
                args.append("password_stdin")
            }
        case .password:
            args.append("-o")
            args.append("password_stdin")
        }
        
        let authPassword = password ?? (profile.authMethod == .password ? KeychainService.shared.getPassword(account: profile.id.uuidString) : nil)
        
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: sshfsBin)
            process.arguments = args
            
            let inputPipe = Pipe()
            let errPipe = Pipe()
            process.standardInput = inputPipe
            process.standardError = errPipe
            
            try process.run()
            
            if (profile.authMethod == .password || (profile.authMethod == .key && authPassword != nil)), let pass = authPassword {
                if let data = (pass + "\n").data(using: .utf8) {
                    try? inputPipe.fileHandleForWriting.write(contentsOf: data)
                    try? inputPipe.fileHandleForWriting.close()
                }
            }
            
            process.waitUntilExit()
            
            if process.terminationStatus != 0 {
                let errData = (try? errPipe.fileHandleForReading.readToEnd()) ?? Data()
                let errStr = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let finalErr = (errStr?.isEmpty == false) ? errStr! : "Mount failed with exit code \(process.terminationStatus)"
                throw NSError(domain: "SSHFSService", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: finalErr])
            }
        }.value
        
        // Create Desktop shortcut if profile has it enabled
        if profile.createDesktopShortcut {
            DesktopShortcutService.shared.createShortcut(for: profile)
        }
        
        // Developer & AI Tools: Inject AGENTS.md / CLAUDE.md and start control socket
        let settings = AppSettings()
        if settings.enableDeveloperAITools {
            AgentInstructionService.shared.injectInstructions(for: profile)
            try? await RemoteExecService.shared.startControlSocket(for: profile)
        }
        
        // Record intended mount for network recovery engine
        NetworkRecoveryService.shared.recordIntendedMount(profile.id)
        
        refreshActiveMounts()
        mountStatuses[profile.id] = MountStatus(profileId: profile.id, isMounted: true, mountedPath: targetPath, mountedAt: Date())
    }
    
    public func unmount(profile: SSHProfile, force: Bool = false, isUserInitiated: Bool = true) async throws {
        let targetPath = (profile.defaultMountPath as NSString).standardizingPath
        
        // Clean up AGENTS.md and CLAUDE.md instructions before unmounting
        AgentInstructionService.shared.removeInstructions(for: profile)
        
        // Stop any active control master sockets and port tunnels
        RemoteExecService.shared.stopControlSocket(for: profile)
        SSHTunnelService.shared.stopTunnels(for: profile)
        
        // If user initiated, remove Desktop shortcut and clear intended mount
        if isUserInitiated {
            if profile.createDesktopShortcut {
                DesktopShortcutService.shared.removeShortcut(for: profile)
            }
            NetworkRecoveryService.shared.recordIntendedUnmount(profile.id)
        }
        
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            
            if force {
                process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
                process.arguments = ["unmount", "force", targetPath]
            } else {
                process.executableURL = URL(fileURLWithPath: "/sbin/umount")
                process.arguments = [targetPath]
            }
            
            let errPipe = Pipe()
            process.standardError = errPipe
            
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus != 0 {
                let forceProc = Process()
                forceProc.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
                forceProc.arguments = ["unmount", "force", targetPath]
                try? forceProc.run()
                forceProc.waitUntilExit()
            }
        }.value
        
        refreshActiveMounts()
        mountStatuses[profile.id] = MountStatus(profileId: profile.id, isMounted: false, mountedPath: targetPath)
    }
    
    private func findSshfsBinary() -> String? {
        let candidatePaths = [
            "/usr/local/bin/sshfs",
            "/opt/homebrew/bin/sshfs",
            "/usr/bin/sshfs"
        ]
        for path in candidatePaths {
            if FileManager.default.fileExists(atPath: path) && FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }
}
