import Foundation
import CryptoKit
import DMXModel
import DMXProtocol
import DMXInspectKit

public enum AnalyzerError: Error, LocalizedError, Equatable {
    case fileNotFound(String)
    case unreadableFile(String)
    case spawnFailed(String)
    case protocolError(String)
    case timeout
    case inspectionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "Binary file not found at path: \(path)"
        case .unreadableFile(let path):
            return "Unable to open binary file for reading: \(path)"
        case .spawnFailed(let detail):
            return "Failed to spawn dmx-inspect worker: \(detail)"
        case .protocolError(let detail):
            return "ICP protocol communication error: \(detail)"
        case .timeout:
            return "dmx-inspect process timed out after \(ProvisionalLimits.inspectorTimeout)s"
        case .inspectionFailed(let reason):
            return "Inspection failed: \(reason)"
        }
    }
}

public actor AnalyzerService {
    private let inspectBinaryPath: String?

    public init(inspectBinaryPath: String? = nil) {
        self.inspectBinaryPath = inspectBinaryPath
    }

    /// Analyzes the PE executable at the given path, returning RequirementFacts and SHA-256 binary digest.
    public func analyze(executablePath: String) async throws -> (facts: RequirementFacts, binaryDigest: String) {
        guard FileManager.default.fileExists(atPath: executablePath) else {
            throw AnalyzerError.fileNotFound(executablePath)
        }

        // Calculate binary SHA-256 digest
        let binaryURL = URL(fileURLWithPath: executablePath)
        let fileHandle: FileHandle
        do {
            fileHandle = try FileHandle(forReadingFrom: binaryURL)
        } catch {
            throw AnalyzerError.unreadableFile(executablePath)
        }

        let binaryDigest = calculateSHA256(of: fileHandle)

        // Try spawning dmx-inspect via socketpair (fd 3) and read-only target binary (fd 4)
        if let inspectorPath = resolveInspectorBinaryPath() {
            do {
                let facts = try await runExternalInspector(
                    inspectorPath: inspectorPath,
                    targetPath: executablePath
                )
                return (facts, binaryDigest)
            } catch {
                // If external disposable inspector encountered an issue, fallback to embedded PEParser
                print("[AnalyzerService] Warning: External dmx-inspect failed (\(error)), falling back to in-process parser")
            }
        }

        // In-process fallback using DMXInspectKit PEParser
        do {
            let facts = try PEParser().parse(fileURL: binaryURL)
            return (facts, binaryDigest)
        } catch {
            throw AnalyzerError.inspectionFailed(error.localizedDescription)
        }
    }

    private func resolveInspectorBinaryPath() -> String? {
        if let explicit = inspectBinaryPath, FileManager.default.isExecutableFile(atPath: explicit) {
            return explicit
        }

        // Check common build artifact locations
        let bundleURL = Bundle.main.bundleURL.deletingLastPathComponent()
        let candidate1 = bundleURL.appendingPathComponent("dmx-inspect").path
        if FileManager.default.isExecutableFile(atPath: candidate1) {
            return candidate1
        }

        let debugPath = ".build/debug/dmx-inspect"
        if FileManager.default.isExecutableFile(atPath: debugPath) {
            return URL(fileURLWithPath: debugPath).standardized.path
        }

        let releasePath = ".build/release/dmx-inspect"
        if FileManager.default.isExecutableFile(atPath: releasePath) {
            return URL(fileURLWithPath: releasePath).standardized.path
        }

        return nil
    }

    private func runExternalInspector(inspectorPath: String, targetPath: String) async throws -> RequirementFacts {
        var fds: [Int32] = [0, 0]
        guard socketpair(AF_UNIX, SOCK_STREAM, 0, &fds) == 0 else {
            throw AnalyzerError.spawnFailed("socketpair creation failed: \(errno)")
        }

        let parentSocketFd = fds[0]
        let childSocketFd = fds[1]

        let targetPeFd = open(targetPath, O_RDONLY)
        guard targetPeFd >= 0 else {
            close(parentSocketFd)
            close(childSocketFd)
            throw AnalyzerError.unreadableFile(targetPath)
        }

        var fileActions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&fileActions)
        defer { posix_spawn_file_actions_destroy(&fileActions) }

        // Map childSocketFd -> fd 3
        posix_spawn_file_actions_adddup2(&fileActions, childSocketFd, 3)
        // Map targetPeFd -> fd 4
        posix_spawn_file_actions_adddup2(&fileActions, targetPeFd, 4)

        // Close redundant descriptors in child
        posix_spawn_file_actions_addclose(&fileActions, parentSocketFd)
        posix_spawn_file_actions_addclose(&fileActions, childSocketFd)
        posix_spawn_file_actions_addclose(&fileActions, targetPeFd)

        var pid: pid_t = 0
        let argv: [UnsafeMutablePointer<CChar>?] = [
            strdup(inspectorPath),
            nil
        ]
        defer {
            for ptr in argv where ptr != nil { free(ptr) }
        }

        let spawnResult = posix_spawn(&pid, inspectorPath, &fileActions, nil, argv, nil)
        // Parent closes child ends
        close(childSocketFd)
        close(targetPeFd)

        guard spawnResult == 0 else {
            close(parentSocketFd)
            throw AnalyzerError.spawnFailed("posix_spawn error code \(spawnResult)")
        }

        let parentHandle = FileHandle(fileDescriptor: parentSocketFd, closeOnDealloc: true)
        let codec = FrameCodec(maxFrameBytes: ProvisionalLimits.maxICPFrameBytes)

        // Send ICP.Request over socketpair
        let request = ICP.Request(version: 1, targetPath: targetPath)
        let reqData = try JSONEncoder().encode(request)
        let frame = try codec.encode(payload: reqData)
        try parentHandle.write(contentsOf: frame)

        // Read response with timeout
        return try await withThrowingTaskGroup(of: RequirementFacts.self) { group in
            group.addTask {
                var decoder = FrameCodec.Decoder(maxFrameBytes: ProvisionalLimits.maxICPFrameBytes)
                while true {
                    try Task.checkCancellation()
                    let chunk = parentHandle.availableData
                    if chunk.isEmpty {
                        throw AnalyzerError.protocolError("Unexpected EOF while awaiting ICP response")
                    }
                    decoder.feed(data: chunk)
                    if let respFrame = try decoder.next() {
                        let resp = try JSONDecoder().decode(ICP.Response.self, from: respFrame)
                        if resp.ok, let facts = resp.facts {
                            return facts
                        } else {
                            throw AnalyzerError.inspectionFailed(resp.error?.message ?? "Unknown inspection error")
                        }
                    }
                }
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(ProvisionalLimits.inspectorTimeout * 1_000_000_000))
                throw AnalyzerError.timeout
            }

            let result = try await group.next()!
            group.cancelAll()

            // Ensure inspector process is reaped
            var status: Int32 = 0
            waitpid(pid, &status, WNOHANG)

            return result
        }
    }

    private func calculateSHA256(of handle: FileHandle) -> String {
        defer { try? handle.seek(toOffset: 0) }
        var hasher = SHA256()
        try? handle.seek(toOffset: 0)
        while true {
            let chunk = handle.readData(ofLength: 64 * 1024)
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
