import Foundation
import DMXModel

public enum PEParserError: Error, LocalizedError, Equatable {
    case dataTooShort
    case invalidDOSSignature
    case invalidPEOffset
    case invalidPESignature
    case invalidCOFFHeader
    case invalidOptionalHeader
    case sectionOutOfBounds
    case readError(String)

    public var errorDescription: String? {
        switch self {
        case .dataTooShort:
            return "File data is too short to be a valid PE executable."
        case .invalidDOSSignature:
            return "Invalid DOS signature (missing 'MZ')."
        case .invalidPEOffset:
            return "Invalid PE header offset in DOS header."
        case .invalidPESignature:
            return "Invalid PE signature (missing 'PE\\0\\0')."
        case .invalidCOFFHeader:
            return "Failed to read COFF header."
        case .invalidOptionalHeader:
            return "Failed to read Optional Header."
        case .sectionOutOfBounds:
            return "Section header points outside file boundaries."
        case .readError(let detail):
            return "Read error: \(detail)"
        }
    }
}

public struct PESection {
    public let name: String
    public let virtualAddress: UInt32
    public let virtualSize: UInt32
    public let rawDataOffset: UInt32
    public let rawDataSize: UInt32

    public func contains(rva: UInt32) -> Bool {
        let size = max(virtualSize, rawDataSize)
        return rva >= virtualAddress && rva < virtualAddress + size
    }

    public func fileOffset(for rva: UInt32) -> UInt32? {
        guard contains(rva: rva) else { return nil }
        let offsetIntoSection = rva - virtualAddress
        guard offsetIntoSection < rawDataSize else { return nil }
        return rawDataOffset + offsetIntoSection
    }
}

public struct PEParser {
    public static let currentAnalyzerVersion = "1.0.0-dmx"

    public init() {}

