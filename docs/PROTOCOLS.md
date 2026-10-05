# Dimension X (DMX) Wire Protocols

## Wire Framing (FrameCodec)

All three Unix domain socket protocols (`DCP/1`, `WCP/1`, `ICP/1`) use identical binary length-prefixed framing.

### Frame Layout
```
+-----------------------------------+-----------------------------------+
| Big-Endian Length Prefix (4 bytes)| Payload Bytes (N bytes)           |
+-----------------------------------+-----------------------------------+
```
- **Length Prefix**: 32-bit unsigned integer in network byte order (Big-Endian) indicating `N`, the length of payload bytes.
- **Payload**: `N` bytes of UTF-8 encoded JSON payload data. Max byte bounds are enforced by `FrameCodec` using limits defined in `ProvisionalLimits`.

---

## 1. Dimension Control Protocol (DCP/1)

Used between `DimensionX` (GUI client) and `dmx-core` over Unix domain socket (`~/Library/Application Support/DimensionX/run/dcp.sock`).

### Messages
- `DCPRequest`: `{ "version": 1, "type": "request", "id": "<uuid>", "method": "<method>", "payload": <JSONValue>, "idempotencyKey": "<key>?" }`
- `DCPResponse`: `{ "version": 1, "type": "response", "id": "<uuid>", "ok": true|false, "payload": <JSONValue>?, "error": <DCPError>? }`
- `DCPEvent`: `{ "version": 1, "type": "event", "operationID": "<uuid>", "seq": <int64>, "payload": <JSONValue> }`

---

## 2. Worker Control Protocol (WCP/1)

Used between `dmx-core` (`ExecutionBroker`) and `dmx-worker` over anonymous `socketpair` (`fd 3`).

### Messages
- `WCPStart`: Sent from core to worker containing `LaunchPlan`.
- `WCPStatus`: Sent from worker to core reporting `started(pid, pgid)`, `progress(message)`, and `exited(result)`.

---

## 3. Inspector Control Protocol (ICP/1)

Used between `dmx-core` (`AnalyzerService`) and `dmx-inspect` over anonymous `socketpair` (`fd 3`). `fd 4` is a read-only handle to the target PE binary file.

### Messages
- `ICPRequest`: Sent from core to inspector requesting inspection.
- `ICPResponse`: Sent from inspector to core containing `RequirementFacts` or error details.
