import Foundation

// DMXModel/RequirementFacts.swift — FACTS ONLY. No verdicts here.

public enum PEArchitecture: String, Codable, Sendable {
    case i386
    case x8664
    case arm64
    case unknown
}

public enum Tri: String, Codable, Sendable {
    case yes
    case no
    case unknown // never collapse unknown
}

public enum GraphicsAPI: String, Codable, Sendable, Comparable {
    case d3d9
    case d3d11
    case d3d12
    case vulkan
    case opengl

    public static func < (a: Self, b: Self) -> Bool {
        a.rawValue < b.rawValue
    }
}

public struct RequirementFacts: Codable, Hashable, Sendable {
    public var architecture: PEArchitecture
    public var isPE32Plus: Tri
    public var importedDLLs: [String]           // lowercased, sorted, deduplicated
    public var graphicsAPIs: Set<GraphicsAPI>   // derived purely from imports (d3d9/d3d11/d3d12/dxgi/vulkan-1/opengl32)
    public var antiCheatIndicators: [String]    // strings matched; empty ≠ "no anti-cheat"
    public var kernelDriverIndicator: Tri       // e.g. .sys present in bundle / known service-install imports
    public var subsystem: UInt16?
    public var analyzerVersion: String

    public init(
        architecture: PEArchitecture,
        isPE32Plus: Tri,
        importedDLLs: [String],
        graphicsAPIs: Set<GraphicsAPI>,
        antiCheatIndicators: [String],
        kernelDriverIndicator: Tri,
        subsystem: UInt16? = nil,
        analyzerVersion: String
    ) {
        self.architecture = architecture
        self.isPE32Plus = isPE32Plus
        self.importedDLLs = Array(Set(importedDLLs.map { $0.lowercased() })).sorted()
        self.graphicsAPIs = graphicsAPIs
        self.antiCheatIndicators = Array(Set(antiCheatIndicators)).sorted()
        self.kernelDriverIndicator = kernelDriverIndicator
        self.subsystem = subsystem
        self.analyzerVersion = analyzerVersion
    }
}
