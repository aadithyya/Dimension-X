#if canImport(XCTest)
import XCTest
#else
import Foundation

open class XCTestCase {
    public required init() {}
    open func setUpWithError() throws {}
    open func tearDownWithError() throws {}
}

public func XCTAssertEqual<T: Equatable>(_ a: T, _ b: T, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
    guard a == b else {
        let msg = message()
        print("❌ XCTAssertEqual Failure: (\(a)) != (\(b)) \(msg.isEmpty ? "" : "- " + msg) at \(file):\(line)")
        exit(1)
    }
}

public func XCTAssertNotNil(_ expression: Any?, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
    guard expression != nil else {
        let msg = message()
        print("❌ XCTAssertNotNil Failure \(msg.isEmpty ? "" : "- " + msg) at \(file):\(line)")
        exit(1)
    }
}

public func XCTAssertNil(_ expression: Any?, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
    guard expression == nil else {
        let msg = message()
        print("❌ XCTAssertNil Failure \(msg.isEmpty ? "" : "- " + msg) at \(file):\(line)")
        exit(1)
    }
}

public func XCTAssertTrue(_ expression: Bool, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
    guard expression else {
        let msg = message()
        print("❌ XCTAssertTrue Failure \(msg.isEmpty ? "" : "- " + msg) at \(file):\(line)")
        exit(1)
    }
}

public func XCTAssertFalse(_ expression: Bool, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
    guard !expression else {
        let msg = message()
        print("❌ XCTAssertFalse Failure \(msg.isEmpty ? "" : "- " + msg) at \(file):\(line)")
        exit(1)
    }
}

public func XCTFail(_ message: String = "", file: StaticString = #file, line: UInt = #line) {
    print("❌ XCTFail: \(message) at \(file):\(line)")
    exit(1)
}

public func XCTAssertThrowsError<T>(_ expression: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line, _ errorHandler: (Error) -> Void = { _ in }) {
    do {
        _ = try expression()
        print("❌ XCTAssertThrowsError Failure: Expected error but succeeded at \(file):\(line)")
        exit(1)
    } catch {
        errorHandler(error)
    }
}
#endif
