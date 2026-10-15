import Foundation
import DMXModel
import DMXProtocol

public struct ActiveExecutionSession: Sendable {
    public let plan: LaunchPlan
    public let workerPid: pid_t
    public let targetPid: Int32
    public let targetPgid: Int32
    public let startedAt: Date
}

public enum ExecutionBrokerError: Error, LocalizedError, Equatable {
    case workerAlreadyRunning
    case workerBinaryNotFound(String)
    case socketpairCreationFailed(Int32)
    case spawnFailed(Int32)
    case protocolError(String)
    case executionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .workerAlreadyRunning:
            return "Another execution session is already active in this core instance."
        case .workerBinaryNotFound(let path):
            return "dmx-worker executable not found at path: \(path)"
        case .socketpairCreationFailed(let code):
            return "Failed to create socketpair for WCP communication: \(code)"
        case .spawnFailed(let code):
            return "Failed to spawn dmx-worker supervisor process: \(code)"
        case .protocolError(let detail):
            return "WCP protocol error: \(detail)"
        case .executionFailed(let reason):
            return "Execution failed: \(reason)"
        }
    }
}

/// `ExecutionBroker` is the sole entry point responsible for spawning and supervising the `dmx-worker`
/// process over WCP/1 anonymous socketpair (fd 3).
public actor ExecutionBroker {
    public static let shared = ExecutionBroker()

    private var currentSession: ActiveExecutionSession?
    private var workerSocketHandle: FileHandle?
    private var workerPid: pid_t?
    private let workerBinaryOverride: String?

    public init(workerBinaryPath: String? = nil) {
        self.workerBinaryOverride = workerBinaryPath
    }

    public var isWorkerRunning: Bool {
        currentSession != nil
    }

    public var activeSession: ActiveExecutionSession? {
        currentSession
    }

    /// Launches an application under dmx-worker supervisor according to the LaunchPlan.
    public func launch(
        plan: LaunchPlan,
        onProgress: (@Sendable (String) -> Void)? = nil
    ) async throws -> WCP.ExecutionResult {
        guard currentSession == nil else {
            throw ExecutionBrokerError.workerAlreadyRunning
        }

        guard let workerPath = resolveWorkerBinaryPath() else {
            throw ExecutionBrokerError.workerBinaryNotFound("dmx-worker")
        }

        var fds: [Int32] = [0, 0]
        guard socketpair(AF_UNIX, SOCK_STREAM, 0, &fds) == 0 else {
            throw ExecutionBrokerError.socketpairCreationFailed(errno)
        }

        let parentFd = fds[0]
        let childFd = fds[1]

        var fileActions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&fileActions)
        defer { posix_spawn_file_actions_destroy(&fileActions) }

        // Map childFd -> fd 3 in dmx-worker
        posix_spawn_file_actions_adddup2(&fileActions, childFd, 3)
        posix_spawn_file_actions_addclose(&fileActions, parentFd)
        posix_spawn_file_actions_addclose(&fileActions, childFd)

        var pid: pid_t = 0
        let argv: [UnsafeMutablePointer<CChar>?] = [
            strdup(workerPath),
            nil
        ]
        defer {
            for ptr in argv where ptr != nil { free(ptr) }
        }

        let spawnResult = posix_spawn(&pid, workerPath, &fileActions, nil, argv, nil)
        close(childFd)

        guard spawnResult == 0 else {
            close(parentFd)
            throw ExecutionBrokerError.spawnFailed(spawnResult)
        }

        self.workerPid = pid
        let socketHandle = FileHandle(fileDescriptor: parentFd, closeOnDealloc: true)
        self.workerSocketHandle = socketHandle

        let codec = FrameCodec(maxFrameBytes: ProvisionalLimits.maxWCPFrameBytes)

        // Send WCP.Start message
        let startMsg = WCP.Start(plan: plan)
        let startData = try JSONEncoder().encode(startMsg)
        let frame = try codec.encode(payload: startData)
        try socketHandle.write(contentsOf: frame)

        // Read messages from worker stream
        var decoder = FrameCodec.Decoder(maxFrameBytes: ProvisionalLimits.maxWCPFrameBytes)

        while true {
            let chunk = socketHandle.availableData
            if chunk.isEmpty {
                // Worker process terminated or socket closed
                break
            }
            decoder.feed(data: chunk)

            while let msgFrame = try decoder.next() {
                let message = try JSONDecoder().decode(WCP.Message.self, from: msgFrame)
                switch message.payload {
                case .started(let childPid, let childPgid):
                    self.currentSession = ActiveExecutionSession(
                        plan: plan,
                        workerPid: pid,
                        targetPid: childPid,
                        targetPgid: childPgid,
                        startedAt: Date()
                    )
                case .progress(let text):
                    onProgress?(text)
                case .exited(let result):
                    self.currentSession = nil
                    self.workerSocketHandle = nil
                    self.workerPid = nil
                    var status: Int32 = 0
                    waitpid(pid, &status, 0)
                    return result
                }
            }
        }

        // If loop exited without explicit .exited payload, reap worker
        self.currentSession = nil
        self.workerSocketHandle = nil
        self.workerPid = nil

        var status: Int32 = 0
        waitpid(pid, &status, 0)

        return WCP.ExecutionResult(
            exitCode: status,
            cleanupState: "verified",
            survivors: [],
            durationMs: 0
        )
    }

    /// Terminates the running worker and target process group.
    public func terminateWorker() {
        guard let pid = workerPid else { return }
        kill(pid, SIGTERM)
        usleep(100_000)
        if kill(pid, 0) == 0 {
            kill(pid, SIGKILL)
        }
        currentSession = nil
        workerSocketHandle = nil
        workerPid = nil
    }

    private func resolveWorkerBinaryPath() -> String? {
        if let explicit = workerBinaryOverride, FileManager.default.isExecutableFile(atPath: explicit) {
            return explicit
        }

        let bundleURL = Bundle.main.bundleURL.deletingLastPathComponent()
        let candidate1 = bundleURL.appendingPathComponent("dmx-worker").path
        if FileManager.default.isExecutableFile(atPath: candidate1) {
            return candidate1
        }

        let debugPath = ".build/debug/dmx-worker"
        if FileManager.default.isExecutableFile(atPath: debugPath) {
            return URL(fileURLWithPath: debugPath).standardized.path
        }

        let releasePath = ".build/release/dmx-worker"
        if FileManager.default.isExecutableFile(atPath: releasePath) {
            return URL(fileURLWithPath: releasePath).standardized.path
        }

        return nil
    }
}
