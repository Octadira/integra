import Foundation
import AppKit
import LocalAuthentication

public struct SudoAuthResult {
    public let isGranted: Bool
    public let sudoPassword: String?
    public let errorMessage: String?
    
    public init(isGranted: Bool, sudoPassword: String? = nil, errorMessage: String? = nil) {
        self.isGranted = isGranted
        self.sudoPassword = sudoPassword
        self.errorMessage = errorMessage
    }
}

public final class SudoAuthManager: @unchecked Sendable {
    public static let shared = SudoAuthManager()
    
    // In-memory grace period cache (15 minutes = 900 seconds)
    private var sessionCache: [UUID: Date] = [:]
    private let cacheDuration: TimeInterval = 900 // 15 minutes
    private let lock = NSLock()
    
    private init() {}
    
    public func isSessionValid(for profileId: UUID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        guard let timestamp = sessionCache[profileId] else { return false }
        if Date().timeIntervalSince(timestamp) < cacheDuration {
            return true
        } else {
            sessionCache.removeValue(forKey: profileId)
            return false
        }
    }
    
    public func recordAuthorization(for profileId: UUID) {
        lock.lock()
        defer { lock.unlock() }
        sessionCache[profileId] = Date()
    }
    
    public func clearAuthorization(for profileId: UUID) {
        lock.lock()
        defer { lock.unlock() }
        sessionCache.removeValue(forKey: profileId)
    }
    
    public func clearAllAuthorizations() {
        lock.lock()
        defer { lock.unlock() }
        sessionCache.removeAll()
    }
    
    public func authorizeAndGetPassword(profile: SSHProfile, command: String) async -> SudoAuthResult {
        let isRootUser = profile.effectiveUser.lowercased() == "root"
        let existingPassword = isRootUser ? nil : KeychainService.shared.getEffectiveSudoPassword(for: profile)
        
        switch profile.sudoAuthPolicy {
        case .autoApprove:
            recordAuthorization(for: profile.id)
            if isRootUser {
                return SudoAuthResult(isGranted: true, sudoPassword: nil)
            }
            if let pass = existingPassword, !pass.isEmpty {
                return SudoAuthResult(isGranted: true, sudoPassword: pass)
            }
            // Auto-Approve policy guarantees non-interactive execution (uses passwordless sudo if no password stored)
            return SudoAuthResult(isGranted: true, sudoPassword: nil)
            
        case .sessionCache:
            if isSessionValid(for: profile.id) {
                if isRootUser {
                    return SudoAuthResult(isGranted: true, sudoPassword: nil)
                }
                if let pass = existingPassword, !pass.isEmpty {
                    return SudoAuthResult(isGranted: true, sudoPassword: pass)
                }
            }
            return await promptForSudo(profile: profile, command: command, savedPassword: existingPassword, isRootUser: isRootUser)
            
        case .touchIDOrPrompt:
            return await promptForSudo(profile: profile, command: command, savedPassword: existingPassword, isRootUser: isRootUser)
        }
    }
    
    public static func sanitizeForAppleScript(_ input: String) -> String {
        return input
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
    
    private func promptForSudo(profile: SSHProfile, command: String, savedPassword: String?, isRootUser: Bool = false) async -> SudoAuthResult {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // If password exists or user is root, try Touch ID / Biometrics first if available
                if isRootUser || (savedPassword != nil && !savedPassword!.isEmpty) {
                    let laContext = LAContext()
                    var error: NSError?
                    
                    if laContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
                        let reason = isRootUser ?
                            "Authorize AI Agent administrative execution on \(profile.name) (root)" :
                            "Authorize AI Agent sudo execution on \(profile.name)"
                        let semaphore = DispatchSemaphore(value: 0)
                        var biometricSuccess = false
                        
                        laContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
                            biometricSuccess = success
                            semaphore.signal()
                        }
                        semaphore.wait()
                        
                        if biometricSuccess {
                            SudoAuthManager.shared.recordAuthorization(for: profile.id)
                            continuation.resume(returning: SudoAuthResult(isGranted: true, sudoPassword: savedPassword))
                            return
                        }
                    }
                }
                
                // Fallback / GUI Dialog via AppleScript for universal cross-process display
                let serverDesc = profile.name.isEmpty ? profile.host : "\(profile.name) (\(profile.effectiveUser)@\(profile.host))"
                let escapedCommand = Self.sanitizeForAppleScript(command)
                let escapedServer = Self.sanitizeForAppleScript(serverDesc)
                
