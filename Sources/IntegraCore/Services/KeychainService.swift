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
        
        return nil
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

