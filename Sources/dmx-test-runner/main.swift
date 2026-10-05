import Foundation
import DMXModel
import DMXProtocol
import DMXInspectKit
import DMXCore

@main
struct DMXTestRunner {
    static func main() {
        print("=== Running Dimension X (DMX) M1 Unit Tests ===")

        do {
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

            print("\n=== All M1 Unit Tests Passed Successfully! ===")
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
}
