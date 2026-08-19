import Foundation
import AppKit
import Combine

@MainActor
public class UpdateCheckerService: ObservableObject {
    public static let shared = UpdateCheckerService()
    
    public static let currentVersion: String = "0.13.0"
    
    @Published public var isChecking: Bool = false
    @Published public var updateAvailable: Bool = false
    @Published public var latestVersion: String? = nil
    @Published public var lastCheckDate: Date? = nil
    @Published public var statusMessage: String? = nil
    
    private var periodicTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private let checkIntervalSeconds: TimeInterval = 86400 // 24 hours
    private let userDefaultsKeyTimestamp = "integra_last_update_check_timestamp"
    private let userDefaultsKeyAutoCheck = "integra_auto_check_updates_enabled"
    
    public var isAutoCheckEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: userDefaultsKeyAutoCheck) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: userDefaultsKeyAutoCheck)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: userDefaultsKeyAutoCheck)
        }
    }
    
    public init() {
        let savedTimestamp = UserDefaults.standard.double(forKey: userDefaultsKeyTimestamp)
        if savedTimestamp > 0 {
            self.lastCheckDate = Date(timeIntervalSince1970: savedTimestamp)
        }
        
        setupLifecycleObservers()
        setupPeriodicTimer()
        
        // Initial silent check on startup if due
        Task {
            checkIfDue()
        }
    }
    
    private func setupLifecycleObservers() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkIfDue()
            }
        }
    }
    
    private func setupPeriodicTimer() {
        // Evaluate every hour if the 24-hour interval has elapsed
        periodicTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkIfDue()
            }
        }
    }
    
    public func checkIfDue() {
        guard isAutoCheckEnabled else { return }
        
        if let lastCheck = lastCheckDate {
            let elapsed = Date().timeIntervalSince(lastCheck)
            if elapsed >= checkIntervalSeconds {
                Task {
                    await checkForUpdates(manual: false)
                }
            }
        } else {
            Task {
                await checkForUpdates(manual: false)
            }
        }
    }
    
    public func checkForUpdates(manual: Bool = false) async {
        guard !isChecking else { return }
        
        isChecking = true
        if manual {
            statusMessage = "Checking for updates..."
        }
        
        let remoteTag = await fetchLatestReleaseTag()
        
        isChecking = false
        lastCheckDate = Date()
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: userDefaultsKeyTimestamp)
        
        if let remote = remoteTag {
            let cleanRemote = Self.cleanVersionString(remote)
            let cleanCurrent = Self.cleanVersionString(UpdateCheckerService.currentVersion)
            
            if Self.isVersion(cleanRemote, newerThan: cleanCurrent) {
                self.updateAvailable = true
                self.latestVersion = "v\(cleanRemote)"
                self.statusMessage = "New version v\(cleanRemote) is available."
            } else {
                self.updateAvailable = false
                self.latestVersion = nil
                self.statusMessage = "Integra is up to date (v\(cleanCurrent))."
            }
        } else {
            if manual {
                self.statusMessage = "Could not check for updates. Check internet connection."
            }
        }
    }
    
    private func fetchLatestReleaseTag() async -> String? {
        let githubURL = URL(string: "https://api.github.com/repos/Octadira/integra/releases/latest")!
        var request = URLRequest(url: githubURL)
        request.timeoutInterval = 8.0
        request.setValue("Integra-macOS/\(UpdateCheckerService.currentVersion)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let tagName = json["tag_name"] as? String {
                    return tagName
                }
            }
        } catch {
            // Fallback to Forgejo API if GitHub fails
            let forgejoURL = URL(string: "https://forgejo.xantu-everest.ts.net/api/v1/repos/octadira/integra/releases/latest")!
            var forgejoReq = URLRequest(url: forgejoURL)
            forgejoReq.timeoutInterval = 5.0
            if let (data, response) = try? await URLSession.shared.data(for: forgejoReq),
               let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let tagName = json["tag_name"] as? String {
                    return tagName
                }
            }
        }
        return nil
    }
    
    // MARK: - Version Comparison Helpers
    
    public static func cleanVersionString(_ version: String) -> String {
        return version
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "^v", with: "", options: .regularExpression)
    }
    
    public static func isVersion(_ remote: String, newerThan current: String) -> Bool {
        let cleanRemote = cleanVersionString(remote)
        let cleanCurrent = cleanVersionString(current)
        
        let remoteParts = cleanRemote.split(separator: ".").compactMap { Int($0) }
        let currentParts = cleanCurrent.split(separator: ".").compactMap { Int($0) }
        
        let maxCount = max(remoteParts.count, currentParts.count)
        
        for i in 0..<maxCount {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let c = i < currentParts.count ? currentParts[i] : 0
            
            if r > c {
                return true
            } else if r < c {
                return false
            }
        }
        return false
    }
}
