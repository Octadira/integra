import Foundation
import Security

public class KeychainService {
    public static let shared = KeychainService()
    private let serviceName = "com.integra.app"
    private let legacyServiceName = "com.octadira.integra"
    
    private init() {}
    
    public func savePassword(account: String, password: String) -> Bool {
        guard let data = password.data(using: .utf8) else { return false }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]
        
        SecItemDelete(query as CFDictionary)
        
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(attributes as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    public func getPassword(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data, let password = String(data: data, encoding: .utf8) {
            return password
        }
        
        // Fallback for legacy items during migration
        let legacyQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: legacyServiceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var legacyDataRef: AnyObject?
        if SecItemCopyMatching(legacyQuery as CFDictionary, &legacyDataRef) == errSecSuccess,
           let data = legacyDataRef as? Data,
           let password = String(data: data, encoding: .utf8) {
            _ = savePassword(account: account, password: password)
            return password
        }
        
        // Resilient fallback for helper tools (integra-mcp) across security sandboxes
        if let cliPassword = getPasswordViaSecurityCLI(service: serviceName, account: account), !cliPassword.isEmpty {
            return cliPassword
        }
        if let legacyCliPassword = getPasswordViaSecurityCLI(service: legacyServiceName, account: account), !legacyCliPassword.isEmpty {
            _ = savePassword(account: account, password: legacyCliPassword)
            return legacyCliPassword
        }
        
        return nil
    }
    
    private func getPasswordViaSecurityCLI(service: String, account: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", service, "-a", account, "-w"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (output?.isEmpty ?? true) ? nil : output
        } catch {
            return nil
        }
    }
    
    public func deletePassword(account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // MARK: - Sudo Specific Keychain Helpers
    
    public func saveSudoPassword(for profileId: UUID, password: String) -> Bool {
        return savePassword(account: "sudo_\(profileId.uuidString)", password: password)
    }
    
    public func getSudoPassword(for profileId: UUID) -> String? {
        return getPassword(account: "sudo_\(profileId.uuidString)")
    }
    
    public func deleteSudoPassword(for profileId: UUID) -> Bool {
        return deletePassword(account: "sudo_\(profileId.uuidString)")
    }
    
    public func getEffectiveSudoPassword(for profile: SSHProfile) -> String? {
        if let explicitSudo = getSudoPassword(for: profile.id), !explicitSudo.isEmpty {
            return explicitSudo
        }
        if profile.useSSHPasswordForSudo {
            return getPassword(account: profile.id.uuidString)
        }
        return nil
    }
}

