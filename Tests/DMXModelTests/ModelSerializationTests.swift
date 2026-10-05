import Foundation
#if canImport(XCTest)
import XCTest
#endif
@testable import DMXModel

final class ModelSerializationTests: XCTestCase {

    func testRequirementFactsRoundTrip() throws {
        let facts = RequirementFacts(
            architecture: .x8664,
            isPE32Plus: .yes,
            importedDLLs: ["kernel32.dll", "user32.dll", "d3d11.dll"],
            graphicsAPIs: [.d3d11],
            antiCheatIndicators: [],
            kernelDriverIndicator: .no,
            subsystem: 3,
            analyzerVersion: "v1.0.0"
        )

        let data = try JSONEncoder().encode(facts)
        let decoded = try JSONDecoder().decode(RequirementFacts.self, from: data)

        XCTAssertEqual(decoded, facts)
        XCTAssertEqual(decoded.importedDLLs, ["d3d11.dll", "kernel32.dll", "user32.dll"])
    }

    func testHostIdentityDigestConsistency() {
        let host = HostIdentity(
            macOSVersion: "15.1",
            macOSBuild: "24B83",
            cpuArchitecture: "arm64",
            chipFamily: "Apple M3 Max",
            metalGPUFamily: "metal3",
            memoryClass: "32GB+",
            x8664Execution: .available
        )

        let digest1 = host.digest
        let digest2 = host.digest

        XCTAssertEqual(digest1, digest2)
        XCTAssertFalse(digest1.isEmpty)
    }

    func testLaunchPlanSerialization() throws {
        let plan = LaunchPlan(
            applicationID: ApplicationID(),
            binaryDigest: "abc123digest",
            binaryRelativePath: "bin/game.exe",
            generationID: GenerationID(),
            compositionDigest: "compdigest",
            hostIdentityDigest: "hostdigest",
            env: ["WINEPREFIX": "/tmp/prefix"],
            workingDirectory: "bin",
            arguments: ["-fullscreen"]
        )

        let data = try JSONEncoder().encode(plan)
        let decoded = try JSONDecoder().decode(LaunchPlan.self, from: data)

        XCTAssertEqual(decoded, plan)
        XCTAssertEqual(plan.digest, decoded.digest)
    }
}
