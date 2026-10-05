import CryptoKit
import Foundation

// DMXModel/CanonicalJSON.swift — deterministic digests. Do NOT use JSONEncoder output directly.

public enum CanonicalJSON {
    /// Canonical form: object keys sorted (byte order), no whitespace, numbers as shortest
    /// round-trip, strings escaped per RFC 8259, dates encoded as ISO-8601 UTC strings.
    public static func data<T: Encodable>(_ value: T) throws -> Data {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        let raw = try enc.encode(value)
        let obj = try JSONSerialization.jsonObject(with: raw, options: [.fragmentsAllowed])
        var out = Data()
        try write(obj, into: &out)
        return out
    }

    public static func sha256Hex<T: Encodable>(of value: T) -> String {
        let d = (try? data(value)) ?? Data()
        return SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined()
    }

    private static func write(_ v: Any, into out: inout Data) throws {
        switch v {
        case let d as [String: Any]:
            out.append(UInt8(ascii: "{"))
            for (i, k) in d.keys.sorted(by: { $0.utf8.lexicographicallyPrecedes($1.utf8) }).enumerated() {
                if i > 0 { out.append(UInt8(ascii: ",")) }
                try writeString(k, into: &out)
                out.append(UInt8(ascii: ":"))
                try write(d[k]!, into: &out)
            }
            out.append(UInt8(ascii: "}"))
        case let a as [Any]:
            out.append(UInt8(ascii: "["))
            for (i, e) in a.enumerated() {
                if i > 0 { out.append(UInt8(ascii: ",")) }
                try write(e, into: &out)
            }
            out.append(UInt8(ascii: "]"))
        case let s as String:
            try writeString(s, into: &out)
        case let n as NSNumber:
            if CFGetTypeID(n) == CFBooleanGetTypeID() {
                out.append(contentsOf: (n.boolValue ? "true" : "false").utf8)
            } else {
                out.append(contentsOf: "\(n)".utf8)
            }
        case is NSNull:
            out.append(contentsOf: "null".utf8)
        default:
            throw CanonicalError.unsupported(String(describing: type(of: v)))
        }
    }

    private static func writeString(_ s: String, into out: inout Data) throws {
        let d = try JSONSerialization.data(withJSONObject: [s], options: [.withoutEscapingSlashes])
        out.append(d.dropFirst().dropLast())   // strip surrounding [ ]
    }

    public enum CanonicalError: Error {
        case unsupported(String)
    }
}
