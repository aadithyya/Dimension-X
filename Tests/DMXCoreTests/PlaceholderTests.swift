#if canImport(XCTest)
import XCTest
#endif
@testable import DMXCore

final class DMXCoreTests: XCTestCase {
    func testProvisionalLimits() {
        XCTAssertEqual(ProvisionalLimits.maxDCPFrameBytes, 16 * 1024 * 1024)
    }
}
