import Foundation
import Network
import AppKit
import Combine

@MainActor
public class NetworkRecoveryService: ObservableObject {
    public static let shared = NetworkRecoveryService()
    
    @Published public var isNetworkAvailable: Bool = true
    @Published public var isRecovering: Bool = false
    @Published public var recoveryStatusMessage: String?
    
    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.integra.app.network-monitor", qos: .utility)
    private var lastPathStatus: NWPath.Status = .requiresConnection
    
    public var intendedMounts: Set<UUID> = []
    private var activeRecoveryTasks: [UUID: Task<Void, Never>] = [:]
    
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        startMonitoring()
        registerWorkspaceNotifications()
    }
    
    deinit {
        pathMonitor.cancel()
    }
    
    public func recordIntendedMount(_ profileId: UUID) {
        intendedMounts.insert(profileId)
    }
    
    public func recordIntendedUnmount(_ profileId: UUID) {
        intendedMounts.remove(profileId)
        activeRecoveryTasks[profileId]?.cancel()
        activeRecoveryTasks.removeValue(forKey: profileId)
    }
    
    private func startMonitoring() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let isSatisfied = (path.status == .satisfied)
                let previousStatus = self.lastPathStatus
                self.lastPathStatus = path.status
                self.isNetworkAvailable = isSatisfied
                
                // Trigger recovery if transitioning from down to up
                if isSatisfied && previousStatus != .satisfied && previousStatus != .requiresConnection {
                    self.triggerRecovery(reason: "Network connectivity restored")
                }
            }
        }
        pathMonitor.start(queue: monitorQueue)
    }
    
    private func registerWorkspaceNotifications() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                // Delay 2.5 seconds after wake to allow Wi-Fi & Tailscale negotiation
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                self?.triggerRecovery(reason: "System woke from sleep")
            }
        }
    }
    
    public func triggerRecovery(reason: String) {
        guard !intendedMounts.isEmpty else { return }
        IntegraLogger.shared.log("[NetworkRecoveryService] Triggering automatic recovery: \(reason)")
        
        let appSettings = AppSettings.shared
        guard appSettings.autoReconnectOnRecovery else { return }
        
        let store = ProfileStore.shared
        let sshfsService = SSHFSService.shared
        
        for profileId in intendedMounts {
            if let profile = store.profiles.first(where: { $0.id == profileId }) {
                if !sshfsService.isProfileMounted(profile) {
                    recoverMountWithBackoff(profile: profile, sshfsService: sshfsService, attempt: 0)
                }
            }
        }
        
        // Recover any dropped OpenSSH ControlMaster sockets and Port Forwarding Tunnels
        RemoteExecService.shared.recoverControlSocketsIfNeeded(store: store)
        SSHTunnelService.shared.recoverTunnelsIfNeeded(store: store)
    }
    
    private func recoverMountWithBackoff(profile: SSHProfile, sshfsService: SSHFSService, attempt: Int) {
        activeRecoveryTasks[profile.id]?.cancel()
        
        let maxAttempts = 6
        guard attempt < maxAttempts else {
            print("[NetworkRecoveryService] Max retry attempts reached for \(profile.name)")
            isRecovering = false
            recoveryStatusMessage = nil
            return
        }
        
        // Exponential backoff: 1.5s, 3s, 6s, 12s, 24s, 30s
        let delaySeconds = min(30.0, 1.5 * pow(2.0, Double(attempt)))
        
        isRecovering = true
        recoveryStatusMessage = "Reconnecting to \(profile.name) in \(Int(delaySeconds))s..."
        
        activeRecoveryTasks[profile.id] = Task {
            try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            
            // Clean any stale mount handles before remounting WITHOUT canceling recovery
            try? await sshfsService.unmount(profile: profile, force: true, isUserInitiated: false)
            
            do {
                try await sshfsService.mount(profile: profile)
                print("[NetworkRecoveryService] Successfully recovered connection to \(profile.name)")
                self.isRecovering = false
                self.recoveryStatusMessage = nil
                self.activeRecoveryTasks.removeValue(forKey: profile.id)
                
                // Reconnect socket for AI bridge on successful mount recovery
                if AppSettings.shared.enableDeveloperAITools {
                    try? await RemoteExecService.shared.startControlSocket(for: profile)
                }
                
                // Reconnect port tunnels if configured
                if profile.portTunnels.contains(where: { $0.isEnabled }) {
                    try? await SSHTunnelService.shared.startTunnels(for: profile)
                }
            } catch {
                print("[NetworkRecoveryService] Recovery attempt \(attempt + 1) failed for \(profile.name): \(error.localizedDescription)")
                self.recoverMountWithBackoff(profile: profile, sshfsService: sshfsService, attempt: attempt + 1)
            }
        }
    }
}
