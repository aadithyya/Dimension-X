import Foundation

// DMXProtocol/FrameCodec.swift

public struct Frame: Sendable {
    public var payload: Data
    public init(payload: Data) {
        self.payload = payload
    }
}

public enum FrameError: Error, Equatable {
    case oversized(UInt32)
    case truncated
    case badLength
}

public struct FrameCodec: Sendable {
    public let maxFrameBytes: UInt32      // injected from ProvisionalLimits; never hard-code here

    public init(maxFrameBytes: UInt32) {
        self.maxFrameBytes = maxFrameBytes
    }

    public func encode(payload: Data) throws -> Data {
        guard payload.count <= Int(maxFrameBytes) else {
            throw FrameError.oversized(UInt32(payload.count))
        }
        var len = UInt32(payload.count).bigEndian
        var out = Data(bytes: &len, count: 4)
        out.append(payload)
        return out
    }

    /// Incremental decoder: feed bytes, pull complete frames. Rejects oversized frames before buffering them.
    public struct Decoder: Sendable {
        private var buffer = Data()
        private let max: UInt32

        public init(maxFrameBytes: UInt32) {
            self.max = maxFrameBytes
        }

        public mutating func feed(data: Data) {
            buffer.append(data)
        }

        public mutating func next() throws -> Data? {
            guard buffer.count >= 4 else { return nil }
            let len = buffer.prefix(4).withUnsafeBytes { UInt32(bigEndian: $0.loadUnaligned(as: UInt32.self)) }
            guard len <= max else { throw FrameError.oversized(len) }
            guard buffer.count >= 4 + Int(len) else { return nil }
            let payload = buffer.subdata(in: 4..<(4 + Int(len)))
            buffer.removeSubrange(0..<(4 + Int(len)))
            return payload
        }
    }
}
