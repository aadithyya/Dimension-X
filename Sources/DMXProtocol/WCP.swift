import Foundation
import DMXModel

// DMXProtocol/WCP.swift — Worker Control Protocol (WCP/1)

public enum WCP {
    public struct Start: Codable, Sendable {
        public let plan: LaunchPlan

        public init(plan: LaunchPlan) {
            self.plan = plan
        }
    }

    public struct ExecutionResult: Codable, Sendable {
        public let exitCode: Int32
        public let cleanupState: String   // "verified" | "CLEANUPUNVERIFIED"
        public let survivors: [Int32]
        public let durationMs: Double

        public init(exitCode: Int32, cleanupState: String, survivors: [Int32] = [], durationMs: Double) {
            self.exitCode = exitCode
            self.cleanupState = cleanupState
            self.survivors = survivors
            self.durationMs = durationMs
        }
    }

    public enum StatusPayload: Codable, Sendable {
        case started(pid: Int32, pgid: Int32)
        case progress(message: String)
        case exited(result: ExecutionResult)
    }

    public struct Message: Codable, Sendable {
        public let version: Int
        public let payload: StatusPayload

        public init(version: Int = 1, payload: StatusPayload) {
            self.version = version
            self.payload = payload
        }
    }
}
