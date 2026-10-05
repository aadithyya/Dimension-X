import Foundation

// DMXModel/Artifact.swift

public enum ArtifactKind: String, Codable, Sendable {
    case runtime
    case graphics
    case dependency
}

public enum ArtifactState: String, Codable, Sendable {
    case imported
    case admitted
    case rejected
}

public struct ArtifactManifest: Codable, Hashable, Sendable {
    public let name: String
    public let version: String
    public let supportedArchitectures: [PEArchitecture]
    public let providedGraphicsProviders: [GraphicsProviderKind]
    public let metadata: [String: String]

    public init(
        name: String,
        version: String,
        supportedArchitectures: [PEArchitecture],
        providedGraphicsProviders: [GraphicsProviderKind] = [],
        metadata: [String: String] = [:]
    ) {
        self.name = name
        self.version = version
        self.supportedArchitectures = supportedArchitectures
        self.providedGraphicsProviders = providedGraphicsProviders
        self.metadata = metadata
    }
}

public struct ArtifactRecord: Codable, Hashable, Sendable {
    public let digest: String
    public let kind: ArtifactKind
    public let state: ArtifactState
    public let manifest: ArtifactManifest?
    public let rejectionReason: String?
    public let importedAt: Date

    public init(
        digest: String,
        kind: ArtifactKind,
        state: ArtifactState,
        manifest: ArtifactManifest? = nil,
        rejectionReason: String? = nil,
        importedAt: Date = Date()
    ) {
        self.digest = digest
        self.kind = kind
        self.state = state
        self.manifest = manifest
        self.rejectionReason = rejectionReason
        self.importedAt = importedAt
    }
}
