import SwiftUI

public enum NavigationTab: Hashable {
    case profiles
    case activeMounts
    case doctor
    case settings
}

public struct SidebarView: View {
    @Binding var selectedTab: NavigationTab
    @EnvironmentObject var store: ProfileStore
    @EnvironmentObject var sshfsService: SSHFSService
    @EnvironmentObject var depService: DependencyService
    @ObservedObject var updateChecker = UpdateCheckerService.shared
    
    public init(selectedTab: Binding<NavigationTab>) {
        self._selectedTab = selectedTab
    }
    
    private var activeCount: Int {
        store.profiles.filter { sshfsService.isProfileMounted($0) }.count
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            List(selection: $selectedTab) {
                Section("SSHFS Manager") {
                    NavigationLink(value: NavigationTab.profiles) {
                        Label {
                            Text("Connections")
                        } icon: {
                            Image(systemName: "server.rack")
                                .foregroundColor(.accentColor)
                        }
                        .badge(store.profiles.count)
                    }
                    
                    NavigationLink(value: NavigationTab.activeMounts) {
                        Label {
                            Text("Active Mounts")
                        } icon: {
                            Image(systemName: "externaldrive.fill.badge.checkmark")
                                .foregroundColor(activeCount > 0 ? .green : .secondary)
                        }
                        .badge(activeCount > 0 ? "\(activeCount)" : nil)
                    }
                }
                
                Section("System") {
                    NavigationLink(value: NavigationTab.doctor) {
                        Label {
                            Text("Dependency Doctor")
                        } icon: {
                            Image(systemName: "stethoscope")
                                .foregroundColor(depService.allInstalled ? .accentColor : .orange)
                        }
                        .badge((depService.isInitialCheckComplete && !depService.allInstalled) ? "!" : nil)
                    }
                    
                    NavigationLink(value: NavigationTab.settings) {
                        Label {
                            Text("Settings")
                        } icon: {
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            
            Divider()
            
            // Bottom Status Card
            HStack(spacing: 10) {
                Circle()
                    .fill(depService.allInstalled ? (activeCount > 0 ? Color.green : Color.blue) : Color.orange)
                    .frame(width: 8, height: 8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(depService.allInstalled ? (activeCount > 0 ? "\(activeCount) Server\(activeCount == 1 ? "" : "s") Connected" : "FUSE-T Ready") : "Dependencies Missing")
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text("Integra v0.14.2")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        if updateChecker.updateAvailable, let newVer = updateChecker.latestVersion {
                            HStack(spacing: 3) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 8))
                                Text(newVer)
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .foregroundColor(.blue)
                            .clipShape(Capsule())
                            .fixedSize(horizontal: true, vertical: true)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        }
        .frame(minWidth: 210)
    }
}
