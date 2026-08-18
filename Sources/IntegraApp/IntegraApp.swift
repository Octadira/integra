import SwiftUI
import AppKit
import IntegraCore

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        IntegraLogger.shared.log("Application finished launching via AppDelegate. Initializing background services...")
        
        Task { @MainActor in
            let store = ProfileStore.shared
            let sshfs = SSHFSService.shared
            let settings = AppSettings.shared
            
            // 1. Sync launch at login state
            LaunchAtLoginService.shared.setLaunchAtLogin(enabled: settings.launchAtLogin)
            
            // 2. Pre-register auto-mount profiles with recovery engine
            for profile in store.profiles where profile.autoMount {
                NetworkRecoveryService.shared.recordIntendedMount(profile.id)
            }
            
            // 3. Perform background auto-mount on startup
            performBackgroundStartupMount(store: store, sshfs: sshfs)
        }
    }
    
    @MainActor
    private func performBackgroundStartupMount(store: ProfileStore, sshfs: SSHFSService) {
        Task {
            let autoMountProfiles = store.profiles.filter { $0.autoMount }
            guard !autoMountProfiles.isEmpty else {
                IntegraLogger.shared.log("No profiles configured with autoMount: true. Background startup mount skipped.")
                return
            }
            
            IntegraLogger.shared.log("Starting resilient background auto-mount for \(autoMountProfiles.count) profile(s)...")
            
            // Try connecting with progressive retries during boot (allowing Tailscale/Wi-Fi/DNS to initialize)
            let delays: [Double] = [1.5, 3.0, 5.0, 8.0, 12.0, 18.0]
            
            for (index, delay) in delays.enumerated() {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
                var allMounted = true
                for profile in autoMountProfiles {
                    sshfs.refreshActiveMounts()
                    if !sshfs.isProfileMounted(profile) {
                        IntegraLogger.shared.log("Attempting startup mount for '\(profile.name)' (Attempt \(index + 1)/\(delays.count))...")
                        do {
                            try await sshfs.mount(profile: profile)
                            IntegraLogger.shared.log("Successfully auto-mounted '\(profile.name)' on startup!")
                        } catch {
                            IntegraLogger.shared.log("Startup mount attempt \(index + 1) for '\(profile.name)' failed: \(error.localizedDescription)")
                            allMounted = false
                        }
                    } else {
                        IntegraLogger.shared.log("Profile '\(profile.name)' is already mounted.")
                        if profile.createDesktopShortcut {
                            DesktopShortcutService.shared.createShortcut(for: profile)
                        }
                    }
                }
                
                if allMounted {
                    IntegraLogger.shared.log("All auto-mount profiles mounted successfully. Startup routine completed.")
                    break
                }
            }
            
            // Hand over any remaining unmounted profiles to NetworkRecoveryService
            NetworkRecoveryService.shared.triggerRecovery(reason: "Startup post-boot verification")
        }
    }
}

@main
struct IntegraApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var profileStore = ProfileStore.shared
    @StateObject private var sshfsService = SSHFSService.shared
    @StateObject private var depService = DependencyService()
    @StateObject private var appSettings = AppSettings.shared
    @StateObject private var recoveryService = NetworkRecoveryService.shared
    @StateObject private var tunnelService = SSHTunnelService.shared
    @StateObject private var execService = RemoteExecService.shared
    
    @State private var selectedTab: NavigationTab = .profiles
    
    var body: some Scene {
        WindowGroup {
            NavigationSplitView {
                SidebarView(selectedTab: $selectedTab)
            } detail: {
                switch selectedTab {
                case .profiles:
                    ProfileListView()
                case .activeMounts:
                    ActiveMountsView()
                case .doctor:
                    DependencyDoctorView()
                case .settings:
                    SettingsView()
                }
            }
            .navigationTitle("Integra - macOS SSHFS Manager")
            .frame(minWidth: 840, minHeight: 540)
            .environmentObject(profileStore)
            .environmentObject(sshfsService)
            .environmentObject(depService)
            .environmentObject(appSettings)
            .environmentObject(recoveryService)
            .environmentObject(tunnelService)
            .environmentObject(execService)
        }
        .windowStyle(.titleBar)
        
        MenuBarExtra("Integra", systemImage: "network") {
            MenuBarView()
                .environmentObject(profileStore)
                .environmentObject(sshfsService)
                .environmentObject(depService)
                .environmentObject(appSettings)
                .environmentObject(recoveryService)
                .environmentObject(tunnelService)
                .environmentObject(execService)
        }
        .menuBarExtraStyle(.window)
    }
}
