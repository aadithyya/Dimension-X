import Foundation
#if canImport(XCTest)
import XCTest
#endif
import DMXModel
import DMXProtocol
@testable import DMXCore

final class DMXCoreSubsystemTests: XCTestCase {

    func testHostIdentityProbe() {
        let host = HostIdentityProbe.probe()
        XCTAssertFalse(host.macOSVersion.isEmpty)
        XCTAssertFalse(host.cpuArchitecture.isEmpty)
        XCTAssertFalse(host.chipFamily.isEmpty)
        XCTAssertFalse(host.metalGPUFamily.isEmpty)
        XCTAssertFalse(host.digest.isEmpty)
    }

    func testStorageService() async throws {
        let storage = try StorageService(inMemory: true)

        let appID = ApplicationID()
        let facts = RequirementFacts(
            architecture: .x8664,
            isPE32Plus: .yes,
            importedDLLs: ["kernel32.dll", "d3d11.dll"],
            graphicsAPIs: [.d3d11],
            antiCheatIndicators: [],
            kernelDriverIndicator: .no,
            subsystem: 2,
            analyzerVersion: "1.0.0"
        )

        let app = ApplicationRecord(
            id: appID,
            name: "Game.exe",
            executablePath: "/path/to/Game.exe",
            binaryDigest: "digest123",
            facts: facts
        )

        try await storage.saveApplication(app)
        let retrieved = try await storage.getApplication(id: appID)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.name, "Game.exe")

        let allApps = try await storage.listApplications()
        XCTAssertEqual(allApps.count, 1)

        try await storage.deleteApplication(id: appID)
        let afterDelete = try await storage.getApplication(id: appID)
        XCTAssertNil(afterDelete)
    }

    func testEnvironmentManager() async throws {
        let storage = try StorageService(inMemory: true)
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("dmx_subsystem_test_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let envManager = EnvironmentManager(storage: storage, customBaseURL: tempDir)

        let appID = ApplicationID()
        let comp = RuntimeComposition(
            runtimeArtifactDigest: "wine-x86_64",
            cpuPath: .x8664HostExecution,
            graphicsProvider: .wined3dBundled
        )

        let (env, gen) = try await envManager.ensureEnvironment(for: appID, composition: comp)
        XCTAssertEqual(env.applicationID, appID)
        XCTAssertEqual(gen.ordinal, 1)

        let snap = try await envManager.createSnapshot(environmentID: env.id, composition: comp)
        XCTAssertEqual(snap.ordinal, 2)

        let rolledBack = try await envManager.rollback(environmentID: env.id, toGenerationID: gen.id)
        XCTAssertEqual(rolledBack.activeGenerationID, gen.id)
    }
}
