import SwiftUI

public struct MenuBarView: View {
    @EnvironmentObject var store: ProfileStore
    @EnvironmentObject var sshfsService: SSHFSService
    @ObservedObject var updateChecker = UpdateCheckerService.shared
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Integra SSHFS Manager")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 6)
            
            Divider()
            
            if store.profiles.isEmpty {
                Text("No connections configured")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            } else {
                ForEach(store.profiles) { profile in
                    let isMounted = sshfsService.isProfileMounted(profile)
                    HStack {
                        Circle()
                            .fill(isMounted ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                        
                        Text(profile.name)
                            .font(.subheadline)
                        
                        Spacer()
                        
                        if isMounted {
                            Button("Unmount") {
                                Task {
                                    try? await sshfsService.unmount(profile: profile)
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        } else {
                            Button("Mount") {
                                Task {
                                    try? await sshfsService.mount(profile: profile)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            if updateChecker.updateAvailable, let newVer = updateChecker.latestVersion {
                Divider()
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text("New Version: \(newVer)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
                .padding(.horizontal)
            }
            
            Divider()
            
            Button("Quit Integra") {
                NSApplication.shared.terminate(nil)
            }
            .padding(.horizontal)
            .padding(.bottom, 6)
        }
        .frame(width: 280)
    }
}
