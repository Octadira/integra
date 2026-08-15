# Network Recovery & Auto-Healing Architecture

## 1. Executive Summary

Remote filesystem connections (such as SSHFS and NFS) are inherently susceptible to network interruptions. On macOS laptops, closing the lid (Mac Sleep), switching between Wi-Fi / Hotspot networks, or experiencing temporary cellular/broadband packet loss typically results in "stale" or frozen mounts.

**Integra** incorporates an autonomous **Network Recovery & Auto-Healing Engine** (`Sources/Integra/Services/NetworkRecoveryService.swift`) designed to detect network transitions in real-time, safely purge unresponsive mount points, and automatically restore active mounts using an **Exponential Backoff** retry algorithm.

---

## 2. Real-Time Network & System Monitoring

The recovery engine monitors two independent hardware and network telemetry sources:

```
                  +-------------------------------------------------+
                  |             macOS System Telemetry              |
                  +------------------------+------------------------+
                                           |
                    +----------------------+----------------------+
                    |                                             |
                    v                                             v
        [Apple Network.framework]                     [macOS Workspace Center]
             (NWPathMonitor)                      (NSWorkspace.didWakeNotification)
                    |                                             |
     Emits: .satisfied / .unsatisfied              Emits: System woke from Sleep
                    |                                             |
                    +----------------------+----------------------+
                                           |
                                           v
                        +-------------------------------------+
                        |       NetworkRecoveryService        |
                        | (Intended Mount State Synchronization)
                        +------------------+------------------+
                                           |
                                           v
                        +-------------------------------------+
                        |  Exponential Backoff Auto-Healing   |
                        |      (1s -> 2s -> 4s -> 8s -> 16s)  |
                        +-------------------------------------+
```

### 2.1. `NWPathMonitor` Lifecycle
- Operates on a dedicated utility dispatch queue (`com.integra.app.network-monitor`).
- Detects Wi-Fi network hops, VPN interface toggling, and cellular tethering transitions.
- When `path.status` transitions from `.unsatisfied` to `.satisfied`, it triggers the recovery sequence.

### 2.2. `NSWorkspace.didWakeNotification` Lifecycle
- Listens directly to macOS power management notifications.
- When the Mac wakes, the engine introduces a 2.0-second stabilization delay allowing DHCP and Wi-Fi handshakes to complete before executing recovery checks.

---

## 3. Intended vs. Unintended Mount State Tracking

To prevent unwanted automatic reconnections when a user manually unmounts a drive, Integra maintains an explicit **Intended Mount Set** (`intendedMounts: Set<UUID>`):

1. **User Mount Action**: When a user mounts a server, its profile ID is registered into `intendedMounts`.
2. **User Unmount Action**: When a user clicks "Unmount" or "Unmount All", its profile ID is permanently removed from `intendedMounts` and any pending retry tasks are cancelled immediately.
3. **Recovery Evaluation**: Only profiles actively present in `intendedMounts` that are not currently mounted in `/sbin/mount` are candidates for auto-healing.

---

## 4. Exponential Backoff Algorithm

When a recovery sequence initiates, retry intervals scale exponentially to avoid CPU thrashing, network congestion, and battery drain:

$$\text{Delay}(n) = \min(30.0, 2^n) \quad \text{for attempt } n \in \{0, 1, 2, 3, 4\}$$

- **Attempt 1**: 1.0 second delay
- **Attempt 2**: 2.0 seconds delay
- **Attempt 3**: 4.0 seconds delay
- **Attempt 4**: 8.0 seconds delay
- **Attempt 5**: 16.0 seconds delay (capped at 30.0 seconds)

### Stale Mount Sanitization
Before attempting a remount, the worker executes a forced unmount fallback (`diskutil unmount force <path>`) to cleanly detach any hanging NFS kernel handles from macOS Finder.
