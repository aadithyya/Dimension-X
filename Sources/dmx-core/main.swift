import Foundation
import DMXModel
import DMXProtocol
import DMXCore

@main
struct DMXCoreMain {
    static func main() async {
        print("[dmx-core] Starting Dimension X Core Authority...")

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("DimensionX")
        let runDir = appSupport.appendingPathComponent("run")
        try? FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)

        let lockURL = runDir.appendingPathComponent("dmx-core.lock")
        let lockFd = open(lockURL.path, O_CREAT | O_RDWR, 0o644)
        guard lockFd >= 0 else {
            print("[dmx-core] Error: Failed to open lock file at \(lockURL.path)")
            exit(1)
        }

        // Enforce single-instance via flock
        if flock(lockFd, LOCK_EX | LOCK_NB) != 0 {
            print("[dmx-core] Notice: Another instance of dmx-core is already running. Exiting.")
            exit(0)
        }

        do {
            let dbURL = appSupport.appendingPathComponent("dmx_storage.sqlite")
            let storage = try StorageService(databaseURL: dbURL)
            let analyzer = AnalyzerService()
            let broker = ExecutionBroker.shared
            let envManager = EnvironmentManager(storage: storage)

            let handler = DCPHandler(
                storage: storage,
                analyzer: analyzer,
                broker: broker,
                envManager: envManager
            )

            let socketURL = runDir.appendingPathComponent("dcp.sock")
            let listener = DCPListener(socketURL: socketURL, handler: handler)
            try await listener.start()

            print("[dmx-core] Listening on Unix domain socket: \(socketURL.path)")

            // Handle clean shutdown on signals
            let sigTerm = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
            let sigInt = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
            signal(SIGTERM, SIG_IGN)
            signal(SIGINT, SIG_IGN)

            sigTerm.setEventHandler {
                Task {
                    await listener.stop()
                    close(lockFd)
                    unlink(lockURL.path)
                    print("[dmx-core] Terminated cleanly via SIGTERM.")
                    exit(0)
                }
            }
            sigInt.setEventHandler {
                Task {
                    await listener.stop()
                    close(lockFd)
                    unlink(lockURL.path)
                    print("[dmx-core] Terminated cleanly via SIGINT.")
                    exit(0)
                }
            }
            sigTerm.resume()
            sigInt.resume()

            // Keep main loop alive
            while true {
                try await Task.sleep(nanoseconds: 1_000_000_000)
            }
        } catch {
            print("[dmx-core] Fatal error during startup: \(error)")
            close(lockFd)
            exit(1)
        }
    }
}