    /// Parse RequirementFacts from Data in memory.
    public func parse(data: Data) throws -> RequirementFacts {
        guard data.count >= 64 else {
            throw PEParserError.dataTooShort
        }

        // 1. DOS Header Check: magic bytes 'M', 'Z' (0x5A4D)
        let dosMagic = data.readUInt16(at: 0)
        guard dosMagic == 0x5A4D else {
            throw PEParserError.invalidDOSSignature
        }

        // e_lfanew is at offset 0x3C (4 bytes)
        let peOffset = Int(data.readUInt32(at: 0x3C))
        guard peOffset > 0, peOffset + 24 <= data.count else {
            throw PEParserError.invalidPEOffset
        }

        // 2. PE Signature: "PE\0\0" (0x00004550)
        let peSig = data.readUInt32(at: peOffset)
        guard peSig == 0x00004550 else {
            throw PEParserError.invalidPESignature
        }

        // 3. COFF File Header (20 bytes following signature)
        let coffOffset = peOffset + 4
        guard coffOffset + 20 <= data.count else {
            throw PEParserError.invalidCOFFHeader
        }

        let machineRaw = data.readUInt16(at: coffOffset)
        let numberOfSections = Int(data.readUInt16(at: coffOffset + 2))
        let sizeOfOptionalHeader = Int(data.readUInt16(at: coffOffset + 16))
        let characteristics = data.readUInt16(at: coffOffset + 18)

        let architecture: PEArchitecture
        switch machineRaw {
        case 0x014c:
            architecture = .i386
        case 0x8664:
            architecture = .x8664
        case 0xaa64:
            architecture = .arm64
        default:
            architecture = .unknown
        }

        // 4. Optional Header (if present)
        let optHeaderOffset = coffOffset + 20
        var isPE32Plus: Tri = .unknown
        var subsystem: UInt16? = nil
        var importDirRVA: UInt32 = 0
        var importDirSize: UInt32 = 0

        if sizeOfOptionalHeader >= 2 {
            guard optHeaderOffset + sizeOfOptionalHeader <= data.count else {
                throw PEParserError.invalidOptionalHeader
            }
            let optMagic = data.readUInt16(at: optHeaderOffset)
            if optMagic == 0x010b { // PE32
                isPE32Plus = .no
                if sizeOfOptionalHeader >= 70 {
                    subsystem = data.readUInt16(at: optHeaderOffset + 68)
                }
                if sizeOfOptionalHeader >= 96 + 16 { // At least 2 data directories
                    importDirRVA = data.readUInt32(at: optHeaderOffset + 96 + 8)
                    importDirSize = data.readUInt32(at: optHeaderOffset + 96 + 12)
                }
            } else if optMagic == 0x020b { // PE32+
                isPE32Plus = .yes
                if sizeOfOptionalHeader >= 70 {
                    subsystem = data.readUInt16(at: optHeaderOffset + 68)
                }
                if sizeOfOptionalHeader >= 112 + 16 { // At least 2 data directories
                    importDirRVA = data.readUInt32(at: optHeaderOffset + 112 + 8)
                    importDirSize = data.readUInt32(at: optHeaderOffset + 112 + 12)
                }
            }
        }

        // 5. Section Headers
        let sectionsOffset = optHeaderOffset + sizeOfOptionalHeader
        var sections: [PESection] = []
        for i in 0..<numberOfSections {
            let sectionStart = sectionsOffset + (i * 40)
            guard sectionStart + 40 <= data.count else {
                break
            }
            let nameData = data.subdata(in: sectionStart..<(sectionStart + 8))
            let name = String(decoding: nameData, as: UTF8.self).trimmingCharacters(in: .controlCharacters).trimmingCharacters(in: ["\0"])
            let virtualSize = data.readUInt32(at: sectionStart + 8)
            let virtualAddress = data.readUInt32(at: sectionStart + 12)
            let rawDataSize = data.readUInt32(at: sectionStart + 16)
            let rawDataOffset = data.readUInt32(at: sectionStart + 20)

            sections.append(PESection(
                name: name,
                virtualAddress: virtualAddress,
                virtualSize: virtualSize,
                rawDataOffset: rawDataOffset,
                rawDataSize: rawDataSize
            ))
        }

        func rvaToFileOffset(_ rva: UInt32) -> Int? {
            for section in sections {
                if let off = section.fileOffset(for: rva) {
                    return Int(off)
                }
            }
            return nil
        }

        // 6. Parse Import Directory Table
        var importedDLLs: Set<String> = []
        if importDirRVA != 0 && importDirSize > 0 {
            if let importFileOffset = rvaToFileOffset(importDirRVA) {
                var currentDescriptorOffset = importFileOffset
                while currentDescriptorOffset + 20 <= data.count {
                    let originalFirstThunk = data.readUInt32(at: currentDescriptorOffset)
                    let timeDateStamp = data.readUInt32(at: currentDescriptorOffset + 4)
                    let forwarderChain = data.readUInt32(at: currentDescriptorOffset + 8)
                    let nameRVA = data.readUInt32(at: currentDescriptorOffset + 12)
                    let firstThunk = data.readUInt32(at: currentDescriptorOffset + 16)

                    // An all-zero entry marks the end of the array
                    if originalFirstThunk == 0 && timeDateStamp == 0 && forwarderChain == 0 && nameRVA == 0 && firstThunk == 0 {
                        break
                    }

                    if nameRVA != 0, let dllNameOffset = rvaToFileOffset(nameRVA) {
                        if let dllName = data.readASCIIString(at: dllNameOffset, maxLength: 256) {
                            let trimmed = dllName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                            if !trimmed.isEmpty {
                                importedDLLs.insert(trimmed)
                            }
                        }
                    }

                    currentDescriptorOffset += 20
                }
            }
        }

        // 7. Derive Graphics APIs from imports
        var graphicsAPIs: Set<GraphicsAPI> = []
        for dll in importedDLLs {
            if dll == "d3d9.dll" {
                graphicsAPIs.insert(.d3d9)
            } else if dll == "d3d11.dll" {
                graphicsAPIs.insert(.d3d11)
            } else if dll == "d3d12.dll" {
                graphicsAPIs.insert(.d3d12)
            } else if dll == "vulkan-1.dll" {
                graphicsAPIs.insert(.vulkan)
            } else if dll == "opengl32.dll" {
                graphicsAPIs.insert(.opengl)
            }
        }
        // If dxgi is imported without d3d11 or d3d12 explicitly, d3d11 is commonly used
        if importedDLLs.contains("dxgi.dll") && !graphicsAPIs.contains(.d3d9) && !graphicsAPIs.contains(.d3d11) && !graphicsAPIs.contains(.d3d12) {
            graphicsAPIs.insert(.d3d11)
        }

        // 8. Detect Anti-Cheat indicators
        var antiCheatIndicators: [String] = []
        let knownAntiCheatSubstrings: [(String, String)] = [
            ("easyanticheat", "EasyAntiCheat"),
            ("battleye", "BattlEye"),
            ("beclient", "BattlEye"),
            ("beservice", "BattlEye"),
            ("vgc.sys", "Riot Vanguard"),
            ("vgk.sys", "Riot Vanguard"),
            ("vanguard", "Riot Vanguard"),
            ("denuvo", "Denuvo"),
            ("gameflt", "Anti-Cheat Filter"),
            ("mhyprot", "MiHoYo Protect"),
            ("xigncode", "XIGNCODE3"),
            ("themida", "Themida Protection"),
            ("vmprotect", "VMProtect"),
            ("anticheat", "Generic Anti-Cheat")
        ]

        for dll in importedDLLs {
            for (sub, label) in knownAntiCheatSubstrings {
                if dll.contains(sub) {
                    antiCheatIndicators.append("\(label) (\(dll))")
                }
            }
        }

        // 9. Kernel Driver Indicator
        var kernelDriverIndicator: Tri = .no
        if subsystem == 1 { // 1 = IMAGE_SUBSYSTEM_NATIVE (device drivers)
            kernelDriverIndicator = .yes
        } else if importedDLLs.contains("ntoskrnl.exe") || importedDLLs.contains("hal.dll") {
            kernelDriverIndicator = .yes
        } else if (characteristics & 0x2000) != 0 && subsystem == nil {
            kernelDriverIndicator = .unknown
        }

        return RequirementFacts(
            architecture: architecture,
            isPE32Plus: isPE32Plus,
            importedDLLs: Array(importedDLLs),
            graphicsAPIs: graphicsAPIs,
            antiCheatIndicators: antiCheatIndicators,
            kernelDriverIndicator: kernelDriverIndicator,
            subsystem: subsystem,
            analyzerVersion: Self.currentAnalyzerVersion
        )
    }

