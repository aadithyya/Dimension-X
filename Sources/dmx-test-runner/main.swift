import Foundation
import DMXModel
import DMXProtocol
import DMXInspectKit
import DMXCore

@main
struct DMXTestRunner {
    static func main() async {
        print("=== Running Dimension X (DMX) Full Test Suite ===")

        do {
            // M1 Tests
            try testCanonicalDigestStabilityForRuntimeComposition()
            print("✓ testCanonicalDigestStabilityForRuntimeComposition passed (100 shuffled key variations)")

            try testCanonicalJSONOutputFormatting()
            print("✓ testCanonicalJSONOutputFormatting passed")

            try testRequirementFactsRoundTrip()
            print("✓ testRequirementFactsRoundTrip passed")

            testHostIdentityDigestConsistency()
            print("✓ testHostIdentityDigestConsistency passed")

            try testLaunchPlanSerialization()
            print("✓ testLaunchPlanSerialization passed")

            try testValidQualificationEvidenceCreation()
            print("✓ testValidQualificationEvidenceCreation passed")

            try testValidCompatibilityEvidenceCreation()
            print("✓ testValidCompatibilityEvidenceCreation passed")

            testQualificationWithApplicationFieldsThrows()
            print("✓ testQualificationWithApplicationFieldsThrows passed")

            testCompatibilityWithQualificationFieldsThrows()
            print("✓ testCompatibilityWithQualificationFieldsThrows passed")

            try testEncodeAndDecodeSingleFrame()
            print("✓ testEncodeAndDecodeSingleFrame passed")

            try testFragmentedStreamingDecoder()
            print("✓ testFragmentedStreamingDecoder passed")

            testOversizedEncodeRejection()
            print("✓ testOversizedEncodeRejection passed")

            testOversizedDecodeRejection()
            print("✓ testOversizedDecodeRejection passed")

            try testDCPRequestResponseRoundTrip()
            print("✓ testDCPRequestResponseRoundTrip passed")

            try testWCPMessageRoundTrip()
            print("✓ testWCPMessageRoundTrip passed")

            try testICPMessageRoundTrip()
            print("✓ testICPMessageRoundTrip passed")

            // New Subsystem Tests
            try testPEParserSyntheticBinary()
            print("✓ testPEParserSyntheticBinary passed")

            testPEParserCorruptInputs()
            print("✓ testPEParserCorruptInputs passed")

            try await testStorageServiceCRUD()
            print("✓ testStorageServiceCRUD passed")

            testHostIdentityProbe()
            print("✓ testHostIdentityProbe passed")

            try await testEnvironmentManagerGenerationsAndRollback()
            print("✓ testEnvironmentManagerGenerationsAndRollback passed")

            try await testDCPListenerAndClientIntegration()
            print("✓ testDCPListenerAndClientIntegration passed")

            print("\n=== All Dimension X Tests Passed Successfully! (22/22) ===")
        } catch {
            print("\n❌ Test Suite Failed with error: \(error)")
            exit(1)
        }
    }

    // --- DMXModelTests ---

