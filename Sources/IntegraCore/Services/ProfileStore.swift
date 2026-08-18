import Foundation
import Combine

@MainActor
public class ProfileStore: ObservableObject {
    public static let shared = ProfileStore()
    
    @Published public var profiles: [SSHProfile] = [] {
        didSet {
            saveProfiles()
        }
    }
    
    private let saveKey = "Integra_SSHProfiles_v1"
    
    private var applicationSupportURL: URL {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory() + "/Library/Application Support")
        let integraDir = appSupport.appendingPathComponent("Integra", isDirectory: true)
        if !fileManager.fileExists(atPath: integraDir.path) {
            try? fileManager.createDirectory(at: integraDir, withIntermediateDirectories: true)
        }
        return integraDir.appendingPathComponent("profiles.json")
    }
    
    public init() {
        loadProfiles()
    }
    
    public func addProfile(_ profile: SSHProfile) {
        profiles.append(profile)
    }
    
    public func updateProfile(_ profile: SSHProfile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        }
    }
    
    public func deleteProfile(id: UUID) {
        profiles.removeAll { $0.id == id }
        _ = KeychainService.shared.deletePassword(account: id.uuidString)
    }
    
    public func importSSHConfigEntries() {
        let entries = SSHConfigParser.parseUserSSHConfig()
        for entry in entries {
            let host = entry.hostName ?? entry.host
            let user = entry.user ?? NSUserName()
            let port = entry.port ?? 22
            let keyFile = entry.identityFile ?? "~/.ssh/id_rsa"
            
            if !profiles.contains(where: { $0.host == host && $0.user == user }) {
                let profile = SSHProfile(
                    name: entry.host,
                    host: host,
                    port: port,
                    user: user,
                    authMethod: .key,
                    remotePath: "/",
                    identityFile: keyFile
                )
                profiles.append(profile)
            }
        }
    }
    
    private func loadProfiles() {
        // 1. Primary: Load from Application Support/Integra/profiles.json
        let fileURL = applicationSupportURL
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([SSHProfile].self, from: data) {
            self.profiles = decoded
            return
        }
        
        // 2. Fallback: Load from UserDefaults for legacy/migration
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([SSHProfile].self, from: data) {
            self.profiles = decoded
            saveProfiles() // Migrate immediately to Application Support file
            UserDefaults.standard.removeObject(forKey: saveKey) // Purge legacy UserDefaults copy (M-4 fix)
        }
    }
    
    private func saveProfiles() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let encoded = try? encoder.encode(profiles) {
            // Write solely to persistent Application Support JSON file
            let fileURL = applicationSupportURL
            try? encoded.write(to: fileURL, options: .atomic)
        }
    }
}
