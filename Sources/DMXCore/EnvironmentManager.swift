import Foundation
import DMXModel

public enum EnvironmentError: Error, LocalizedError, Equatable {
    case environmentNotFound(String)
    case generationNotFound(String)
    case generationAlreadyProtected(String)
    case fileSystemError(String)

    public var errorDescription: String? {
        switch self {
        case .environmentNotFound(let id):
            return "Environment not found: \(id)"
        case .generationNotFound(let id):
            return "Generation not found: \(id)"
        case .generationAlreadyProtected(let id):
            return "Cannot mutate or delete protected generation: \(id)"
        case .fileSystemError(let detail):
            return "Filesystem error: \(detail)"
        }
    }
}

public actor EnvironmentManager {
    private let baseEnvironmentsURL: URL
    private let storage: StorageService

    public init(storage: StorageService, customBaseURL: URL? = nil) {
        self.storage = storage
        if let custom = customBaseURL {
            self.baseEnvironmentsURL = custom
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.baseEnvironmentsURL = appSupport.appendingPathComponent("DimensionX/environments")
        }
        try? FileManager.default.createDirectory(at: self.baseEnvironmentsURL, withIntermediateDirectories: true)
    }

    /// Retrieves or initializes the managed environment for an application.
    public func ensureEnvironment(for applicationID: ApplicationID, composition: RuntimeComposition) async throws -> (EnvironmentRecord, EnvironmentGeneration) {
        if let existing = try await storage.getEnvironment(for: applicationID) {
            if let activeGenID = existing.activeGenerationID,
               let gen = try await storage.getGeneration(id: activeGenID) {
                return (existing, gen)
            }
        }

        // Create new environment
        let envID = EnvironmentID()
        let envRecord = EnvironmentRecord(id: envID, applicationID: applicationID)
        try await storage.saveEnvironment(envRecord)

        // Create generation 1
        let gen = try await createGeneration(
            environmentID: envID,
            ordinal: 1,
            composition: composition
        )

        var updatedEnv = envRecord
        updatedEnv.activeGenerationID = gen.id
        try await storage.saveEnvironment(updatedEnv)

        return (updatedEnv, gen)
    }

    /// Creates a new generation (snapshot) based on the current active generation.
    public func createSnapshot(environmentID: EnvironmentID, composition: RuntimeComposition, protected: Bool = false) async throws -> EnvironmentGeneration {
        guard var env = try await storage.getEnvironment(id: environmentID) else {
            throw EnvironmentError.environmentNotFound(environmentID.raw)
        }

        let existingGens = try await storage.listGenerations(for: environmentID)
        let nextOrdinal = (existingGens.map(\.ordinal).max() ?? 0) + 1

        let newGen = try await createGeneration(
            environmentID: environmentID,
            ordinal: nextOrdinal,
            composition: composition,
            protected: protected,
            cloneFromGenerationID: env.activeGenerationID
        )

        env.activeGenerationID = newGen.id
        try await storage.saveEnvironment(env)

        return newGen
    }

    /// Rolls back the environment to a prior generation.
    public func rollback(environmentID: EnvironmentID, toGenerationID targetGenID: GenerationID) async throws -> EnvironmentRecord {
        guard var env = try await storage.getEnvironment(id: environmentID) else {
            throw EnvironmentError.environmentNotFound(environmentID.raw)
        }

        guard let targetGen = try await storage.getGeneration(id: targetGenID),
              targetGen.environmentID == environmentID else {
            throw EnvironmentError.generationNotFound(targetGenID.raw)
        }

        env.activeGenerationID = targetGenID
        try await storage.saveEnvironment(env)
        return env
    }

    /// Returns the absolute prefix path for a generation.
    public func prefixURL(for environmentID: EnvironmentID, generationID: GenerationID) -> URL {
        baseEnvironmentsURL
            .appendingPathComponent(environmentID.raw)
            .appendingPathComponent("generations")
            .appendingPathComponent(generationID.raw)
    }

    // MARK: - Internal Helpers

    private func createGeneration(
        environmentID: EnvironmentID,
        ordinal: Int,
        composition: RuntimeComposition,
        protected: Bool = false,
        cloneFromGenerationID: GenerationID? = nil
    ) async throws -> EnvironmentGeneration {
        let genID = GenerationID()
        let genDir = prefixURL(for: environmentID, generationID: genID)

        try FileManager.default.createDirectory(at: genDir, withIntermediateDirectories: true)

        var fileInventory: [String] = []

        if let sourceGenID = cloneFromGenerationID {
            let sourceDir = prefixURL(for: environmentID, generationID: sourceGenID)
            if FileManager.default.fileExists(atPath: sourceDir.path) {
                // Copy source prefix contents to new generation
                let contents = (try? FileManager.default.contentsOfDirectory(atPath: sourceDir.path)) ?? []
                for item in contents {
                    let srcItem = sourceDir.appendingPathComponent(item)
                    let dstItem = genDir.appendingPathComponent(item)
                    try? FileManager.default.copyItem(at: srcItem, to: dstItem)
                    fileInventory.append(item)
                }
            }
        } else {
            // Initialize fresh skeleton wineprefix
            let driveC = genDir.appendingPathComponent("drive_c")
            let system32 = driveC.appendingPathComponent("windows/system32")
            let programFiles = driveC.appendingPathComponent("Program Files")

            try FileManager.default.createDirectory(at: system32, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: programFiles, withIntermediateDirectories: true)

            // Write minimal Wine registry stubs
            let systemReg = genDir.appendingPathComponent("system.reg")
            let userReg = genDir.appendingPathComponent("user.reg")
            let stubReg = "WINE REGISTRY Version 2\n;; Generated by Dimension X (DMX)\n"
            try stubReg.write(to: systemReg, atomically: true, encoding: .utf8)
            try stubReg.write(to: userReg, atomically: true, encoding: .utf8)

            fileInventory = [
                "drive_c",
                "drive_c/windows",
                "drive_c/windows/system32",
                "drive_c/Program Files",
                "system.reg",
                "user.reg"
            ]
        }

        let manifest = GenerationManifest(
            id: genID,
            composition: composition,
            builtAt: Date(),
            contents: fileInventory
        )

        let generation = EnvironmentGeneration(
            id: genID,
            environmentID: environmentID,
            ordinal: ordinal,
            compositionDigest: composition.digest,
            state: .ready,
            protected: protected,
            manifest: manifest,
            createdAt: Date()
        )

        try await storage.saveGeneration(generation)
        return generation
    }
}
