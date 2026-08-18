import Foundation

public enum DependencyType: String, CaseIterable, Identifiable {
    case homebrew = "Homebrew"
    case fuseT = "FUSE-T"
    case sshfs = "SSHFS (FUSE-T)"
    
    public var id: String { self.rawValue }
    
    public var icon: String {
        switch self {
        case .homebrew: return "mug"
        case .fuseT: return "externaldrive.badge.wifi"
        case .sshfs: return "network"
        }
    }
    
    public var description: String {
        switch self {
        case .homebrew: return "macOS Package Manager required for FUSE-T installation."
        case .fuseT: return "User-space NFS filesystem engine for macOS (KEXT-free)."
        case .sshfs: return "SSH File System client adapted for FUSE-T."
        }
    }
}

public enum DependencyState: Equatable {
    case checking
    case installed(path: String)
    case missing
    case error(String)
    
    public var isInstalled: Bool {
        if case .installed = self { return true }
        return false
    }
}

public struct DependencyItem: Identifiable, Equatable {
    public var id: DependencyType { type }
    public let type: DependencyType
    public var state: DependencyState
}
