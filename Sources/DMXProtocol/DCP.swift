import Foundation

// DMXProtocol/DCP.swift

public struct DCPRequest: Codable, Sendable {
    public var version: Int
    public var type: String
    public var id: String
    public var method: String                 // e.g. "application.import", "operation.subscribe"
    public var payload: JSONValue
    public var idempotencyKey: String?

    public init(
        version: Int = 1,
        type: String = "request",
        id: String = UUID().uuidString.lowercased(),
        method: String,
        payload: JSONValue = .null,
        idempotencyKey: String? = nil
    ) {
        self.version = version
        self.type = type
        self.id = id.lowercased()
        self.method = method
        self.payload = payload
        self.idempotencyKey = idempotencyKey
    }
}

public struct DCPResponse: Codable, Sendable {
    public var version: Int
    public var type: String
    public var id: String
    public var ok: Bool
    public var payload: JSONValue?
    public var error: DCPError?

    public init(
        version: Int = 1,
        type: String = "response",
        id: String,
        ok: Bool,
        payload: JSONValue? = nil,
        error: DCPError? = nil
    ) {
        self.version = version
        self.type = type
        self.id = id.lowercased()
        self.ok = ok
        self.payload = payload
        self.error = error
    }
}

public struct DCPEvent: Codable, Sendable {
    public var version: Int
    public var type: String
    public var operationID: String
    public var seq: Int64
    public var payload: JSONValue

    public init(
        version: Int = 1,
        type: String = "event",
        operationID: String,
        seq: Int64,
        payload: JSONValue
    ) {
        self.version = version
        self.type = type
        self.operationID = operationID.lowercased()
        self.seq = seq
        self.payload = payload
    }
}

public struct DCPError: Codable, Sendable {
    public var code: String
    public var message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}
