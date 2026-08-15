# Desktop Shortcut Lifecycle Architecture

## 1. Feature Overview

Integra provides an optional per-server **Desktop Shortcut** capability that allows users to place an instant shortcut directly on `~/Desktop` pointing to their mounted SSHFS directory.

---

## 2. Technical Implementation

The lifecycle is orchestrated by `DesktopShortcutService` (`Sources/Integra/Services/DesktopShortcutService.swift`):

### 2.1. Symlink Creation (`createShortcut`)
- **Target Source**: `~/Mounts/<SafeProfileName>` (the mounted filesystem).
- **Destination Path**: `~/Desktop/<SafeProfileName>`.
- Utilizes Apple's native Foundation API:
  ```swift
  FileManager.default.createSymbolicLink(atPath: destination, withDestinationPath: source)
  ```
- **Zero Special Permissions**: Executed using standard POSIX user-level privileges inside the user's home directory. Does NOT require `sudo`, Accessibility, or AppleScript permissions.

### 2.2. Robust Broken Symlink Detection & Cleanup
In Cocoa/Foundation, `FileManager.default.fileExists(atPath:)` returns `false` when inspecting a symlink whose target is temporarily unmounted (a broken symlink). 

To guarantee that broken symlinks on `~/Desktop` are always properly detected and cleaned up on unmount or application launch, `DesktopShortcutService` utilizes low-level item attribute inspection:
```swift
if (try? FileManager.default.attributesOfItem(atPath: path)) != nil {
    try? FileManager.default.removeItem(atPath: path)
}
```
This prevents macOS Finder from displaying the error: *"The operation can’t be completed because the original item for 'ServerName' can’t be found"*.

### 2.3. Smart Lifecycle Synchronization
```
[User clicks Mount / Startup Auto-Mount]
        |
        v
[SSHFSService mounts remote filesystem]
        |
        v
[Is profile.createDesktopShortcut == true?]
        |
     +--+--+
     |     |
    YES    NO
     |     |
     v     v
[Create Desktop Symlink]  [No Desktop Action]
     |
     v
[User clicks Unmount / Network Disconnect]
        |
        v
[SSHFSService unmounts filesystem]
        |
        v
[DesktopShortcutService.removeShortcut()]
        |
        v
[Desktop cleaned up instantly (Zero broken symlinks)]
```

### 2.4. Real-Time Card Toggling
When the user clicks the `Desktop` button on an active connection card:
- If toggled **ON**: The profile's `createDesktopShortcut` flag is set to `true`, saved to `ProfileStore`, and `DesktopShortcutService.shared.createShortcut(for: profile)` creates the Desktop symlink immediately.
- If toggled **OFF**: The flag is set to `false`, saved to `ProfileStore`, and `DesktopShortcutService.shared.removeShortcut(for: profile)` removes the Desktop symlink immediately.