                if isRootUser {
                    // For root user: only authorization confirmation is needed (no password input needed)
                    let script = """
                    tell application "System Events"
                        activate
                        set res to display dialog "AI Assistant requested administrative command on root account:\n\(escapedServer)\n\nCommand:\n\(escapedCommand)\n\nAuthorize execution?" with title "Integra — Root Authorization" buttons {"Cancel", "Authorize"} default button "Authorize" with icon caution
                        return button returned of res
                    end tell
                    """
                    
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                    process.arguments = ["-e", script]
                    let pipe = Pipe()
                    process.standardOutput = pipe
                    
                    do {
                        try process.run()
                        process.waitUntilExit()
                        let data = pipe.fileHandleForReading.readDataToEndOfFile()
                        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        
                        if process.terminationStatus == 0 && output == "Authorize" {
                            SudoAuthManager.shared.recordAuthorization(for: profile.id)
                            continuation.resume(returning: SudoAuthResult(isGranted: true, sudoPassword: nil))
                        } else {
                            continuation.resume(returning: SudoAuthResult(isGranted: false, errorMessage: "Execution cancelled by user."))
                        }
                    } catch {
                        continuation.resume(returning: SudoAuthResult(isGranted: false, errorMessage: "Failed to present authorization dialog: \(error.localizedDescription)"))
                    }
                } else if let pass = savedPassword, !pass.isEmpty {
                    let script = """
                    tell application "System Events"
                        activate
                        set res to display dialog "AI Assistant requested sudo execution on:\n\(escapedServer)\n\nCommand:\n\(escapedCommand)\n\nAuthorize execution using saved Keychain credentials?" with title "Integra — Sudo Authorization" buttons {"Cancel", "Authorize"} default button "Authorize" with icon caution
                        return button returned of res
                    end tell
                    """
                    
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                    process.arguments = ["-e", script]
                    let pipe = Pipe()
                    process.standardOutput = pipe
                    
                    do {
                        try process.run()
                        process.waitUntilExit()
                        let data = pipe.fileHandleForReading.readDataToEndOfFile()
                        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        
                        if process.terminationStatus == 0 && output == "Authorize" {
                            SudoAuthManager.shared.recordAuthorization(for: profile.id)
                            continuation.resume(returning: SudoAuthResult(isGranted: true, sudoPassword: pass))
                        } else {
                            continuation.resume(returning: SudoAuthResult(isGranted: false, errorMessage: "Execution cancelled by user."))
                        }
                    } catch {
                        continuation.resume(returning: SudoAuthResult(isGranted: false, errorMessage: "Failed to present authorization dialog: \(error.localizedDescription)"))
                    }
                } else {
                    // Password not in Keychain: ask user to enter sudo password and optionally save it
                    let script = """
                    tell application "System Events"
                        activate
                        set res to display dialog "AI Assistant requested sudo execution on:\n\(escapedServer)\n\nCommand:\n\(escapedCommand)\n\nPlease enter the sudo password for \(escapedServer):" with title "Integra — Sudo Password Required" default answer "" with hidden answer buttons {"Cancel", "Authorize & Save"} default button "Authorize & Save" with icon caution
                        return (text returned of res) & ":::" & (button returned of res)
                    end tell
                    """
                    
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                    process.arguments = ["-e", script]
                    let pipe = Pipe()
                    process.standardOutput = pipe
                    
                    do {
                        try process.run()
                        process.waitUntilExit()
                        let data = pipe.fileHandleForReading.readDataToEndOfFile()
                        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        
                        if process.terminationStatus == 0 {
                            let parts = output.components(separatedBy: ":::")
                            let enteredPassword = parts.first ?? ""
                            let button = parts.count > 1 ? parts[1] : ""
                            
                            if button == "Authorize & Save" || button == "Authorize" {
                                if !enteredPassword.isEmpty {
                                    _ = KeychainService.shared.saveSudoPassword(for: profile.id, password: enteredPassword)
                                    SudoAuthManager.shared.recordAuthorization(for: profile.id)
                                    continuation.resume(returning: SudoAuthResult(isGranted: true, sudoPassword: enteredPassword))
                                } else {
                                    // Empty password authorization (for passwordless / NOPASSWD servers)
                                    SudoAuthManager.shared.recordAuthorization(for: profile.id)
                                    continuation.resume(returning: SudoAuthResult(isGranted: true, sudoPassword: nil))
                                }
                                return
                            }
                        }
                        continuation.resume(returning: SudoAuthResult(isGranted: false, errorMessage: "Execution cancelled by user."))
                    } catch {
                        continuation.resume(returning: SudoAuthResult(isGranted: false, errorMessage: "Failed to present password prompt: \(error.localizedDescription)"))
                    }
                }
            }
        }
    }
}
