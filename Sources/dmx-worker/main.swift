import Foundation
import DMXModel
import DMXProtocol

@main
struct DMXWorkerMain {
    static func main() {
        // fd 3 is the anonymous socketpair to dmx-core
        let socketFd: Int32 = 3
        let socketHandle = FileHandle(fileDescriptor: socketFd, closeOnDealloc: false)
        let codec = FrameCodec(maxFrameBytes: 4 * 1024 * 1024) // 4 MB limit per ProvisionalLimits

        // Ensure worker runs in its own process group for isolated signal and cleanup tracking
        setpgid(0, 0)
        let myPgid = getpgrp()

        var decoder = FrameCodec.Decoder(maxFrameBytes: 4 * 1024 * 1024)
        var receivedPayload: Data? = nil

        // Read WCP.Start from fd 3
        while receivedPayload == nil {
            let chunk = socketHandle.availableData
            if chunk.isEmpty {
                // Socket closed without WCP.Start
                exit(1)
            }
            decoder.feed(data: chunk)
            do {
                if let frame = try decoder.next() {
                    receivedPayload = frame
                    break
                }
            } catch {
                exit(1)
            }
        }

        guard let payload = receivedPayload else {
            exit(1)
        }

        let startMsg: WCP.Start
        do {
            startMsg = try JSONDecoder().decode(WCP.Start.self, from: payload)
        } catch {
            exit(1)
        }

        let plan = startMsg.plan
        let process = Process()

        // Resolve executable URL
        let workingDirURL = URL(fileURLWithPath: plan.workingDirectory.isEmpty ? FileManager.default.currentDirectoryPath : plan.workingDirectory)
        let executableURL: URL
        if plan.binaryRelativePath.hasPrefix("/") {
            executableURL = URL(fileURLWithPath: plan.binaryRelativePath)
        } else {
            executableURL = workingDirURL.appendingPathComponent(plan.binaryRelativePath)
        }

        process.executableURL = executableURL
        process.currentDirectoryURL = workingDirURL
        process.arguments = plan.arguments

        var effectiveEnv = ProcessInfo.processInfo.environment
        for (k, v) in plan.env {
            effectiveEnv[k] = v
        }
        process.environment = effectiveEnv

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        let startTime = Date()

        do {
            try process.run()
        } catch {
            // Failed to run executable
            let duration = Date().timeIntervalSince(startTime) * 1000.0
            let result = WCP.ExecutionResult(
                exitCode: -1,
                cleanupState: "verified",
                survivors: [],
                durationMs: duration
            )
            sendMessage(
                socketHandle: socketHandle,
                codec: codec,
                message: WCP.Message(payload: .exited(result: result))
            )
            exit(1)
        }

        let childPid = process.processIdentifier

        // Send started notification back to dmx-core
        sendMessage(
            socketHandle: socketHandle,
            codec: codec,
            message: WCP.Message(payload: .started(pid: childPid, pgid: myPgid))
        )

        // Install signal handler to forward SIGTERM/SIGINT to child
        let termSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        let intSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        signal(SIGTERM, SIG_IGN)
        signal(SIGINT, SIG_IGN)

        termSource.setEventHandler {
            if process.isRunning {
                process.terminate()
            }
        }
        intSource.setEventHandler {
            if process.isRunning {
                process.terminate()
            }
        }
        termSource.resume()
        intSource.resume()

        // Drain pipes asynchronously
        let outSource = DispatchSource.makeReadSource(fileDescriptor: outPipe.fileHandleForReading.fileDescriptor, queue: .global())
        outSource.setEventHandler {
            _ = try? outPipe.fileHandleForReading.readToEnd()
        }
        outSource.resume()

        let errSource = DispatchSource.makeReadSource(fileDescriptor: errPipe.fileHandleForReading.fileDescriptor, queue: .global())
        errSource.setEventHandler {
            _ = try? errPipe.fileHandleForReading.readToEnd()
        }
        errSource.resume()

        // Wait for process to terminate
        process.waitUntilExit()

        termSource.cancel()
        intSource.cancel()
        outSource.cancel()
        errSource.cancel()

        let durationMs = Date().timeIntervalSince(startTime) * 1000.0
        let exitCode = process.terminationStatus

        // Supervise and clean up any lingering child processes in this process group
        let (cleanupState, survivors) = performProcessTreeCleanup(targetPgid: myPgid, rootPid: childPid)

        let executionResult = WCP.ExecutionResult(
            exitCode: exitCode,
            cleanupState: cleanupState,
            survivors: survivors,
            durationMs: durationMs
        )

        sendMessage(
            socketHandle: socketHandle,
            codec: codec,
            message: WCP.Message(payload: .exited(result: executionResult))
        )

        exit(exitCode)
    }

    private static func sendMessage(socketHandle: FileHandle, codec: FrameCodec, message: WCP.Message) {
        do {
            let data = try JSONEncoder().encode(message)
            let frame = try codec.encode(payload: data)
            socketHandle.write(frame)
        } catch {
            // Socket write failed
        }
    }

    /// Scans for surviving child processes in the given process group and verifies cleanup.
    private static func performProcessTreeCleanup(targetPgid: pid_t, rootPid: pid_t) -> (String, [Int32]) {
        var survivors: [Int32] = []
        let myPid = getpid()

        // Scan process table on macOS using libproc / proc_listpids
        var pids = [pid_t](repeating: 0, count: 2048)
        let bytesUsed = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, Int32(MemoryLayout<pid_t>.size * pids.count))

        if bytesUsed > 0 {
            let count = Int(bytesUsed) / MemoryLayout<pid_t>.size
            for i in 0..<count {
                let candidatePid = pids[i]
                if candidatePid <= 1 || candidatePid == myPid || candidatePid == rootPid {
                    continue
                }
                let candPgid = getpgid(candidatePid)
                if candPgid == targetPgid {
                    survivors.append(Int32(candidatePid))
                }
            }
        }

        if survivors.isEmpty {
            return ("verified", [])
        }

        // Attempt graceful termination (SIGTERM)
        for sPid in survivors {
            kill(pid_t(sPid), SIGTERM)
        }
        usleep(100_000) // 100ms grace period

        // Check if any remain; if so, send SIGKILL
        var postTermSurvivors: [Int32] = []
        for sPid in survivors {
            if kill(pid_t(sPid), 0) == 0 {
                // Process is still alive
                kill(pid_t(sPid), SIGKILL)
                postTermSurvivors.append(sPid)
            }
        }

        if postTermSurvivors.isEmpty {
            return ("verified", [])
        }

        usleep(50_000) // 50ms grace period
        var stubbornSurvivors: [Int32] = []
        for sPid in postTermSurvivors {
            if kill(pid_t(sPid), 0) == 0 {
                stubbornSurvivors.append(sPid)
            }
        }

        if stubbornSurvivors.isEmpty {
            return ("verified", [])
        } else {
            return ("CLEANUPUNVERIFIED", stubbornSurvivors)
        }
    }
}

// C library declarations for proc_listpids
@_silgen_name("proc_listpids")
func proc_listpids(_ type: UInt32, _ typeinfo: UInt32, _ buffer: UnsafeMutableRawPointer?, _ buffersize: Int32) -> Int32

let PROC_ALL_PIDS: UInt32 = 1
