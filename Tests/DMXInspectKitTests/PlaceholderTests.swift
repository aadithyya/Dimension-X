#if canImport(XCTest)
import XCTest
#endif
@testable import DMXInspectKit

final class DMXInspectKitTests: XCTestCase {
    func testPlaceholder() {
        XCTAssertNotNil(PEParser())
    }
}
