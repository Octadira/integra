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
                    
                    Text("Integra v0.9.0")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        }
    }
}
