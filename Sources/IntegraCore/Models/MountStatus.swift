import Foundation

public struct ActiveMountInfo: Identifiable, Equatable {
    public var id: String { localPath }
    public let source: String
    public let localPath: String
}

public struct MountStatus: Identifiable, Equatable {
    public var id: UUID { profileId }
    public let profileId: UUID
    public var isMounted: Bool
    public var mountedPath: String
    public var mountedAt: Date?
    public var errorMessage: String?
    
    public init(
        profileId: UUID,
        isMounted: Bool = false,
        mountedPath: String = "",
        mountedAt: Date? = nil,
        errorMessage: String? = nil
    ) {
        self.profileId = profileId
        self.isMounted = isMounted
        self.mountedPath = mountedPath
        self.mountedAt = mountedAt
        self.errorMessage = errorMessage
    }
}
