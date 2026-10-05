import Foundation

// DMXProtocol/JSONValue.swift — Codable dynamic JSON payload enum

public enum JSONValue: Codable, Hashable, Sendable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let boolVal = try? container.decode(Bool.self) {
            self = .bool(boolVal)
        } else if let doubleVal = try? container.decode(Double.self) {
            self = .number(doubleVal)
        } else if let stringVal = try? container.decode(String.self) {
            self = .string(stringVal)
        } else if let arrayVal = try? container.decode([JSONValue].self) {
            self = .array(arrayVal)
        } else if let objectVal = try? container.decode([String: JSONValue].self) {
            self = .object(objectVal)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported JSONValue type"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .object(let dict):
            try container.encode(dict)
        case .array(let arr):
            try container.encode(arr)
        case .string(let str):
            try container.encode(str)
        case .number(let num):
            try container.encode(num)
        case .bool(let b):
            try container.encode(b)
        case .null:
            try container.encodeNil()
        }
    }
}
