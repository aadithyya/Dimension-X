import Foundation
import DMXModel
import DMXProtocol

public actor DCPListener {
    private let socketURL: URL
    private let handler: DCPHandler
    private var serverFd: Int32 = -1
    private var isListening: Bool = false

    public init(socketURL: URL, handler: DCPHandler) {
        self.socketURL = socketURL
        self.handler = handler
    }

    public func start() throws {
        // Ensure parent directory exists
        let dir = socketURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // Remove old socket file if present
        unlink(socketURL.path)

        serverFd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard serverFd >= 0 else {
            throw DCPError(code: "SOCKET_CREATE_FAILED", message: "Failed to create UNIX domain socket: \(errno)")
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = socketURL.path.utf8CString
        guard pathBytes.count < MemoryLayout.size(ofValue: addr.sun_path) else {
            close(serverFd)
            throw DCPError(code: "SOCKET_PATH_TOO_LONG", message: "Socket path exceeds sun_path buffer limit")
        }

        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: pathBytes.count) { dest in
                _ = pathBytes.withUnsafeBufferPointer { src in
                    memcpy(dest, src.baseAddress!, src.count)
                }
            }
        }

        let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                bind(serverFd, sa, addrLen)
            }
        }

        guard bindResult == 0 else {
            close(serverFd)
            throw DCPError(code: "SOCKET_BIND_FAILED", message: "Failed to bind UNIX domain socket: \(errno)")
        }

        guard listen(serverFd, 16) == 0 else {
            close(serverFd)
            throw DCPError(code: "SOCKET_LISTEN_FAILED", message: "Failed to listen on UNIX domain socket: \(errno)")
        }

        isListening = true

        let activeFd = serverFd
        let currentHandler = handler

        // Run accept loop on a background thread so it never blocks cooperative Swift concurrency
        DispatchQueue.global(qos: .userInitiated).async {
            while true {
                var clientAddr = sockaddr_un()
                var clientAddrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
                let clientFd = withUnsafeMutablePointer(to: &clientAddr) { ptr in
                    ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                        accept(activeFd, sa, &clientAddrLen)
                    }
                }

                if clientFd < 0 {
                    break
                }

                Task.detached {
                    await Self.processClient(clientFd: clientFd, handler: currentHandler)
                }
            }
        }
    }

    public func stop() {
        guard isListening else { return }
        isListening = false
        if serverFd >= 0 {
            close(serverFd)
            serverFd = -1
        }
        unlink(socketURL.path)
    }

    private static func processClient(clientFd: Int32, handler: DCPHandler) async {
        defer { close(clientFd) }
        let codec = FrameCodec(maxFrameBytes: ProvisionalLimits.maxDCPFrameBytes)
        var decoder = FrameCodec.Decoder(maxFrameBytes: ProvisionalLimits.maxDCPFrameBytes)
        var buffer = [UInt8](repeating: 0, count: 64 * 1024)

        while true {
            let bytesRead = Darwin.recv(clientFd, &buffer, buffer.count, 0)
            if bytesRead <= 0 {
                // Client disconnected
                break
            }

            decoder.feed(data: Data(buffer[0..<bytesRead]))

            do {
                while let frame = try decoder.next() {
                    let request = try JSONDecoder().decode(DCPRequest.self, from: frame)
                    let response = await handler.handle(request: request)
                    let respData = try JSONEncoder().encode(response)
                    let outFrame = try codec.encode(payload: respData)

                    outFrame.withUnsafeBytes { rawPtr in
                        _ = Darwin.send(clientFd, rawPtr.baseAddress!, outFrame.count, 0)
                    }
                }
            } catch {
                break
            }
        }
    }
}
