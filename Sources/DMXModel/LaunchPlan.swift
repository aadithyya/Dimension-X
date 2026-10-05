import Foundation

// DMXModel/LaunchPlan.swift — immutable, canonical-digested launch payload

public struct LaunchPlan: Codable, Hashable, Sendable {
    public let applicationID: ApplicationID
    public let binaryDigest: String
    public let binaryRelativePath: String
    public let generationID: GenerationID
    public let compositionDigest: String
    public let hostIdentityDigest: String
    public let env: [String: String]
    public let workingDirectory: String
    public let arguments: [String]

    public init(
        applicationID: ApplicationID,
        binaryDigest: String,
        binaryRelativePath: String,
        generationID: GenerationID,
        compositionDigest: String,
        hostIdentityDigest: String,
        env: [String: String],
        workingDirectory: String,
        arguments: [String]
    ) {
        self.applicationID = applicationID
        self.binaryDigest = binaryDigest
        self.binaryRelativePath = binaryRelativePath
        self.generationID = generationID
        self.compositionDigest = compositionDigest
        self.hostIdentityDigest = hostIdentityDigest
        self.env = env
        self.workingDirectory = workingDirectory
        self.arguments = arguments
    }

    public var digest: String {
        CanonicalJSON.sha256Hex(of: self)
    }
}
