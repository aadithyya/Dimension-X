import Foundation
import DMXModel
import DMXProtocol

public actor DCPClient {
    private let socketURL: URL
    private var clientFd: Int32 = -1
    private let codec = FrameCodec(maxFrameBytes: ProvisionalLimits.maxDCPFrameBytes)

    public init(socketURL: URL? = nil) {
        if let custom = socketURL {
            self.socketURL = custom
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.socketURL = appSupport.appendingPathComponent("DimensionX/run/dcp.sock")
        }
    }

    public func connect() throws {
        if clientFd >= 0 {
            close(clientFd)
            clientFd = -1
        }

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw DCPError(code: "CLIENT_SOCKET_FAILED", message: "Failed to create client socket: \(errno)")
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = socketURL.path.utf8CString
        guard pathBytes.count < MemoryLayout.size(ofValue: addr.sun_path) else {
            close(fd)
            throw DCPError(code: "SOCKET_PATH_TOO_LONG", message: "Socket path exceeds sun_path limit")
        }

        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: pathBytes.count) { dest in
                _ = pathBytes.withUnsafeBufferPointer { src in
                    memcpy(dest, src.baseAddress!, src.count)
                }
            }
        }

        let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
        let connectResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                Darwin.connect(fd, sa, addrLen)
            }
        }

        guard connectResult == 0 else {
            close(fd)
            throw DCPError(code: "CONNECT_FAILED", message: "Failed to connect to dmx-core at \(socketURL.path): \(errno)")
        }

        self.clientFd = fd
    }

    public func disconnect() {
        if clientFd >= 0 {
            close(clientFd)
            clientFd = -1
        }
    }

    public func send(method: String, payload: JSONValue = .null) async throws -> DCPResponse {
        if clientFd < 0 {
            try connect()
        }

        let request = DCPRequest(method: method, payload: payload)
        let reqData = try JSONEncoder().encode(request)
        let frame = try codec.encode(payload: reqData)

        let sendResult = frame.withUnsafeBytes { rawPtr in
            Darwin.send(clientFd, rawPtr.baseAddress!, frame.count, 0)
        }

        guard sendResult > 0 else {
            disconnect()
            throw DCPError(code: "SEND_FAILED", message: "Failed to send frame to dmx-core")
        }

        var decoder = FrameCodec.Decoder(maxFrameBytes: ProvisionalLimits.maxDCPFrameBytes)
        var buffer = [UInt8](repeating: 0, count: 64 * 1024)

        while true {
            let bytesRead = Darwin.recv(clientFd, &buffer, buffer.count, 0)
            if bytesRead <= 0 {
                disconnect()
                throw DCPError(code: "CONNECTION_CLOSED", message: "Server closed connection")
            }

            decoder.feed(data: Data(buffer[0..<bytesRead]))
            if let respFrame = try decoder.next() {
                return try JSONDecoder().decode(DCPResponse.self, from: respFrame)
            }
        }
    }
}
