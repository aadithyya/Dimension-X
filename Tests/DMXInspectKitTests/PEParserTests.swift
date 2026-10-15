import Foundation
#if canImport(XCTest)
import XCTest
#endif
import DMXModel
@testable import DMXInspectKit

final class PEParserTests: XCTestCase {

    func testSyntheticPE32PlusParsing() throws {
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
        var nameRVA: UInt32 = 0x2040 // points to file offset 1088
        binary.replaceSubrange((1024 + 12)..<(1024 + 16), with: Data(bytes: &nameRVA, count: 4))

        let dllName = "d3d11.dll\0"
        binary.replaceSubrange(1088..<(1088 + dllName.utf8.count), with: Data(dllName.utf8))

        let parser = PEParser()
        let facts = try parser.parse(data: binary)

        XCTAssertEqual(facts.architecture, .x8664)
        XCTAssertEqual(facts.isPE32Plus, .yes)
        XCTAssertTrue(facts.importedDLLs.contains("d3d11.dll"))
        XCTAssertTrue(facts.graphicsAPIs.contains(.d3d11))
        XCTAssertEqual(facts.subsystem, 2)
    }

    func testCorruptDataRejections() {
        let parser = PEParser()
        XCTAssertThrowsError(try parser.parse(data: Data([0x5A, 0x4D])))
        XCTAssertThrowsError(try parser.parse(data: Data(repeating: 0, count: 128)))
    }
}
