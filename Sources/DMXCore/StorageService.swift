import Foundation
import GRDB
import DMXModel

public struct ApplicationRecord: Codable, Hashable, Sendable {
    public let id: ApplicationID
    public let name: String
    public let executablePath: String
    public let binaryDigest: String
    public let importedAt: Date
    public let facts: RequirementFacts

    public init(
        id: ApplicationID = ApplicationID(),
        name: String,
        executablePath: String,
        binaryDigest: String,
        importedAt: Date = Date(),
        facts: RequirementFacts
    ) {
        self.id = id
        self.name = name
        self.executablePath = executablePath
        self.binaryDigest = binaryDigest
        self.importedAt = importedAt
        self.facts = facts
    }
}

public actor StorageService {
    private let dbQueue: DatabaseQueue

    public init(databaseURL: URL) throws {
        // Ensure parent directory exists
        let dir = databaseURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        var config = Configuration()
        config.qos = .userInitiated
        self.dbQueue = try DatabaseQueue(path: databaseURL.path, configuration: config)
        try Self.createTables(in: self.dbQueue)
    }

    public init(inMemory: Bool = false) throws {
        var config = Configuration()
        config.qos = .userInitiated
        if inMemory {
            self.dbQueue = try DatabaseQueue(configuration: config)
        } else {
            let defaultDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("DimensionX")
            try FileManager.default.createDirectory(at: defaultDir, withIntermediateDirectories: true)
            let path = defaultDir.appendingPathComponent("dmx_storage.sqlite").path
            self.dbQueue = try DatabaseQueue(path: path, configuration: config)
        }
        try Self.createTables(in: self.dbQueue)
    }

    private static func createTables(in dbQueue: DatabaseQueue) throws {
        try dbQueue.write { db in
            try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS applications (
                id TEXT PRIMARY KEY NOT NULL,
                name TEXT NOT NULL,
                executablePath TEXT NOT NULL,
                binaryDigest TEXT NOT NULL,
                importedAt TEXT NOT NULL,
                factsJSON TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS artifacts (
                digest TEXT PRIMARY KEY NOT NULL,
                kind TEXT NOT NULL,
                state TEXT NOT NULL,
                manifestJSON TEXT,
                rejectionReason TEXT,
                importedAt TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS environments (
                id TEXT PRIMARY KEY NOT NULL,
                applicationID TEXT NOT NULL,
                activeGenerationID TEXT
            );

            CREATE TABLE IF NOT EXISTS generations (
                id TEXT PRIMARY KEY NOT NULL,
                environmentID TEXT NOT NULL,
                ordinal INTEGER NOT NULL,
                compositionDigest TEXT NOT NULL,
                state TEXT NOT NULL,
                protected INTEGER NOT NULL,
                manifestJSON TEXT,
                createdAt TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS evidence (
                id TEXT PRIMARY KEY NOT NULL,
                kind TEXT NOT NULL,
                compositionDigest TEXT NOT NULL,
                hostIdentityDigest TEXT NOT NULL,
                observedAt TEXT NOT NULL,
                qualificationTest TEXT,
                qualificationVerdict TEXT,
                applicationID TEXT,
                applicationBinaryDigest TEXT,
                generationID TEXT,
                scenario TEXT,
                compatibilityVerdict TEXT,
                performance TEXT,
                performanceSampleJSON TEXT,
                stability TEXT,
                notes TEXT
            );

            CREATE TABLE IF NOT EXISTS launch_plans (
                digest TEXT PRIMARY KEY NOT NULL,
                applicationID TEXT NOT NULL,
                binaryDigest TEXT NOT NULL,
                binaryRelativePath TEXT NOT NULL,
                generationID TEXT NOT NULL,
                compositionDigest TEXT NOT NULL,
                hostIdentityDigest TEXT NOT NULL,
                envJSON TEXT NOT NULL,
                workingDirectory TEXT NOT NULL,
                argumentsJSON TEXT NOT NULL
            );
            """)
        }
    }

    // MARK: - Application Operations

    public func saveApplication(_ app: ApplicationRecord) throws {
        let factsData = try JSONEncoder().encode(app.facts)
        let factsJSON = String(data: factsData, encoding: .utf8) ?? "{}"
        let dateStr = ISO8601DateFormatter().string(from: app.importedAt)

        try dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO applications (id, name, executablePath, binaryDigest, importedAt, factsJSON)
                VALUES (?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    name=excluded.name,
                    executablePath=excluded.executablePath,
                    binaryDigest=excluded.binaryDigest,
                    importedAt=excluded.importedAt,
                    factsJSON=excluded.factsJSON
                """,
                arguments: [app.id.raw, app.name, app.executablePath, app.binaryDigest, dateStr, factsJSON]
            )
        }
    }

    public func getApplication(id: ApplicationID) throws -> ApplicationRecord? {
        try dbQueue.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM applications WHERE id = ?", arguments: [id.raw]) else {
                return nil
            }
            return try parseApplicationRow(row)
        }
    }

    public func listApplications() throws -> [ApplicationRecord] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM applications ORDER BY importedAt DESC")
            return try rows.map { try parseApplicationRow($0) }
        }
    }

    public func deleteApplication(id: ApplicationID) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM applications WHERE id = ?", arguments: [id.raw])
            try db.execute(sql: "DELETE FROM environments WHERE applicationID = ?", arguments: [id.raw])
        }
    }

    private func parseApplicationRow(_ row: Row) throws -> ApplicationRecord {
        let idRaw: String = row["id"]
        let name: String = row["name"]
        let path: String = row["executablePath"]
        let digest: String = row["binaryDigest"]
        let dateStr: String = row["importedAt"]
        let factsJSON: String = row["factsJSON"]

        let importedAt = ISO8601DateFormatter().date(from: dateStr) ?? Date()
        let factsData = Data(factsJSON.utf8)
        let facts = try JSONDecoder().decode(RequirementFacts.self, from: factsData)

        return ApplicationRecord(
            id: ApplicationID(raw: idRaw),
            name: name,
            executablePath: path,
            binaryDigest: digest,
            importedAt: importedAt,
            facts: facts
        )
    }

    // MARK: - Artifact Operations

    public func saveArtifact(_ artifact: ArtifactRecord) throws {
        let manifestJSON: String?
        if let manifest = artifact.manifest {
            let data = try JSONEncoder().encode(manifest)
            manifestJSON = String(data: data, encoding: .utf8)
        } else {
            manifestJSON = nil
        }
        let dateStr = ISO8601DateFormatter().string(from: artifact.importedAt)

        try dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO artifacts (digest, kind, state, manifestJSON, rejectionReason, importedAt)
                VALUES (?, ?, ?, ?, ?, ?)
                ON CONFLICT(digest) DO UPDATE SET
                    kind=excluded.kind,
                    state=excluded.state,
                    manifestJSON=excluded.manifestJSON,
                    rejectionReason=excluded.rejectionReason,
                    importedAt=excluded.importedAt
                """,
                arguments: [artifact.digest, artifact.kind.rawValue, artifact.state.rawValue, manifestJSON, artifact.rejectionReason, dateStr]
            )
        }
    }

    public func getArtifact(digest: String) throws -> ArtifactRecord? {
        try dbQueue.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM artifacts WHERE digest = ?", arguments: [digest]) else {
                return nil
            }
            return try parseArtifactRow(row)
        }
    }

    public func listArtifacts() throws -> [ArtifactRecord] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM artifacts ORDER BY importedAt DESC")
            return try rows.map { try parseArtifactRow($0) }
        }
    }

    private func parseArtifactRow(_ row: Row) throws -> ArtifactRecord {
        let digest: String = row["digest"]
        let kindStr: String = row["kind"]
        let stateStr: String = row["state"]
        let manifestJSON: String? = row["manifestJSON"]
        let rejection: String? = row["rejectionReason"]
        let dateStr: String = row["importedAt"]

        let kind = ArtifactKind(rawValue: kindStr) ?? .runtime
        let state = ArtifactState(rawValue: stateStr) ?? .imported
        let importedAt = ISO8601DateFormatter().date(from: dateStr) ?? Date()

        var manifest: ArtifactManifest? = nil
        if let mJson = manifestJSON, let data = mJson.data(using: .utf8) {
            manifest = try? JSONDecoder().decode(ArtifactManifest.self, from: data)
        }

        return ArtifactRecord(
            digest: digest,
            kind: kind,
            state: state,
            manifest: manifest,
            rejectionReason: rejection,
            importedAt: importedAt
        )
    }

    // MARK: - Environment & Generation Operations

    public func saveEnvironment(_ env: EnvironmentRecord) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO environments (id, applicationID, activeGenerationID)
                VALUES (?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    applicationID=excluded.applicationID,
                    activeGenerationID=excluded.activeGenerationID
                """,
                arguments: [env.id.raw, env.applicationID.raw, env.activeGenerationID?.raw]
            )
        }
    }

    public func getEnvironment(id: EnvironmentID) throws -> EnvironmentRecord? {
        try dbQueue.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM environments WHERE id = ?", arguments: [id.raw]) else {
                return nil
            }
            let envId: String = row["id"]
            let appId: String = row["applicationID"]
            let genId: String? = row["activeGenerationID"]
            return EnvironmentRecord(
                id: EnvironmentID(raw: envId),
                applicationID: ApplicationID(raw: appId),
                activeGenerationID: genId != nil ? GenerationID(raw: genId!) : nil
            )
        }
    }

    public func getEnvironment(for applicationID: ApplicationID) throws -> EnvironmentRecord? {
        try dbQueue.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM environments WHERE applicationID = ?", arguments: [applicationID.raw]) else {
                return nil
            }
            let envId: String = row["id"]
            let appId: String = row["applicationID"]
            let genId: String? = row["activeGenerationID"]
            return EnvironmentRecord(
                id: EnvironmentID(raw: envId),
                applicationID: ApplicationID(raw: appId),
                activeGenerationID: genId != nil ? GenerationID(raw: genId!) : nil
            )
        }
    }

    public func saveGeneration(_ gen: EnvironmentGeneration) throws {
        let manifestJSON: String?
        if let manifest = gen.manifest {
            let data = try JSONEncoder().encode(manifest)
            manifestJSON = String(data: data, encoding: .utf8)
        } else {
            manifestJSON = nil
        }
        let dateStr = ISO8601DateFormatter().string(from: gen.createdAt)

        try dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO generations (id, environmentID, ordinal, compositionDigest, state, protected, manifestJSON, createdAt)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    environmentID=excluded.environmentID,
                    ordinal=excluded.ordinal,
                    compositionDigest=excluded.compositionDigest,
                    state=excluded.state,
                    protected=excluded.protected,
                    manifestJSON=excluded.manifestJSON,
                    createdAt=excluded.createdAt
                """,
                arguments: [gen.id.raw, gen.environmentID.raw, gen.ordinal, gen.compositionDigest, gen.state.rawValue, gen.protected ? 1 : 0, manifestJSON, dateStr]
            )
        }
    }

    public func getGeneration(id: GenerationID) throws -> EnvironmentGeneration? {
        try dbQueue.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM generations WHERE id = ?", arguments: [id.raw]) else {
                return nil
            }
            return try parseGenerationRow(row)
        }
    }

    public func listGenerations(for environmentID: EnvironmentID) throws -> [EnvironmentGeneration] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM generations WHERE environmentID = ? ORDER BY ordinal ASC", arguments: [environmentID.raw])
            return try rows.map { try parseGenerationRow($0) }
        }
    }

    private func parseGenerationRow(_ row: Row) throws -> EnvironmentGeneration {
        let idRaw: String = row["id"]
        let envRaw: String = row["environmentID"]
        let ordinal: Int = row["ordinal"]
        let compDigest: String = row["compositionDigest"]
        let stateStr: String = row["state"]
        let protectedInt: Int = row["protected"]
        let manifestJSON: String? = row["manifestJSON"]
        let dateStr: String = row["createdAt"]

        let state = GenerationState(rawValue: stateStr) ?? .ready
        let createdAt = ISO8601DateFormatter().date(from: dateStr) ?? Date()

        var manifest: GenerationManifest? = nil
        if let mJson = manifestJSON, let data = mJson.data(using: .utf8) {
            manifest = try? JSONDecoder().decode(GenerationManifest.self, from: data)
        }

        return EnvironmentGeneration(
            id: GenerationID(raw: idRaw),
            environmentID: EnvironmentID(raw: envRaw),
            ordinal: ordinal,
            compositionDigest: compDigest,
            state: state,
            protected: protectedInt == 1,
            manifest: manifest,
            createdAt: createdAt
        )
    }

    // MARK: - Evidence Operations

    public func saveEvidence(_ evidence: Evidence) throws {
        let sampleJSON: String?
        if let sample = evidence.performanceSample {
            let data = try JSONEncoder().encode(sample)
            sampleJSON = String(data: data, encoding: .utf8)
        } else {
            sampleJSON = nil
        }
        let dateStr = ISO8601DateFormatter().string(from: evidence.observedAt)

        try dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO evidence (
                    id, kind, compositionDigest, hostIdentityDigest, observedAt,
                    qualificationTest, qualificationVerdict, applicationID, applicationBinaryDigest,
                    generationID, scenario, compatibilityVerdict, performance,
                    performanceSampleJSON, stability, notes
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    kind=excluded.kind,
                    compositionDigest=excluded.compositionDigest,
                    hostIdentityDigest=excluded.hostIdentityDigest,
                    observedAt=excluded.observedAt,
                    qualificationTest=excluded.qualificationTest,
                    qualificationVerdict=excluded.qualificationVerdict,
                    applicationID=excluded.applicationID,
                    applicationBinaryDigest=excluded.applicationBinaryDigest,
                    generationID=excluded.generationID,
                    scenario=excluded.scenario,
                    compatibilityVerdict=excluded.compatibilityVerdict,
                    performance=excluded.performance,
                    performanceSampleJSON=excluded.performanceSampleJSON,
                    stability=excluded.stability,
                    notes=excluded.notes
                """,
                arguments: [
                    evidence.id,
                    evidence.kind.rawValue,
                    evidence.compositionDigest,
                    evidence.hostIdentityDigest,
                    dateStr,
                    evidence.qualificationTest,
                    evidence.qualificationVerdict?.rawValue,
                    evidence.applicationID?.raw,
                    evidence.applicationBinaryDigest,
                    evidence.generationID?.raw,
                    evidence.scenario,
                    evidence.compatibilityVerdict?.rawValue,
                    evidence.performance?.rawValue,
                    sampleJSON,
                    evidence.stability,
                    evidence.notes
                ]
            )
        }
    }

    public func listEvidence(forApplicationID appID: ApplicationID? = nil, compositionDigest: String? = nil) throws -> [Evidence] {
        try dbQueue.read { db in
            var sql = "SELECT * FROM evidence WHERE 1=1"
            var args: [DatabaseValueConvertible] = []

            if let appID = appID {
                sql += " AND applicationID = ?"
                args.append(appID.raw)
            }
            if let comp = compositionDigest {
                sql += " AND compositionDigest = ?"
                args.append(comp)
            }
            sql += " ORDER BY observedAt DESC"

            let rows = try Row.fetchAll(db, sql: sql, arguments: StatementArguments(args))
            return try rows.compactMap { try parseEvidenceRow($0) }
        }
    }

    private func parseEvidenceRow(_ row: Row) throws -> Evidence? {
        let id: String = row["id"]
        let kindStr: String = row["kind"]
        let compDigest: String = row["compositionDigest"]
        let hostDigest: String = row["hostIdentityDigest"]
        let dateStr: String = row["observedAt"]
        let qualTest: String? = row["qualificationTest"]
        let qualVerdictStr: String? = row["qualificationVerdict"]
        let appIdRaw: String? = row["applicationID"]
        let binDigest: String? = row["applicationBinaryDigest"]
        let genIdRaw: String? = row["generationID"]
        let scenario: String? = row["scenario"]
        let compVerdictStr: String? = row["compatibilityVerdict"]
        let perfStr: String? = row["performance"]
        let sampleJSON: String? = row["performanceSampleJSON"]
        let stability: String? = row["stability"]
        let notes: String? = row["notes"]

        guard let kind = EvidenceKind(rawValue: kindStr) else { return nil }
        let observedAt = ISO8601DateFormatter().date(from: dateStr) ?? Date()

        let qualVerdict = qualVerdictStr != nil ? QualificationVerdict(rawValue: qualVerdictStr!) : nil
        let compVerdict = compVerdictStr != nil ? CompatibilityVerdict(rawValue: compVerdictStr!) : nil
        let perf = perfStr != nil ? PerformanceClass(rawValue: perfStr!) : nil

        var sample: PerformanceSample? = nil
        if let sJson = sampleJSON, let data = sJson.data(using: .utf8) {
            sample = try? JSONDecoder().decode(PerformanceSample.self, from: data)
        }

        return try Evidence(
            id: id,
            kind: kind,
            compositionDigest: compDigest,
            hostIdentityDigest: hostDigest,
            observedAt: observedAt,
            qualificationTest: qualTest,
            qualificationVerdict: qualVerdict,
            applicationID: appIdRaw != nil ? ApplicationID(raw: appIdRaw!) : nil,
            applicationBinaryDigest: binDigest,
            generationID: genIdRaw != nil ? GenerationID(raw: genIdRaw!) : nil,
            scenario: scenario,
            compatibilityVerdict: compVerdict,
            performance: perf,
            performanceSample: sample,
            stability: stability,
            notes: notes
        )
    }

    // MARK: - LaunchPlan Operations

    public func saveLaunchPlan(_ plan: LaunchPlan) throws {
        let envData = try JSONEncoder().encode(plan.env)
        let envJSON = String(data: envData, encoding: .utf8) ?? "{}"
        let argsData = try JSONEncoder().encode(plan.arguments)
        let argsJSON = String(data: argsData, encoding: .utf8) ?? "[]"

        try dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO launch_plans (
                    digest, applicationID, binaryDigest, binaryRelativePath,
                    generationID, compositionDigest, hostIdentityDigest,
                    envJSON, workingDirectory, argumentsJSON
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(digest) DO UPDATE SET
                    applicationID=excluded.applicationID,
                    binaryDigest=excluded.binaryDigest,
                    binaryRelativePath=excluded.binaryRelativePath,
                    generationID=excluded.generationID,
                    compositionDigest=excluded.compositionDigest,
                    hostIdentityDigest=excluded.hostIdentityDigest,
                    envJSON=excluded.envJSON,
                    workingDirectory=excluded.workingDirectory,
                    argumentsJSON=excluded.argumentsJSON
                """,
                arguments: [
                    plan.digest,
                    plan.applicationID.raw,
                    plan.binaryDigest,
                    plan.binaryRelativePath,
                    plan.generationID.raw,
                    plan.compositionDigest,
                    plan.hostIdentityDigest,
                    envJSON,
                    plan.workingDirectory,
                    argsJSON
                ]
            )
        }
    }

    public func getLaunchPlan(digest: String) throws -> LaunchPlan? {
        try dbQueue.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM launch_plans WHERE digest = ?", arguments: [digest]) else {
                return nil
            }
            let appIdRaw: String = row["applicationID"]
            let binDigest: String = row["binaryDigest"]
            let relPath: String = row["binaryRelativePath"]
            let genIdRaw: String = row["generationID"]
            let compDigest: String = row["compositionDigest"]
            let hostDigest: String = row["hostIdentityDigest"]
            let envJSON: String = row["envJSON"]
            let workDir: String = row["workingDirectory"]
            let argsJSON: String = row["argumentsJSON"]

            let env = (try? JSONDecoder().decode([String: String].self, from: Data(envJSON.utf8))) ?? [:]
            let args = (try? JSONDecoder().decode([String].self, from: Data(argsJSON.utf8))) ?? []

            return LaunchPlan(
                applicationID: ApplicationID(raw: appIdRaw),
                binaryDigest: binDigest,
                binaryRelativePath: relPath,
                generationID: GenerationID(raw: genIdRaw),
                compositionDigest: compDigest,
                hostIdentityDigest: hostDigest,
                env: env,
                workingDirectory: workDir,
                arguments: args
            )
        }
    }
}