    /// Parse directly from a file path.
    public func parse(fileURL: URL) throws -> RequirementFacts {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }
        let data = handle.readDataToEndOfFile()
        return try parse(data: data)
    }

    /// Parse directly from an open file descriptor.
    public func parse(fileDescriptor: Int32) throws -> RequirementFacts {
        let handle = FileHandle(fileDescriptor: fileDescriptor, closeOnDealloc: false)
        let data = handle.readDataToEndOfFile()
        return try parse(data: data)
    }
}

// MARK: - Binary Data Reading Extensions

private extension Data {
    func readUInt16(at offset: Int) -> UInt16 {
        guard offset + 2 <= count else { return 0 }
        return subdata(in: offset..<(offset + 2)).withUnsafeBytes {
            $0.loadUnaligned(as: UInt16.self).littleEndian
        }
    }

    func readUInt32(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        return subdata(in: offset..<(offset + 4)).withUnsafeBytes {
            $0.loadUnaligned(as: UInt32.self).littleEndian
        }
    }

    func readASCIIString(at offset: Int, maxLength: Int) -> String? {
        guard offset < count else { return nil }
        let endLimit = Swift.min(offset + maxLength, count)
        var stringBytes: [UInt8] = []
        for i in offset..<endLimit {
            let byte = self[i]
            if byte == 0 { break }
            stringBytes.append(byte)
        }
        guard !stringBytes.isEmpty else { return nil }
        return String(bytes: stringBytes, encoding: .ascii)
    }
}
