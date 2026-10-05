# Dimension X (DMX) — Validation Required Ledger

This document tracks all unverified engineering assumptions and provisional limits across Dimension X V1.

---

## 1. Process Supervision & Cleanup
- **[VALIDATION REQUIRED]**: Wine's actual process-tree behavior (wineserver lifetime, process re-parenting, child daemon spawns) on macOS has not been fully empirically verified against all target Wine runtimes. The prefix-scoped process scan in `StopSequence` is an engineering inference and must be verified against live runtimes before claiming cleanup is guaranteed.

## 2. Host Capability Probing
- **[VALIDATION REQUIRED]**: The generic `x8664-probe` binary execution proves generic x8664 process launch on macOS Apple Silicon (via Rosetta 2), but does NOT prove Wine compatibility, graphics translation capability, or application feasibility.

## 3. Provisional Limits & Parameters
All numerical limits listed below are defined as named constants in `DMXCore/Policy/ProvisionalLimits.swift` with doc comment `// PROVISIONAL — VALIDATION REQUIRED`:
- `maxDCPFrameBytes`: 16,777,216 bytes (16 MB)
- `maxWCPFrameBytes`: 4,194,304 bytes (4 MB)
- `maxICPFrameBytes`: 1,048,576 bytes (1 MB)
- `inspectorTimeout`: 10.0 seconds
- `probeTimeout`: 5.0 seconds
- `qualificationTimeout`: 120.0 seconds
- `maxQueuedEventsPerClient`: 1000 events
- `idleTimeout`: 300.0 seconds (5 minutes)
