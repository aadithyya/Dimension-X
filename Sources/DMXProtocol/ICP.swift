import Foundation
import DMXModel

// DMXProtocol/ICP.swift — Inspector Control Protocol (ICP/1)

public enum ICP {
    public struct Request: Codable, Sendable {
        public let version: Int
        public let targetPath: String?

        public init(version: Int = 1, targetPath: String? = nil) {
            self.version = version
            self.targetPath = targetPath
        }
    }

    public struct Response: Codable, Sendable {
        public let version: Int
        public let ok: Bool
        public let facts: RequirementFacts?
        public let error: ErrorDetail?

        public init(version: Int = 1, ok: Bool, facts: RequirementFacts? = nil, error: ErrorDetail? = nil) {
            self.version = version
            self.ok = ok
            self.facts = facts
            self.error = error
        }
    }

    public struct ErrorDetail: Codable, Sendable {
        public let code: String
        public let message: String

        public init(code: String, message: String) {
            self.code = code
            self.message = message
        }
    }
}