    static func testCanonicalDigestStabilityForRuntimeComposition() throws {
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

            guard composition.digest == expectedDigest else {
                fatalError("Canonical digest mismatch! Expected \(expectedDigest), got \(composition.digest)")
            }
        }
    }

    static func testCanonicalJSONOutputFormatting() throws {
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

        let expectedJSON = "{\"a\":42,\"array\":[\"b\",\"a\"],\"boolVal\":true,\"nullVal\":null,\"z\":\"last\"}"
        guard jsonString == expectedJSON else {
            fatalError("Canonical JSON formatting failed: expected \(expectedJSON), got \(jsonString)")
        }
    }

    static func testRequirementFactsRoundTrip() throws {
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
        guard decoded == facts else { fatalError("RequirementFacts decode mismatch") }
    }

    static func testHostIdentityDigestConsistency() {
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
        guard digest1 == digest2, !digest1.isEmpty else { fatalError("HostIdentity digest mismatch") }
    }

    static func testLaunchPlanSerialization() throws {
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
        guard decoded == plan, plan.digest == decoded.digest else { fatalError("LaunchPlan decode mismatch") }
    }

    static func testValidQualificationEvidenceCreation() throws {
        let evidence = try Evidence(
            kind: .qualification,
            compositionDigest: "comp123",
            hostIdentityDigest: "host123",
            qualificationTest: "boot+console",
            qualificationVerdict: .qualified,
            notes: "Qualification passed cleanly"
        )

        guard evidence.kind == .qualification, evidence.qualificationVerdict == .qualified, evidence.applicationID == nil else {
            fatalError("Qualification evidence invariant violated")
        }
    }

    static func testValidCompatibilityEvidenceCreation() throws {
        let appId = ApplicationID()
        let evidence = try Evidence(
            kind: .compatibility,
            compositionDigest: "comp123",
            hostIdentityDigest: "host123",
            applicationID: appId,
            applicationBinaryDigest: "bin123",
            compatibilityVerdict: .works,
            performance: .measuredOK,
            performanceSample: PerformanceSample(frameTimeP50ms: 16.6, source: "test-harness"),
            stability: "stable"
        )

        guard evidence.kind == .compatibility, evidence.compatibilityVerdict == .works, evidence.applicationID == appId, evidence.qualificationVerdict == nil else {
            fatalError("Compatibility evidence invariant violated")
        }
    }

    static func testQualificationWithApplicationFieldsThrows() {
        do {
            _ = try Evidence(
                kind: .qualification,
                compositionDigest: "comp123",
                hostIdentityDigest: "host123",
                qualificationVerdict: .qualified,
                applicationID: ApplicationID()
            )
            fatalError("Expected throwing error on invalid qualification fields")
        } catch Evidence.ValidationError.qualificationCannotContainApplicationFields {
            // expected
        } catch {
            fatalError("Unexpected error type: \(error)")
        }
    }

    static func testCompatibilityWithQualificationFieldsThrows() {
        do {
            _ = try Evidence(
                kind: .compatibility,
                compositionDigest: "comp123",
                hostIdentityDigest: "host123",
                qualificationVerdict: .qualified,
                applicationID: ApplicationID(),
                compatibilityVerdict: .works
            )
            fatalError("Expected throwing error on invalid compatibility fields")
        } catch Evidence.ValidationError.compatibilityCannotContainQualificationFields {
            // expected
        } catch {
            fatalError("Unexpected error type: \(error)")
        }
    }

    // --- DMXProtocolTests ---

    static func testEncodeAndDecodeSingleFrame() throws {
        let codec = FrameCodec(maxFrameBytes: 1024)
        let payload = Data("Hello Dimension X".utf8)

        let encoded = try codec.encode(payload: payload)
        guard encoded.count == 4 + payload.count else { fatalError("Encoded frame count mismatch") }

        var decoder = FrameCodec.Decoder(maxFrameBytes: 1024)
        decoder.feed(data: encoded)

        let decodedPayload = try decoder.next()
        guard decodedPayload == payload else { fatalError("Decoded payload mismatch") }

        let nextFrame = try decoder.next()
        guard nextFrame == nil else { fatalError("Expected nil next frame") }
    }

    static func testFragmentedStreamingDecoder() throws {
        let codec = FrameCodec(maxFrameBytes: 1024)
        let payload1 = Data("Payload 1".utf8)
        let payload2 = Data("Payload 2 - longer data segment".utf8)

        let encoded1 = try codec.encode(payload: payload1)
        let encoded2 = try codec.encode(payload: payload2)

        var combined = Data()
        combined.append(encoded1)
        combined.append(encoded2)

        var decoder = FrameCodec.Decoder(maxFrameBytes: 1024)
        var framesRead: [Data] = []
        for byte in combined {
            decoder.feed(data: Data([byte]))
            if let frame = try decoder.next() {
                framesRead.append(frame)
            }
        }

        guard framesRead.count == 2, framesRead[0] == payload1, framesRead[1] == payload2 else {
            fatalError("Fragmented decoder failed")
        }
    }

    static func testOversizedEncodeRejection() {
        let codec = FrameCodec(maxFrameBytes: 10)
        let payload = Data("12345678901".utf8)
        do {
            _ = try codec.encode(payload: payload)
            fatalError("Expected oversized encode error")
        } catch FrameError.oversized(let len) {
            guard len == 11 else { fatalError("Unexpected oversized length: \(len)") }
        } catch {
            fatalError("Unexpected error: \(error)")
        }
    }

    static func testOversizedDecodeRejection() {
        var decoder = FrameCodec.Decoder(maxFrameBytes: 10)
        var lenHeader = UInt32(20).bigEndian
        let headerData = Data(bytes: &lenHeader, count: 4)
        decoder.feed(data: headerData)
        do {
            _ = try decoder.next()
            fatalError("Expected oversized decode error")
        } catch FrameError.oversized(let len) {
            guard len == 20 else { fatalError("Unexpected oversized length: \(len)") }
        } catch {
            fatalError("Unexpected error: \(error)")
        }
    }

    static func testDCPRequestResponseRoundTrip() throws {
        let req = DCPRequest(
            method: "application.import",
            payload: .object(["path": .string("/tmp/game.exe")]),
            idempotencyKey: "key-123"
        )
        let reqData = try JSONEncoder().encode(req)
        let decodedReq = try JSONDecoder().decode(DCPRequest.self, from: reqData)
        guard decodedReq.method == "application.import", decodedReq.idempotencyKey == "key-123" else {
            fatalError("DCPRequest decode mismatch")
        }

        let resp = DCPResponse(
            id: req.id,
            ok: true,
            payload: .object(["applicationID": .string("app-123")])
        )
        let respData = try JSONEncoder().encode(resp)
        let decodedResp = try JSONDecoder().decode(DCPResponse.self, from: respData)
        guard decodedResp.id == req.id, decodedResp.ok else {
            fatalError("DCPResponse decode mismatch")
        }
    }

    static func testWCPMessageRoundTrip() throws {
        let plan = LaunchPlan(
            applicationID: ApplicationID(),
            binaryDigest: "digest123",
            binaryRelativePath: "game.exe",
            generationID: GenerationID(),
            compositionDigest: "comp123",
            hostIdentityDigest: "host123",
            env: ["WINEPREFIX": "/tmp/prefix"],
            workingDirectory: ".",
            arguments: []
        )
        let start = WCP.Start(plan: plan)
        let startData = try JSONEncoder().encode(start)
        let decodedStart = try JSONDecoder().decode(WCP.Start.self, from: startData)
        guard decodedStart.plan.binaryDigest == "digest123" else { fatalError("WCP.Start decode mismatch") }

        let status = WCP.Message(payload: .started(pid: 1234, pgid: 1234))
        let statusData = try JSONEncoder().encode(status)
        let decodedStatus = try JSONDecoder().decode(WCP.Message.self, from: statusData)
        if case .started(let pid, let pgid) = decodedStatus.payload {
            guard pid == 1234, pgid == 1234 else { fatalError("WCP.Message status payload mismatch") }
        } else {
            fatalError("Expected .started payload")
        }
    }

    static func testICPMessageRoundTrip() throws {
        let req = ICP.Request(targetPath: "/tmp/game.exe")
        let reqData = try JSONEncoder().encode(req)
        let decodedReq = try JSONDecoder().decode(ICP.Request.self, from: reqData)
        guard decodedReq.targetPath == "/tmp/game.exe" else { fatalError("ICP.Request decode mismatch") }

        let facts = RequirementFacts(
            architecture: .x8664,
            isPE32Plus: .yes,
            importedDLLs: ["kernel32.dll"],
            graphicsAPIs: [.d3d11],
            antiCheatIndicators: [],
            kernelDriverIndicator: .no,
            analyzerVersion: "v1.0.0"
        )
        let resp = ICP.Response(ok: true, facts: facts)
        let respData = try JSONEncoder().encode(resp)
        let decodedResp = try JSONDecoder().decode(ICP.Response.self, from: respData)
        guard decodedResp.ok, decodedResp.facts?.architecture == .x8664 else { fatalError("ICP.Response decode mismatch") }
    }

    // --- New Subsystem Tests ---

    static func testPEParserSyntheticBinary() throws {
        // Construct a valid in-memory PE32+ (x86_64) image
        var binary = Data(repeating: 0, count: 2048)

        // 1. DOS Header
        var dosMagic: UInt16 = 0x5A4D // "MZ"
        binary.replaceSubrange(0..<2, with: Data(bytes: &dosMagic, count: 2))
        var peOffset: UInt32 = 128
        binary.replaceSubrange(0x3C..<0x40, with: Data(bytes: &peOffset, count: 4))

        // 2. PE Signature at offset 128
        var peSig: UInt32 = 0x00004550 // "PE\0\0"
        binary.replaceSubrange(128..<132, with: Data(bytes: &peSig, count: 4))

        // 3. COFF File Header (offset 132)
        var machine: UInt16 = 0x8664 // x86_64
        binary.replaceSubrange(132..<134, with: Data(bytes: &machine, count: 2))
        var numSections: UInt16 = 1
        binary.replaceSubrange(134..<136, with: Data(bytes: &numSections, count: 2))
        var sizeOfOptHeader: UInt16 = 240
        binary.replaceSubrange(148..<150, with: Data(bytes: &sizeOfOptHeader, count: 2))
        var characteristics: UInt16 = 0x0002 // executable
        binary.replaceSubrange(150..<152, with: Data(bytes: &characteristics, count: 2))

        // 4. Optional Header (offset 152)
        var optMagic: UInt16 = 0x020b // PE32+
        binary.replaceSubrange(152..<154, with: Data(bytes: &optMagic, count: 2))
        var subsystem: UInt16 = 2 // Windows GUI
        binary.replaceSubrange((152 + 68)..<(152 + 70), with: Data(bytes: &subsystem, count: 2))

        // Data directory 1 (Import table) at 152 + 112 + 8
        var importDirRVA: UInt32 = 0x2000
        var importDirSize: UInt32 = 0x100
        binary.replaceSubrange((152 + 120)..<(152 + 124), with: Data(bytes: &importDirRVA, count: 4))
        binary.replaceSubrange((152 + 124)..<(152 + 128), with: Data(bytes: &importDirSize, count: 4))

        // 5. Section Header (.rdata) at offset 152 + 240 = 392
        let secOffset = 392
        let secName = ".rdata\0\0"
        binary.replaceSubrange(secOffset..<(secOffset + 8), with: Data(secName.utf8))
        var virtualSize: UInt32 = 0x1000
        var virtualAddress: UInt32 = 0x2000
        var rawDataSize: UInt32 = 0x400
        var rawDataOffset: UInt32 = 0x400 // file offset 1024
        binary.replaceSubrange((secOffset + 8)..<(secOffset + 12), with: Data(bytes: &virtualSize, count: 4))
        binary.replaceSubrange((secOffset + 12)..<(secOffset + 16), with: Data(bytes: &virtualAddress, count: 4))
        binary.replaceSubrange((secOffset + 16)..<(secOffset + 20), with: Data(bytes: &rawDataSize, count: 4))
        binary.replaceSubrange((secOffset + 20)..<(secOffset + 24), with: Data(bytes: &rawDataOffset, count: 4))

        // 6. Import Directory at file offset 1024 (RVA 0x2000)
        // First descriptor
        var nameRVA: UInt32 = 0x2040 // points to file offset 1024 + 64 = 1088
        binary.replaceSubrange((1024 + 12)..<(1024 + 16), with: Data(bytes: &nameRVA, count: 4))

        // Second descriptor (all zeros already)

        // Write DLL name at offset 1088
        let dllName = "d3d11.dll\0"
        binary.replaceSubrange(1088..<(1088 + dllName.utf8.count), with: Data(dllName.utf8))

        let parser = PEParser()
        let facts = try parser.parse(data: binary)

        guard facts.architecture == .x8664 else {
            fatalError("PEParser failed: expected x86_64, got \(facts.architecture)")
        }
        guard facts.isPE32Plus == .yes else {
            fatalError("PEParser failed: expected PE32+, got \(facts.isPE32Plus)")
        }
        guard facts.importedDLLs.contains("d3d11.dll") else {
            fatalError("PEParser failed: expected imported d3d11.dll, got \(facts.importedDLLs)")
        }
        guard facts.graphicsAPIs.contains(.d3d11) else {
            fatalError("PEParser failed: expected .d3d11 graphics API, got \(facts.graphicsAPIs)")
        }
        guard facts.subsystem == 2 else {
            fatalError("PEParser failed: expected subsystem 2, got \(String(describing: facts.subsystem))")
        }
    }

    static func testPEParserCorruptInputs() {
        let parser = PEParser()

        // Too short
        do {
            _ = try parser.parse(data: Data([0x5A, 0x4D]))
            fatalError("Expected dataTooShort error")
        } catch PEParserError.dataTooShort {
            // expected
        } catch {
            fatalError("Unexpected error: \(error)")
        }

        // Invalid DOS signature
        do {
            _ = try parser.parse(data: Data(repeating: 0, count: 128))
            fatalError("Expected invalidDOSSignature error")
        } catch PEParserError.invalidDOSSignature {
            // expected
        } catch {
            fatalError("Unexpected error: \(error)")
        }
    }

    static func testStorageServiceCRUD() async throws {
        let storage = try StorageService(inMemory: true)

        let appID = ApplicationID()
        let facts = RequirementFacts(
            architecture: .x8664,
            isPE32Plus: .yes,
            importedDLLs: ["d3d11.dll", "kernel32.dll"],
            graphicsAPIs: [.d3d11],
            antiCheatIndicators: [],
            kernelDriverIndicator: .no,
            subsystem: 2,
            analyzerVersion: "1.0.0"
        )
        let app = ApplicationRecord(
            id: appID,
            name: "TestGame.exe",
            executablePath: "/Games/TestGame.exe",
            binaryDigest: "sha256:abc",
            facts: facts
        )

        // Save and retrieve
        try await storage.saveApplication(app)
        let retrievedApp = try await storage.getApplication(id: appID)
        guard let rApp = retrievedApp, rApp.name == "TestGame.exe", rApp.facts.architecture == .x8664 else {
            fatalError("StorageService failed to retrieve application")
        }

        // List
        let list = try await storage.listApplications()
        guard list.count == 1, list[0].id == appID else {
            fatalError("StorageService listApplications failed")
        }

        // Evidence
        let evidence = try Evidence(
            kind: .qualification,
            compositionDigest: "comp-123",
            hostIdentityDigest: "host-123",
            qualificationVerdict: .qualified
        )
        try await storage.saveEvidence(evidence)
        let evidenceList = try await storage.listEvidence(compositionDigest: "comp-123")
        guard evidenceList.count == 1, evidenceList[0].id == evidence.id else {
            fatalError("StorageService failed to retrieve evidence")
        }

        // Delete
        try await storage.deleteApplication(id: appID)
        let afterDelete = try await storage.getApplication(id: appID)
        guard afterDelete == nil else {
            fatalError("StorageService failed to delete application")
        }
    }

    static func testHostIdentityProbe() {
        let host = HostIdentityProbe.probe()
        guard !host.macOSVersion.isEmpty, host.macOSVersion != "unknown" else {
            fatalError("HostIdentityProbe failed to detect macOS version: \(host.macOSVersion)")
        }
        guard !host.cpuArchitecture.isEmpty else {
            fatalError("HostIdentityProbe failed to detect CPU architecture")
        }
        guard !host.chipFamily.isEmpty else {
            fatalError("HostIdentityProbe failed to detect chip family")
        }
        guard !host.metalGPUFamily.isEmpty else {
            fatalError("HostIdentityProbe failed to detect metal GPU family")
        }
        guard !host.digest.isEmpty else {
            fatalError("HostIdentity digest is empty")
        }
    }

    static func testEnvironmentManagerGenerationsAndRollback() async throws {
        let storage = try StorageService(inMemory: true)
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("dmx_test_env_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let envManager = EnvironmentManager(storage: storage, customBaseURL: tempDir)

        let appID = ApplicationID()
        let comp = RuntimeComposition(
            runtimeArtifactDigest: "default-wine",
            cpuPath: .x8664HostExecution,
            graphicsProvider: .wined3dBundled
        )

        // 1. Ensure initial environment and generation
        let (env1, gen1) = try await envManager.ensureEnvironment(for: appID, composition: comp)
        guard env1.applicationID == appID, gen1.ordinal == 1, env1.activeGenerationID == gen1.id else {
            fatalError("EnvironmentManager failed to create initial generation")
        }

        let prefixDir = await envManager.prefixURL(for: env1.id, generationID: gen1.id)
        guard FileManager.default.fileExists(atPath: prefixDir.appendingPathComponent("drive_c").path) else {
            fatalError("EnvironmentManager failed to create skeleton drive_c")
        }

        // 2. Snapshot to create generation 2
        let gen2 = try await envManager.createSnapshot(environmentID: env1.id, composition: comp)
        guard gen2.ordinal == 2 else {
            fatalError("Snapshot generation ordinal expected 2, got \(gen2.ordinal)")
        }
        let updatedEnv = try await storage.getEnvironment(id: env1.id)
        guard updatedEnv?.activeGenerationID == gen2.id else {
            fatalError("Active generation was not updated after snapshot")
        }

        // 3. Rollback to generation 1
        let rolledBackEnv = try await envManager.rollback(environmentID: env1.id, toGenerationID: gen1.id)
        guard rolledBackEnv.activeGenerationID == gen1.id else {
            fatalError("Rollback failed to restore generation 1")
        }
    }

    static func testDCPListenerAndClientIntegration() async throws {
        let storage = try StorageService(inMemory: true)
        let analyzer = AnalyzerService()
        let broker = ExecutionBroker.shared
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("dmx_dcp_test_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let envManager = EnvironmentManager(storage: storage, customBaseURL: tempDir)
        let handler = DCPHandler(storage: storage, analyzer: analyzer, broker: broker, envManager: envManager)

        let sockURL = URL(fileURLWithPath: "/tmp/dmx_t\(UInt32.random(in: 100000...999999)).sock")
        let listener = DCPListener(socketURL: sockURL, handler: handler)
        try await listener.start()
        defer {
            Task { await listener.stop() }
        }

        // Connect client after brief pause to allow accept loop to bind and enter accept
        try await Task.sleep(nanoseconds: 30_000_000)
        let client = DCPClient(socketURL: sockURL)
        try await client.connect()
        defer {
            Task { await client.disconnect() }
        }

        // 1. Test system.status
        let statusResp = try await client.send(method: "system.status")
        guard statusResp.ok, let payload = statusResp.payload, case .object(let dict) = payload else {
            fatalError("system.status failed or payload is invalid")
        }
        guard dict["ready"] == .bool(true) else {
            fatalError("system.status expected ready: true")
        }

        // 2. Test system.hostIdentity
        let hostResp = try await client.send(method: "system.hostIdentity")
        guard hostResp.ok, let hostPayload = hostResp.payload else {
            fatalError("system.hostIdentity failed")
        }
        let hostData = try JSONEncoder().encode(hostPayload)
        let host = try JSONDecoder().decode(HostIdentity.self, from: hostData)
        guard !host.macOSVersion.isEmpty else {
            fatalError("Decoded HostIdentity macOSVersion is empty")
        }

        // 3. Test application.list (empty initially)
        let listResp = try await client.send(method: "application.list")
        guard listResp.ok, let listPayload = listResp.payload, case .array(let apps) = listPayload, apps.isEmpty else {
            fatalError("application.list expected empty array")
        }
    }
}
