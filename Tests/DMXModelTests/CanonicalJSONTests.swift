import Foundation
#if canImport(XCTest)
import XCTest
#endif
@testable import DMXModel

final class CanonicalJSONTests: XCTestCase {

    func testCanonicalDigestStabilityForRuntimeComposition() throws {
        // Prepare 100 variations of RuntimeComposition with configuration dictionary keys inserted in random orders
        let baseKeys = (1...20).map { "key_\($0)" }
        let expectedDigest = RuntimeComposition(
            runtimeArtifactDigest: "sha256:1111111111111111111111111111111111111111111111111111111111111111",
            cpuPath: .x8664HostExecution,
            graphicsProvider: .dxmt,
            graphicsArtifactDigest: "sha256:2222222222222222222222222222222222222222222222222222222222222222",
            dependencyRecipeDigests: ["sha256:bbb", "sha256:aaa"].sorted(),
            configuration: Dictionary(uniqueKeysWithValues: baseKeys.map { ($0, "val_\($0)") })
        ).digest

        for _ in 1...100 {
            let shuffledKeys = baseKeys.shuffled()
            var config: [String: String] = [:]
            for k in shuffledKeys {
                config[k] = "val_\(k)"
            }

            let composition = RuntimeComposition(
                runtimeArtifactDigest: "sha256:1111111111111111111111111111111111111111111111111111111111111111",
                cpuPath: .x8664HostExecution,
                graphicsProvider: .dxmt,
                graphicsArtifactDigest: "sha256:2222222222222222222222222222222222222222222222222222222222222222",
                dependencyRecipeDigests: ["sha256:aaa", "sha256:bbb"],
                configuration: config
            )

            XCTAssertEqual(composition.digest, expectedDigest, "Canonical digest MUST be identical regardless of dictionary key insertion order.")
        }
    }

    func testCanonicalJSONOutputFormatting() throws {
        struct TestObj: Encodable {
            let z: String
            let a: Int
            let boolVal: Bool
            let nullVal: String?
            let array: [String]

            enum CodingKeys: String, CodingKey {
                case z, a, boolVal, nullVal, array
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(z, forKey: .z)
                try container.encode(a, forKey: .a)
                try container.encode(boolVal, forKey: .boolVal)
                try container.encode(nullVal, forKey: .nullVal)
                try container.encode(array, forKey: .array)
            }
        }

        let obj = TestObj(z: "last", a: 42, boolVal: true, nullVal: nil, array: ["b", "a"])
        let canonicalData = try CanonicalJSON.data(obj)
        let jsonString = String(data: canonicalData, encoding: .utf8)!

        // Keys MUST be sorted lexicographically: "a", "array", "boolVal", "nullVal", "z"
        let expectedJSON = "{\"a\":42,\"array\":[\"b\",\"a\"],\"boolVal\":true,\"nullVal\":null,\"z\":\"last\"}"
        XCTAssertEqual(jsonString, expectedJSON)
    }
}
