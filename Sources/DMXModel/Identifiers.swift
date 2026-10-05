import Foundation


public struct ID<Tag>: Hashable, Codable, Sendable, CustomStringConvertible {
    public let raw: String

    public init() {
        self.raw = UUID().uuidString.lowercased()
    }

    public init(raw: String) {
        self.raw = raw.lowercased()
    }

    public var description: String {
        raw
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self.raw = value.lowercased()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(raw)
    }
}

public enum ApplicationTag {}
public enum GenerationTag {}
public enum SessionTag {}
public enum ArtifactTag {}
public enum EnvironmentTag {}
public enum OperationTag {}

public typealias ApplicationID = ID<ApplicationTag>
public typealias GenerationID  = ID<GenerationTag>
public typealias SessionID     = ID<SessionTag>
public typealias ArtifactID    = ID<ArtifactTag>
public typealias EnvironmentID = ID<EnvironmentTag>
public typealias OperationID   = ID<OperationTag>
