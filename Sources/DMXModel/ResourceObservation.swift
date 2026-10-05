import Foundation

// DMXModel/ResourceObservation.swift — transient. NO display configuration.

public enum MemoryPressure: String, Codable, Sendable {
    case normal
    case warning
    case critical
    case unknown
}

public enum ThermalState: String, Codable, Sendable {
    case nominal
    case fair
    case serious
    case critical
    case unknown
}

public enum PowerSource: String, Codable, Sendable {
    case ac
    case battery
    case unknown
}

public struct ResourceObservation: Codable, Hashable, Sendable {
    public var freeDiskBytes: UInt64
    public var memoryPressure: MemoryPressure   // .normal/.warning/.critical/.unknown
    public var thermalState: ThermalState       // mirrors ProcessInfo.ThermalState + .unknown
    public var powerSource: PowerSource         // .ac/.battery/.unknown
    public var observedAt: Date

    public init(
        freeDiskBytes: UInt64,
        memoryPressure: MemoryPressure,
        thermalState: ThermalState,
        powerSource: PowerSource,
        observedAt: Date = Date()
    ) {
        self.freeDiskBytes = freeDiskBytes
        self.memoryPressure = memoryPressure
        self.thermalState = thermalState
        self.powerSource = powerSource
        self.observedAt = observedAt
    }
}
