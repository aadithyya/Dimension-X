// Recovered from Dimension-X_Project_Dossier.md (exact supplied snippets).
// NOTE: This file contains only the model snippets that were actually supplied; it is not a complete Models.swift.

public enum Certainty: String, Codable, Sendable {
    case confirmed
    case detected
    case inferred
    case unknown
}

public enum Provenance: String, Codable, Sendable {
    case localStaticAnalysis
    case importedUnverified
}

public struct Finding: Codable, Equatable, Sendable {
    public var topic: String
    public var value: String
    public var certainty: Certainty
    public var source: String
}

public struct AnalysisReport: Codable, Equatable, Sendable {
    public var analyzerVersion: Int
    public var provenance: Provenance
    public var sha256: String
    public var byteCount: Int
    public var machine: String
    public var importedDLLs: [String]
    public var importedAPIs: [String]
    public var findings: [Finding]
    public var executionBlocks: [String]
}

public struct ApplicationProfile:
    Codable, Identifiable, Equatable, Sendable
{
    public var schemaVersion: Int
    public var id: UUID
    public var name: String
    public var createdAt: Date
    public var updatedAt: Date
    public var analysis: AnalysisReport
}
