import Foundation
#if canImport(XCTest)
import XCTest
#endif
@testable import DMXProtocol

final class FrameCodecTests: XCTestCase {

    func testEncodeAndDecodeSingleFrame() throws {
        let codec = FrameCodec(maxFrameBytes: 1024)
        let payload = Data("Hello Dimension X".utf8)

        let encoded = try codec.encode(payload: payload)
        XCTAssertEqual(encoded.count, 4 + payload.count)

        var decoder = FrameCodec.Decoder(maxFrameBytes: 1024)
        decoder.feed(data: encoded)

        let decodedPayload = try decoder.next()
        XCTAssertEqual(decodedPayload, payload)

        // No more frames in stream
        let nextFrame = try decoder.next()
        XCTAssertNil(nextFrame)
    }

    func testFragmentedStreamingDecoder() throws {
        let codec = FrameCodec(maxFrameBytes: 1024)
        let payload1 = Data("Payload 1".utf8)
        let payload2 = Data("Payload 2 - longer data segment".utf8)

        let encoded1 = try codec.encode(payload: payload1)
        let encoded2 = try codec.encode(payload: payload2)

        var combined = Data()
        combined.append(encoded1)
        combined.append(encoded2)

        var decoder = FrameCodec.Decoder(maxFrameBytes: 1024)

        // Feed byte by byte to simulate extreme fragmentation
        var framesRead: [Data] = []
        for byte in combined {
            decoder.feed(data: Data([byte]))
            if let frame = try decoder.next() {
                framesRead.append(frame)
            }
        }

        XCTAssertEqual(framesRead.count, 2)
        XCTAssertEqual(framesRead[0], payload1)
        XCTAssertEqual(framesRead[1], payload2)
    }

    func testOversizedEncodeRejection() {
        let codec = FrameCodec(maxFrameBytes: 10)
        let payload = Data("12345678901".utf8) // 11 bytes

        XCTAssertThrowsError(try codec.encode(payload: payload)) { error in
            XCTAssertEqual(error as? FrameError, .oversized(11))
        }
    }

    func testOversizedDecodeRejection() {
        var decoder = FrameCodec.Decoder(maxFrameBytes: 10)

        // Synthesize length header declaring 20 bytes (oversized)
        var lenHeader = UInt32(20).bigEndian
        let headerData = Data(bytes: &lenHeader, count: 4)

        decoder.feed(data: headerData)

        XCTAssertThrowsError(try decoder.next()) { error in
            XCTAssertEqual(error as? FrameError, .oversized(20))
        }
    }
}
