import Foundation

// DMXModel/EnvironmentGeneration.swift

public enum GenerationState: String, Codable, Sendable {
    case building
    case ready
    case failed
    case retired
    case missing
}

public struct GenerationManifest: Codable, Hashable, Sendable {
    public let id: GenerationID
    public let composition: RuntimeComposition
    public let builtAt: Date
    public let contents: [String]   // file relative paths inventory

    public init(id: GenerationID, composition: RuntimeComposition, builtAt: Date = Date(), contents: [String]) {
        self.id = id
        self.composition = composition
        self.builtAt = builtAt
        self.contents = contents.sorted()
    }
}

public struct EnvironmentRecord: Codable, Hashable, Sendable {
    public let id: EnvironmentID
    public let applicationID: ApplicationID
    public var activeGenerationID: GenerationID?

    public init(id: EnvironmentID = EnvironmentID(), applicationID: ApplicationID, activeGenerationID: GenerationID? = nil) {
        self.id = id
        self.applicationID = applicationID
        self.activeGenerationID = activeGenerationID
    }
}

public struct EnvironmentGeneration: Codable, Hashable, Sendable {
    public let id: GenerationID
    public let environmentID: EnvironmentID
    public let ordinal: Int
    public let compositionDigest: String
    public var state: GenerationState
    public var protected: Bool
    public var manifest: GenerationManifest?
    public let createdAt: Date

    public init(
        id: GenerationID = GenerationID(),
        environmentID: EnvironmentID,
        ordinal: Int,
        compositionDigest: String,
        state: GenerationState,
        protected: Bool = false,
        manifest: GenerationManifest? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.environmentID = environmentID
        self.ordinal = ordinal
        self.compositionDigest = compositionDigest
        self.state = state
        self.protected = protected
        self.manifest = manifest
        self.createdAt = createdAt
    }
}
