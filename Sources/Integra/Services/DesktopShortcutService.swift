import Foundation
import AppKit

public class DesktopShortcutService {
    public static let shared = DesktopShortcutService()
    
    private init() {}
    
    @discardableResult
    public func createShortcut(for profile: SSHProfile) -> Bool {
        let destination = profile.desktopShortcutPath
        let source = profile.defaultMountPath
        
        removeShortcut(for: profile)
        
        do {
            try FileManager.default.createSymbolicLink(atPath: destination, withDestinationPath: source)
            return true
        } catch {
            print("[DesktopShortcutService] Failed to create desktop symlink: \(error)")
            return false
        }
    }
    
    @discardableResult
    public func removeShortcut(for profile: SSHProfile) -> Bool {
        let path = profile.desktopShortcutPath
        // Use attributesOfItem to detect broken symlinks as well
        if (try? FileManager.default.attributesOfItem(atPath: path)) != nil {
            do {
                try FileManager.default.removeItem(atPath: path)
                return true
            } catch {
                print("[DesktopShortcutService] Failed to remove desktop symlink: \(error)")
                return false
            }
        }
        return true
    }
    
    public func isShortcutPresent(for profile: SSHProfile) -> Bool {
        return (try? FileManager.default.attributesOfItem(atPath: profile.desktopShortcutPath)) != nil
    }
}
