import Foundation
import SwiftUI
import AppKit

@MainActor
public class RemoteExecService: ObservableObject {
    public static let shared = RemoteExecService()
    
    @Published public var isExecuting: [UUID: Bool] = [:]
    @Published public var lastOutput: [UUID: String] = [:]
    @Published public var isStartingSocket: [UUID: Bool] = [:]
    
    private var watchdogTimer: Timer?
    
    public init() {
        installCLIHelperIfNeeded()
        startWatchdog()
    }
    
    private func startWatchdog() {
        watchdogTimer = Timer.scheduledTimer(withTimeInterval: 25.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.performSocketHealthCheck()
            }
        }
    }
    
    public func performSocketHealthCheck() {
        let store = ProfileStore.shared
        let sshfsService = SSHFSService.shared
        
        for profile in store.profiles {
            if sshfsService.isProfileMounted(profile) {
                let socketPath = profile.controlSocketPath
                if !FileManager.default.fileExists(atPath: socketPath) && isStartingSocket[profile.id] != true {
                    IntegraLogger.shared.log("[RemoteExecService] Socket missing for active mount \(profile.name); auto-reconnecting...")
                    Task {
                        try? await self.startControlSocket(for: profile)
                    }
                }
            }
        }
    }
    
    public func startControlSocket(for profile: SSHProfile) async throws {
        let socketPath = profile.controlSocketPath
        let socketDir = (socketPath as NSString).deletingLastPathComponent
        
        // Ensure private socket directory exists with strict 0700 permissions
        if !FileManager.default.fileExists(atPath: socketDir) {
            try? FileManager.default.createDirectory(atPath: socketDir, withIntermediateDirectories: true)
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: socketDir)
        }
        
        // Clean stale socket file if present
        if FileManager.default.fileExists(atPath: socketPath) {
            try? FileManager.default.removeItem(atPath: socketPath)
        }
        
        isStartingSocket[profile.id] = true
        defer { isStartingSocket[profile.id] = false }
        
        var args: [String] = [
            "-N", // No remote command
            "-f", // Fork into background
            "-M", // Master mode for connection sharing
            "-S", socketPath,
            "-p", "\(profile.port)",
            "-o", "ControlPersist=yes", // Stay open indefinitely until unmount
            "-o", "ServerAliveInterval=20",
            "-o", "ServerAliveCountMax=6",
            "-o", "TCPKeepAlive=yes",
            "-o", "StrictHostKeyChecking=accept-new",
            "-o", "ConnectTimeout=10",
            "-o", "BatchMode=yes"
        ]
        
        switch profile.authMethod {
        case .none:
            break
        case .key:
            let keyPath = (profile.identityFile as NSString).expandingTildeInPath
            if !keyPath.isEmpty {
                args.append(contentsOf: ["-i", keyPath])
            }
        case .password:
            break
        }
        
        let userSpec = profile.effectiveUser
        let destination = "\(userSpec)@\(profile.host)"
        args.append(destination)
        
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
            process.arguments = args
            
            let errPipe = Pipe()
            process.standardError = errPipe
            process.standardInput = Pipe() // Ensure stdin is closed
            
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus != 0 {
                let errData = (try? errPipe.fileHandleForReading.readToEnd()) ?? Data()
                let errStr = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                throw NSError(
                    domain: "RemoteExecService",
                    code: Int(process.terminationStatus),
                    userInfo: [NSLocalizedDescriptionKey: errStr.isEmpty ? "Failed to establish OpenSSH Control Socket (Exit \(process.terminationStatus))" : errStr]
                )
            }
            
            // Save mount mapping file for exact path matching in integra-exec (M-3 Fix)
            let mountPath = (profile.defaultMountPath as NSString).standardizingPath
            try? mountPath.write(toFile: profile.controlMountMapPath, atomically: true, encoding: .utf8)
        }.value
    }
    
    public func stopControlSocket(for profile: SSHProfile) {
        let socketPath = profile.controlSocketPath
        let mapPath = profile.controlMountMapPath
        let destination = "\(profile.effectiveUser)@\(profile.host)"
        
        Task.detached(priority: .userInitiated) {
            if FileManager.default.fileExists(atPath: socketPath) {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
                process.arguments = ["-O", "exit", "-S", socketPath, destination]
                try? process.run()
                process.waitUntilExit()
                try? FileManager.default.removeItem(atPath: socketPath)
            }
            if FileManager.default.fileExists(atPath: mapPath) {
                try? FileManager.default.removeItem(atPath: mapPath)
            }
        }
    }
    
    public func isSocketActive(for profile: SSHProfile) -> Bool {
        let socketPath = profile.controlSocketPath
        return FileManager.default.fileExists(atPath: socketPath)
    }
    
    public func recoverControlSocketsIfNeeded(store: ProfileStore) {
        Task {
            // Short grace period to let network routes and DNS stabilize
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            for profile in store.profiles {
                if SSHFSService.shared.isProfileMounted(profile) {
                    try? await self.startControlSocket(for: profile)
                }
            }
        }
    }
    
    public func executeCommand(profile: SSHProfile, command: String, targetSubpath: String? = nil) async -> String {
        isExecuting[profile.id] = true
        defer { isExecuting[profile.id] = false }
        
        let socketPath = profile.controlSocketPath
        let destination = "\(profile.effectiveUser)@\(profile.host)"
        
        if !FileManager.default.fileExists(atPath: socketPath) {
            do {
                try await startControlSocket(for: profile)
            } catch {
                let msg = "Error: Control socket is not active and could not be started: \(error.localizedDescription)"
                lastOutput[profile.id] = msg
                return msg
            }
        }
        
        return await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
            
            var remoteCmd = command
            if let subpath = targetSubpath, !subpath.isEmpty {
                let escapedSubpath = subpath.replacingOccurrences(of: "'", with: "'\\''")
                remoteCmd = "if [ -d '\(escapedSubpath)' ]; then cd '\(escapedSubpath)'; fi && \(command)"
            }
            
            process.arguments = [
                "-S", socketPath,
                "-p", "\(profile.port)",
                "-o", "BatchMode=yes",
                "-o", "ConnectTimeout=8",
                destination,
                remoteCmd
            ]
            
            let outPipe = Pipe()
            let errPipe = Pipe()
            let inPipe = Pipe()
            
            process.standardOutput = outPipe
            process.standardError = errPipe
            process.standardInput = inPipe
            
            try? inPipe.fileHandleForWriting.close()
            
            do {
                try process.run()
            } catch {
                return "Failed to launch process: \(error.localizedDescription)"
            }
            
            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                if process.isRunning {
                    process.terminate()
                }
            }
            
            process.waitUntilExit()
            timeoutTask.cancel()
            
            let outData = (try? outPipe.fileHandleForReading.readToEnd()) ?? Data()
            let errData = (try? errPipe.fileHandleForReading.readToEnd()) ?? Data()
            
            let outStr = String(data: outData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let errStr = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            let result = outStr.isEmpty ? (errStr.isEmpty ? "(Command executed successfully with no output)" : errStr) : (errStr.isEmpty ? outStr : "\(outStr)\n\n[STDERR]:\n\(errStr)")
            
            Task { @MainActor in
                self.lastOutput[profile.id] = result
            }
            
            return outStr.isEmpty ? (errStr.isEmpty ? "(Command executed successfully with no output)" : errStr) : outStr
        }.value
    }
    
    public func installCLIHelperIfNeeded() {
        let home = NSHomeDirectory()
        let binDir = "\(home)/.local/bin"
        let scriptPath = "\(binDir)/integra-exec"
        
        try? FileManager.default.createDirectory(atPath: binDir, withIntermediateDirectories: true)
        
        let scriptContent = #"""
        #!/bin/bash
        # Integra Remote Command Execution Bridge for macOS & AI Agents

        if [ "$#" -eq 0 ]; then
            echo "Usage: integra-exec <command...>"
            echo "Executes commands directly on the connected remote Linux/SSH host from inside any mounted directory."
            exit 1
        fi

        CURRENT_DIR="$(pwd -P)"
        SOCKET_DIR="$HOME/.ssh/integra/sock"

        # Determine interactive pseudo-terminal flag (-t vs -T)
        if [ -t 0 ] && [ -t 1 ]; then
            SSH_TTY_OPT="-t"
        else
            SSH_TTY_OPT="-T"
        fi

        FOUND_SOCKET=""
        REMOTE_SUBPATH=""

        if [ -d "$SOCKET_DIR" ]; then
            # Check all registered active mount maps for exact directory matching (M-3 Fix)
            for MAP_FILE in "$SOCKET_DIR"/i_*.mount; do
                if [ -f "$MAP_FILE" ]; then
                    MOUNT_PATH="$(cat "$MAP_FILE" 2>/dev/null)"
                    SOCK="${MAP_FILE%.mount}.sock"
                    
                    if [ -S "$SOCK" ] && [ -n "$MOUNT_PATH" ]; then
                        # Exact directory or subfolder matching
                        if [ "$CURRENT_DIR" = "$MOUNT_PATH" ]; then
                            FOUND_SOCKET="$SOCK"
                            REMOTE_SUBPATH=""
                            break
                        elif [[ "$CURRENT_DIR" == "$MOUNT_PATH/"* ]]; then
                            FOUND_SOCKET="$SOCK"
                            REMOTE_SUBPATH="${CURRENT_DIR#$MOUNT_PATH}"
                            break
                        fi
                    fi
                fi
            done
        fi

        # Strict validation: Reject execution outside mounted directory (C-2 fix)
        if [ -z "$FOUND_SOCKET" ] || [ ! -S "$FOUND_SOCKET" ]; then
            echo "Error: Current directory is not inside any active Integra mounted server directory (~/Mounts/<Server>)." >&2
            echo "Please navigate (cd) into a mounted directory before executing integra-exec." >&2
            exit 1
        fi

        # Securely escape directory subpath against command injection (C-1 fix)
        REMOTE_PREFIX=""
        if [ -n "$REMOTE_SUBPATH" ]; then
            SQ="'"
            REPL="'\\''"
            ESCAPED_SUBPATH="${REMOTE_SUBPATH//$SQ/$REPL}"
            REMOTE_PREFIX="if [ -d '$ESCAPED_SUBPATH' ]; then cd '$ESCAPED_SUBPATH'; fi; "
        fi

        # Pass command string naturally to remote login shell (supporting &&, |, quotes, etc.)
        ssh $SSH_TTY_OPT -S "$FOUND_SOCKET" placeholder "${REMOTE_PREFIX}$*"
        exit $?
        """#
        
        try? scriptContent.write(toFile: scriptPath, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath)
    }
}
