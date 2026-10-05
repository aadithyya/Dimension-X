import Foundation

// DMXModel/Evidence.swift

public enum EvidenceKind: String, Codable, Sendable {
    case qualification
    case compatibility
}

public enum QualificationVerdict: String, Codable, Sendable {
    case qualified
    case failed
}

public enum CompatibilityVerdict: String, Codable, Sendable {
    case works
    case partial
    case fails
    case blocked
    case unknown
}

public enum PerformanceClass: String, Codable, Sendable {
    case measuredOK
    case limited
    case unknown
}

public struct PerformanceSample: Codable, Hashable, Sendable {
    public var frameTimeP50ms: Double?
    public var frameTimeP95ms: Double?
    public var frameTimeP99ms: Double?
    public var onePercentLowFPS: Double?
    public var firstFrameMs: Double?
    public var source: String   // which instrument produced it; never "estimated"

    public init(
        frameTimeP50ms: Double? = nil,
        frameTimeP95ms: Double? = nil,
        frameTimeP99ms: Double? = nil,
        onePercentLowFPS: Double? = nil,
        firstFrameMs: Double? = nil,
        source: String
    ) {
        self.frameTimeP50ms = frameTimeP50ms
        self.frameTimeP95ms = frameTimeP95ms
        self.frameTimeP99ms = frameTimeP99ms
        self.onePercentLowFPS = onePercentLowFPS
        self.firstFrameMs = firstFrameMs
        self.source = source
    }
}

public struct Evidence: Codable, Hashable, Sendable {
    public enum ValidationError: Error, Equatable {
        case qualificationCannotContainApplicationFields
        case compatibilityCannotContainQualificationFields
        case missingRequiredQualificationFields
        case missingRequiredCompatibilityFields
    }

    public let id: String
    public let kind: EvidenceKind
    public let compositionDigest: String
    public let hostIdentityDigest: String
    public let observedAt: Date

    // qualification-only
    public let qualificationTest: String?
    public let qualificationVerdict: QualificationVerdict?

    // compatibility-only
    public let applicationID: ApplicationID?
    public let applicationBinaryDigest: String?
    public let generationID: GenerationID?
    public let scenario: String?
    public let compatibilityVerdict: CompatibilityVerdict?
    public let performance: PerformanceClass?
    public let performanceSample: PerformanceSample?
    public let stability: String?                     // "stable" / "crashed@<phase>" / "unknown"
    public let notes: String?

    public init(
        id: String = UUID().uuidString.lowercased(),
        kind: EvidenceKind,
        compositionDigest: String,
        hostIdentityDigest: String,
        observedAt: Date = Date(),
        qualificationTest: String? = nil,
        qualificationVerdict: QualificationVerdict? = nil,
        applicationID: ApplicationID? = nil,
        applicationBinaryDigest: String? = nil,
        generationID: GenerationID? = nil,
        scenario: String? = nil,
        compatibilityVerdict: CompatibilityVerdict? = nil,
        performance: PerformanceClass? = nil,
        performanceSample: PerformanceSample? = nil,
        stability: String? = nil,
        notes: String? = nil
    ) throws {
        self.id = id.lowercased()
        self.kind = kind
        self.compositionDigest = compositionDigest
        self.hostIdentityDigest = hostIdentityDigest
        self.observedAt = observedAt
        self.qualificationTest = qualificationTest
        self.qualificationVerdict = qualificationVerdict
        self.applicationID = applicationID
        self.applicationBinaryDigest = applicationBinaryDigest
        self.generationID = generationID
        self.scenario = scenario
        self.compatibilityVerdict = compatibilityVerdict
        self.performance = performance
        self.performanceSample = performanceSample
        self.stability = stability
        self.notes = notes

        // Enforce invariants
        switch kind {
        case .qualification:
            if applicationID != nil || applicationBinaryDigest != nil || generationID != nil || scenario != nil || compatibilityVerdict != nil || performance != nil || performanceSample != nil {
                throw ValidationError.qualificationCannotContainApplicationFields
            }
            if qualificationVerdict == nil {
                throw ValidationError.missingRequiredQualificationFields
            }
        case .compatibility:
            if qualificationTest != nil || qualificationVerdict != nil {
                throw ValidationError.compatibilityCannotContainQualificationFields
            }
            if compatibilityVerdict == nil {
                throw ValidationError.missingRequiredCompatibilityFields
            }
        }
    }
}
