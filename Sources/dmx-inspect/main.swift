import Foundation
import DMXModel
import DMXProtocol
import DMXInspectKit

@main
struct DMXInspectMain {
    static func main() {
        // fd 3 is the anonymous socketpair to dmx-core
        let socketFd: Int32 = 3
        let targetFd: Int32 = 4

        let socketHandle = FileHandle(fileDescriptor: socketFd, closeOnDealloc: false)
        let codec = FrameCodec(maxFrameBytes: 1024 * 1024) // 1 MB limit per ProvisionalLimits

        var decoder = FrameCodec.Decoder(maxFrameBytes: 1024 * 1024)
        var receivedPayload: Data? = nil

        // Read ICP.Request from fd 3
        while receivedPayload == nil {
            let chunk = socketHandle.availableData
            if chunk.isEmpty {
                // EOF reached without complete frame
                break
            }
            decoder.feed(data: chunk)
            do {
                if let frame = try decoder.next() {
                    receivedPayload = frame
                    break
                }
            } catch {
                sendResponse(
                    socketHandle: socketHandle,
                    codec: codec,
                    response: ICP.Response(
                        ok: false,
                        error: ICP.ErrorDetail(code: "FRAMING_ERROR", message: "Failed to decode ICP frame: \(error)")
                    )
                )
                exit(1)
            }
        }

        guard let payload = receivedPayload else {
            exit(1)
        }

        let request: ICP.Request
        do {
            request = try JSONDecoder().decode(ICP.Request.self, from: payload)
        } catch {
            sendResponse(
                socketHandle: socketHandle,
                codec: codec,
                response: ICP.Response(
                    ok: false,
                    error: ICP.ErrorDetail(code: "DECODE_ERROR", message: "Invalid ICP.Request JSON: \(error)")
                )
            )
            exit(1)
        }

        let parser = PEParser()
        let facts: RequirementFacts

        do {
            // First attempt to read target binary from fd 4 (passed by parent process)
            // Check if fd 4 is valid using fcntl
            var isFd4Valid = false
            if fcntl(targetFd, F_GETFL) != -1 {
                isFd4Valid = true
            }

            if isFd4Valid {
                facts = try parser.parse(fileDescriptor: targetFd)
            } else if let path = request.targetPath, !path.isEmpty {
                let url = URL(fileURLWithPath: path)
                facts = try parser.parse(fileURL: url)
            } else {
                throw PEParserError.readError("Neither valid fd 4 nor targetPath provided for inspection")
            }

            sendResponse(
                socketHandle: socketHandle,
                codec: codec,
                response: ICP.Response(ok: true, facts: facts)
            )
            exit(0)
        } catch {
            sendResponse(
                socketHandle: socketHandle,
                codec: codec,
                response: ICP.Response(
                    ok: false,
                    error: ICP.ErrorDetail(code: "INSPECTION_FAILED", message: "\(error.localizedDescription)")
                )
            )
            exit(1)
        }
    }

    private static func sendResponse(socketHandle: FileHandle, codec: FrameCodec, response: ICP.Response) {
        do {
            let data = try JSONEncoder().encode(response)
            let frame = try codec.encode(payload: data)
            socketHandle.write(frame)
        } catch {
            // Socket write failed, nothing more we can do
        }
    }
}
