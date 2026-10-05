import Foundation
#if canImport(XCTest)
import XCTest
#endif
@testable import DMXModel

final class EvidenceTests: XCTestCase {

    func testValidQualificationEvidenceCreation() throws {
        let evidence = try Evidence(
            kind: .qualification,
            compositionDigest: "comp123",
            hostIdentityDigest: "host123",
            qualificationTest: "boot+console",
            qualificationVerdict: .qualified,
            notes: "Qualification passed cleanly"
        )

        XCTAssertEqual(evidence.kind, .qualification)
        XCTAssertEqual(evidence.qualificationVerdict, .qualified)
        XCTAssertNil(evidence.applicationID)
    }

    func testValidCompatibilityEvidenceCreation() throws {
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

        XCTAssertEqual(evidence.kind, .compatibility)
        XCTAssertEqual(evidence.compatibilityVerdict, .works)
        XCTAssertEqual(evidence.applicationID, appId)
        XCTAssertNil(evidence.qualificationVerdict)
    }

    func testQualificationWithApplicationFieldsThrows() {
        XCTAssertThrowsError(
            try Evidence(
                kind: .qualification,
                compositionDigest: "comp123",
                hostIdentityDigest: "host123",
                qualificationVerdict: .qualified,
                applicationID: ApplicationID()
            )
        ) { error in
            XCTAssertEqual(error as? Evidence.ValidationError, .qualificationCannotContainApplicationFields)
        }
    }

    func testCompatibilityWithQualificationFieldsThrows() {
        XCTAssertThrowsError(
            try Evidence(
                kind: .compatibility,
                compositionDigest: "comp123",
                hostIdentityDigest: "host123",
                qualificationVerdict: .qualified,
                applicationID: ApplicationID(),
                compatibilityVerdict: .works
            )
        ) { error in
            XCTAssertEqual(error as? Evidence.ValidationError, .compatibilityCannotContainQualificationFields)
        }
    }
}
