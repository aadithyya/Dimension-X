import Foundation
import DMXModel
import DMXProtocol

public actor DCPHandler {
    private let storage: StorageService
    private let analyzer: AnalyzerService
    private let broker: ExecutionBroker
    private let envManager: EnvironmentManager

    public init(
        storage: StorageService,
        analyzer: AnalyzerService,
        broker: ExecutionBroker,
        envManager: EnvironmentManager
    ) {
        self.storage = storage
        self.analyzer = analyzer
        self.broker = broker
        self.envManager = envManager
    }

    public func handle(request: DCPRequest) async -> DCPResponse {
        do {
            let resultPayload = try await dispatch(method: request.method, payload: request.payload)
            return DCPResponse(id: request.id, ok: true, payload: resultPayload)
        } catch {
            return DCPResponse(
                id: request.id,
                ok: false,
                error: DCPError(code: "METHOD_ERROR", message: error.localizedDescription)
            )
        }
    }

    private func dispatch(method: String, payload: JSONValue) async throws -> JSONValue {
        switch method {
        case "system.hostIdentity":
            let host = HostIdentityProbe.probe()
            let data = try JSONEncoder().encode(host)
            return try JSONDecoder().decode(JSONValue.self, from: data)

        case "system.status":
            let host = HostIdentityProbe.probe()
            let isRunning = await broker.isWorkerRunning
            return .object([
                "ready": .bool(true),
                "activeExecution": .bool(isRunning),
                "hostDigest": .string(host.digest),
                "chipFamily": .string(host.chipFamily),
                "macOSVersion": .string(host.macOSVersion)
            ])

        case "application.import":
            guard case .object(let dict) = payload,
                  case .string(let path)? = dict["path"] else {
                throw DCPError(code: "INVALID_PAYLOAD", message: "Missing required 'path' parameter")
            }

            let (facts, digest) = try await analyzer.analyze(executablePath: path)
            let name = URL(fileURLWithPath: path).lastPathComponent
            let app = ApplicationRecord(
                name: name,
                executablePath: path,
                binaryDigest: digest,
                facts: facts
            )
            try await storage.saveApplication(app)

            let appData = try JSONEncoder().encode(app)
            return try JSONDecoder().decode(JSONValue.self, from: appData)

        case "application.list":
            let apps = try await storage.listApplications()
            let data = try JSONEncoder().encode(apps)
            return try JSONDecoder().decode(JSONValue.self, from: data)

        case "application.get":
            guard case .object(let dict) = payload,
                  case .string(let idStr)? = dict["id"] else {
                throw DCPError(code: "INVALID_PAYLOAD", message: "Missing required 'id' parameter")
            }
            guard let app = try await storage.getApplication(id: ApplicationID(raw: idStr)) else {
                throw DCPError(code: "NOT_FOUND", message: "Application not found: \(idStr)")
            }
            let data = try JSONEncoder().encode(app)
            return try JSONDecoder().decode(JSONValue.self, from: data)

        case "application.delete":
            guard case .object(let dict) = payload,
                  case .string(let idStr)? = dict["id"] else {
                throw DCPError(code: "INVALID_PAYLOAD", message: "Missing required 'id' parameter")
            }
            try await storage.deleteApplication(id: ApplicationID(raw: idStr))
            return .object(["deleted": .bool(true), "id": .string(idStr)])

        case "environment.ensure":
            guard case .object(let dict) = payload,
                  case .string(let appIdStr)? = dict["applicationID"] else {
                throw DCPError(code: "INVALID_PAYLOAD", message: "Missing applicationID")
            }
            let comp: RuntimeComposition
            if let compVal = dict["composition"] {
                let compData = try JSONEncoder().encode(compVal)
                comp = try JSONDecoder().decode(RuntimeComposition.self, from: compData)
            } else {
                comp = RuntimeComposition(
                    runtimeArtifactDigest: "default-wine",
                    cpuPath: .x8664HostExecution,
                    graphicsProvider: .wined3dBundled
                )
            }

            let (env, gen) = try await envManager.ensureEnvironment(for: ApplicationID(raw: appIdStr), composition: comp)
            let envData = try JSONEncoder().encode(env)
            let genData = try JSONEncoder().encode(gen)

            return .object([
                "environment": try JSONDecoder().decode(JSONValue.self, from: envData),
                "generation": try JSONDecoder().decode(JSONValue.self, from: genData)
            ])

        case "environment.snapshot":
            guard case .object(let dict) = payload,
                  case .string(let envIdStr)? = dict["environmentID"] else {
                throw DCPError(code: "INVALID_PAYLOAD", message: "Missing environmentID")
            }
            let comp: RuntimeComposition
            if let compVal = dict["composition"] {
                let compData = try JSONEncoder().encode(compVal)
                comp = try JSONDecoder().decode(RuntimeComposition.self, from: compData)
            } else {
                comp = RuntimeComposition(
                    runtimeArtifactDigest: "default-wine",
                    cpuPath: .x8664HostExecution,
                    graphicsProvider: .wined3dBundled
                )
            }

            let protected = (dict["protected"] == .bool(true))
            let newGen = try await envManager.createSnapshot(
                environmentID: EnvironmentID(raw: envIdStr),
                composition: comp,
                protected: protected
            )
            let genData = try JSONEncoder().encode(newGen)
            return try JSONDecoder().decode(JSONValue.self, from: genData)

        case "environment.rollback":
            guard case .object(let dict) = payload,
                  case .string(let envIdStr)? = dict["environmentID"],
                  case .string(let genIdStr)? = dict["generationID"] else {
                throw DCPError(code: "INVALID_PAYLOAD", message: "Missing environmentID or generationID")
            }

            let updatedEnv = try await envManager.rollback(
                environmentID: EnvironmentID(raw: envIdStr),
                toGenerationID: GenerationID(raw: genIdStr)
            )
            let envData = try JSONEncoder().encode(updatedEnv)
            return try JSONDecoder().decode(JSONValue.self, from: envData)

        case "execution.start":
            guard case .object(let dict) = payload,
                  case .string(let appIdStr)? = dict["applicationID"] else {
                throw DCPError(code: "INVALID_PAYLOAD", message: "Missing applicationID")
            }

            let appId = ApplicationID(raw: appIdStr)
            guard let app = try await storage.getApplication(id: appId) else {
                throw DCPError(code: "APP_NOT_FOUND", message: "Application not found: \(appIdStr)")
            }

            let comp = RuntimeComposition(
                runtimeArtifactDigest: "default-wine",
                cpuPath: .x8664HostExecution,
                graphicsProvider: .wined3dBundled
            )
            let (envRecord, activeGen) = try await envManager.ensureEnvironment(for: appId, composition: comp)
            let prefixPath = await envManager.prefixURL(for: envRecord.id, generationID: activeGen.id).path

            var envVars = [
                "WINEPREFIX": prefixPath,
                "WINEDEBUG": "-all"
            ]
            if case .object(let extraEnv)? = dict["env"] {
                for (k, v) in extraEnv {
                    if case .string(let str) = v { envVars[k] = str }
                }
            }

            var args: [String] = []
            if case .array(let argsArr)? = dict["arguments"] {
                for item in argsArr {
                    if case .string(let str) = item { args.append(str) }
                }
            }

            let plan = LaunchPlan(
                applicationID: appId,
                binaryDigest: app.binaryDigest,
                binaryRelativePath: app.executablePath,
                generationID: activeGen.id,
                compositionDigest: comp.digest,
                hostIdentityDigest: HostIdentityProbe.probe().digest,
                env: envVars,
                workingDirectory: URL(fileURLWithPath: app.executablePath).deletingLastPathComponent().path,
                arguments: args
            )

            try await storage.saveLaunchPlan(plan)

            // Launch worker asynchronously in background task so request responds immediately with active state
            Task {
                do {
                    let result = try await self.broker.launch(plan: plan)
                    // Save execution outcome evidence
                    let evidence = try Evidence(
                        kind: .compatibility,
                        compositionDigest: plan.compositionDigest,
                        hostIdentityDigest: plan.hostIdentityDigest,
                        applicationID: appId,
                        applicationBinaryDigest: plan.binaryDigest,
                        generationID: plan.generationID,
                        compatibilityVerdict: result.exitCode == 0 ? .works : .fails,
                        performance: .measuredOK,
                        performanceSample: PerformanceSample(source: "dmx-worker"),
                        stability: result.exitCode == 0 ? "stable" : "exited(\(result.exitCode))",
                        notes: "Cleanup: \(result.cleanupState)"
                    )
                    try await self.storage.saveEvidence(evidence)
                } catch {
                    print("[DCPHandler] Execution failed: \(error)")
                }
            }

            return .object([
                "started": .bool(true),
                "applicationID": .string(appId.raw),
                "planDigest": .string(plan.digest)
            ])

        case "execution.stop":
            await broker.terminateWorker()
            return .object(["stopped": .bool(true)])

        case "evidence.list":
            var targetAppId: ApplicationID? = nil
            if case .object(let dict) = payload, case .string(let appIdStr)? = dict["applicationID"] {
                targetAppId = ApplicationID(raw: appIdStr)
            }
            let list = try await storage.listEvidence(forApplicationID: targetAppId)
            let data = try JSONEncoder().encode(list)
            return try JSONDecoder().decode(JSONValue.self, from: data)

        case "evidence.record":
            let evidenceData = try JSONEncoder().encode(payload)
            let evidence = try JSONDecoder().decode(Evidence.self, from: evidenceData)
            try await storage.saveEvidence(evidence)
            return .object(["recorded": .bool(true), "id": .string(evidence.id)])

        default:
            throw DCPError(code: "UNKNOWN_METHOD", message: "Method '\(method)' is not recognized")
        }
    }
}
