# FUSE-T Filesystem Engine Integration

## 1. Overview & Architectural Motivation

On modern macOS versions (macOS Sonoma 14+ and Sequoia 15+), Apple has heavily restricted and deprecated third-party **Kernel Extensions (KEXTs)**. Traditional FUSE solutions (such as legacy OSXFUSE or macFUSE 4.x) require:
1. Disabling or lowering **System Integrity Protection (SIP)**.
2. Rebooting Apple Silicon Macs into **Recovery Mode** to enable "Reduced Security" and authorize Kernel Extensions.
3. Managing kernel panic risks and enterprise MDM blocking.

**Integra solves this completely by adopting FUSE-T.**

---

## 2. How FUSE-T Operates (NFS Loopback Architecture)

FUSE-T is a completely **KEXT-free** user-space FUSE implementation. Instead of injecting a driver into the macOS XNU kernel, FUSE-T spawns an ultra-fast local NFS server in user space (`go-nfsv4`) listening on loopback (`127.0.0.1`):

```
+-------------------------------------------------------------+
|                       macOS User Space                      |
|                                                             |
|   +---------------+      libfuse API      +--------------+  |
|   |  Integra SSHFS| --------------------> | FUSE-T Engine|  |
|   +---------------+                       +--------------+  |
|           | (SSH Protocol)                       |          |
|           v                                      v          |
|   +---------------+                      +--------------+   |
|   | Remote Server |                      | local NFSv4  |   |
|   +---------------+                      | server       |   |
|                                          +-------+------+   |
+--------------------------------------------------|----------+
                                                   | loopback
+--------------------------------------------------v----------+
|                       macOS Kernel                          |
|   Built-in /sbin/mount_nfs (Native Apple NFS Client)        |
+-------------------------------------------------------------+
```

1. **`sshfs` CLI** interacts with `libfuse.dylib` provided by `/Library/Frameworks/fuse_t.framework`.
2. **FUSE-T Framework** translates FUSE filesystem calls (read, write, readdir, getattr) into standard NFSv4 RPC operations.
3. macOS connects to the local NFS server using its built-in, Apple-certified `/sbin/mount_nfs` client.
4. **Result**: Zero kernel extensions, zero SIP modification, and 100% compliance with Apple enterprise security policies.

---

## 3. SSHFS Mount Parameter Configuration

Integra invokes `sshfs` with carefully tuned flags optimized for stability, performance, and non-blocking operation:

```swift
var args: [String] = [
    remoteSpec,              // user@host:/remote/path
    targetPath,              // ~/Mounts/<ProfileName>
    "-p", "\(profile.port)", // SSH Port (e.g. 22)
    "-o", "reconnect",       // Auto-reconnect on network interruptions
    "-o", "ServerAliveInterval=15",
    "-o", "ServerAliveCountMax=3",
    "-o", "StrictHostKeyChecking=accept-new", // Prevents interactive terminal hanging
    "-o", "ConnectTimeout=10",
    "-o", "volname=\(volName)",               // Custom Finder volume display name
    "-o", "defer_permissions",                // Delegate permission checking to remote host
    "-o", "follow_symlinks"                   // Seamless remote symlink traversal
]
```

### Password Injection via STDIN
When password authentication or encrypted SSH key passphrases are used, Integra passes `-o password_stdin` and securely streams the credential via an internal pipe (`Process.standardInput`), immediately closing the write handle to prevent memory exposure.

---

## 4. Mount Table Polling & Detection

FUSE-T mounts are tracked in real-time by polling `/sbin/mount` every 2.0 seconds:
- Lines reporting `(nfs, ...)` or `(fuse...)` rooted at `~/Mounts/<ServerName>` are matched against active profiles.
- Paths are normalized using `(localPath as NSString).standardizingPath` to avoid case-sensitivity discrepancies.

---

## 5. Clean Unmounting Workflow

Integra implements a dual-tier unmounting mechanism:
1. **Graceful Soft Unmount**: Invokes `/sbin/umount <targetPath>`.
2. **Forced Fallback**: If the filesystem has active open file handles, Integra automatically falls back to `/usr/sbin/diskutil unmount force <targetPath>` to prevent hung Finder windows.
