import Foundation

// DMXModel/RuntimeComposition.swift — exact, immutable tuple

public enum CPUExecutionPath: String, Codable, Sendable {
    case x8664HostExecution
}

public enum GraphicsProviderKind: String, Codable, Sendable {
    case wined3dBundled
    case dxmt
    case dxvkMoltenVK
    case d3dmetalUserImported
}

public struct RuntimeComposition: Codable, Hashable, Sendable {
    public let runtimeArtifactDigest: String             // Wine runtime (content-addressed)
    public let cpuPath: CPUExecutionPath
    public let graphicsProvider: GraphicsProviderKind
    public let graphicsArtifactDigest: String?           // nil for bundled wined3d
    public let dependencyRecipeDigests: [String]         // sorted
    public let configuration: [String: String]           // canonicalized by sorted keys

    public init(
        runtimeArtifactDigest: String,
        cpuPath: CPUExecutionPath,
        graphicsProvider: GraphicsProviderKind,
        graphicsArtifactDigest: String? = nil,
        dependencyRecipeDigests: [String] = [],
        configuration: [String: String] = [:]
    ) {
        self.runtimeArtifactDigest = runtimeArtifactDigest
        self.cpuPath = cpuPath
        self.graphicsProvider = graphicsProvider
        self.graphicsArtifactDigest = graphicsArtifactDigest
        self.dependencyRecipeDigests = dependencyRecipeDigests.sorted()
        self.configuration = configuration
    }

    public var digest: String {
        CanonicalJSON.sha256Hex(of: self)
    }
}
