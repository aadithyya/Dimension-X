# Dimension X (DMX)

Dimension X (DMX) is a local-first macOS Windows-compatibility control plane. DMX provides clean orchestration, environment isolation, and evidence-based compatibility reporting around Wine on macOS Apple Silicon.

## Core Features
- Local-first architecture (no cloud server, no telemetry, no mandatory external network dependencies).
- Strict separation of process roles (Authority `dmx-core`, Disposable Inspector `dmx-inspect`, Disposable Supervisor `dmx-worker`, UI Client `DimensionX`).
- Deterministic planning & canonical content-addressed hashing.
- Atomic environment generation and prefix isolation.
- Evidence-based compatibility records (`ADMITTED ≠ QUALIFIED ≠ WORKS`).

## Building & Testing
```bash
swift build
swift test
```
