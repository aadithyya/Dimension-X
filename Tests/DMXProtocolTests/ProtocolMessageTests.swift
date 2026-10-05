import Foundation
#if canImport(XCTest)
import XCTest
#endif
@testable import DMXModel
@testable import DMXProtocol

final class ProtocolMessageTests: XCTestCase {

    func testDCPRequestResponseRoundTrip() throws {
        let req = DCPRequest(
            method: "application.import",
            payload: .object(["path": .string("/tmp/game.exe")]),
            idempotencyKey: "key-123"
        )

        let reqData = try JSONEncoder().encode(req)
        let decodedReq = try JSONDecoder().decode(DCPRequest.self, from: reqData)

        XCTAssertEqual(decodedReq.method, "application.import")
        XCTAssertEqual(decodedReq.idempotencyKey, "key-123")

        let resp = DCPResponse(
            id: req.id,
            ok: true,
            payload: .object(["applicationID": .string("app-123")])
        )

        let respData = try JSONEncoder().encode(resp)
        let decodedResp = try JSONDecoder().decode(DCPResponse.self, from: respData)

        XCTAssertEqual(decodedResp.id, req.id)
        XCTAssertTrue(decodedResp.ok)
    }

    func testWCPMessageRoundTrip() throws {
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

        XCTAssertEqual(decodedStart.plan.binaryDigest, "digest123")

        let status = WCP.Message(payload: .started(pid: 1234, pgid: 1234))
        let statusData = try JSONEncoder().encode(status)
        let decodedStatus = try JSONDecoder().decode(WCP.Message.self, from: statusData)

        if case .started(let pid, let pgid) = decodedStatus.payload {
            XCTAssertEqual(pid, 1234)
            XCTAssertEqual(pgid, 1234)
        } else {
            XCTFail("Expected .started payload")
        }
    }

    func testICPMessageRoundTrip() throws {
        let req = ICP.Request(targetPath: "/tmp/game.exe")
        let reqData = try JSONEncoder().encode(req)
        let decodedReq = try JSONDecoder().decode(ICP.Request.self, from: reqData)

        XCTAssertEqual(decodedReq.targetPath, "/tmp/game.exe")

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

        XCTAssertTrue(decodedResp.ok)
        XCTAssertEqual(decodedResp.facts?.architecture, .x8664)
    }
}
