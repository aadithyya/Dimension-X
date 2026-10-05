import Foundation

// DMXCore/Policy/ProvisionalLimits.swift

public enum ProvisionalLimits {
    // PROVISIONAL — VALIDATION REQUIRED: Maximum allowed protocol frame size for DCP/1 (16 MB)
    public static let maxDCPFrameBytes: UInt32 = 16 * 1024 * 1024

    // PROVISIONAL — VALIDATION REQUIRED: Maximum allowed protocol frame size for WCP/1 (4 MB)
    public static let maxWCPFrameBytes: UInt32 = 4 * 1024 * 1024

    // PROVISIONAL — VALIDATION REQUIRED: Maximum allowed protocol frame size for ICP/1 (1 MB)
    public static let maxICPFrameBytes: UInt32 = 1 * 1024 * 1024

    // PROVISIONAL — VALIDATION REQUIRED: Inspector timeout before killing dmx-inspect process (10s)
    public static let inspectorTimeout: TimeInterval = 10.0

    // PROVISIONAL — VALIDATION REQUIRED: Probe execution timeout for x8664 probe (5s)
    public static let probeTimeout: TimeInterval = 5.0

    // PROVISIONAL — VALIDATION REQUIRED: Maximum time allowed for qualification boot+console test (120s)
    public static let qualificationTimeout: TimeInterval = 120.0

    // PROVISIONAL — VALIDATION REQUIRED: Maximum outbound event queue depth per connected client (1000)
    public static let maxQueuedEventsPerClient: Int = 1000

    // PROVISIONAL — VALIDATION REQUIRED: Core idle exit timeout when no active connections, operations, or sessions exist (300s)
    public static let idleTimeout: TimeInterval = 300.0
}
