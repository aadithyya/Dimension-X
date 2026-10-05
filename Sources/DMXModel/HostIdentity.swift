import Foundation

// DMXModel/HostIdentity.swift

public enum X8664Execution: String, Codable, Sendable {
    case available
    case unavailable
    case unknown
}

public struct HostIdentity: Codable, Hashable, Sendable {
    public var macOSVersion: String      // e.g. "15.1"
    public var macOSBuild: String        // e.g. "24B83"
    public var cpuArchitecture: String   // e.g. "arm64"
    public var chipFamily: String        // from sysctl machdep.cpu.brandstring, normalized
    public var metalGPUFamily: String    // highest supported MTLGPUFamily name
    public var memoryClass: String       // "8GB", "16GB", "24GB", "32GB+", "unknown"
    public var x8664Execution: X8664Execution

    public init(
        macOSVersion: String,
        macOSBuild: String,
        cpuArchitecture: String,
        chipFamily: String,
        metalGPUFamily: String,
        memoryClass: String,
        x8664Execution: X8664Execution
    ) {
        self.macOSVersion = macOSVersion
        self.macOSBuild = macOSBuild
        self.cpuArchitecture = cpuArchitecture
        self.chipFamily = chipFamily
        self.metalGPUFamily = metalGPUFamily
        self.memoryClass = memoryClass
        self.x8664Execution = x8664Execution
    }

    public var digest: String {
        CanonicalJSON.sha256Hex(of: self)
    }
}
