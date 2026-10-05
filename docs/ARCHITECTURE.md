# Dimension X (DMX) V1 Architecture

// LOCKED: Architectural Principles & Constraints

Dimension X (DMX) is a local-first macOS Windows-compatibility control plane. DMX is an orchestration and evidence system around Wine. It is NOT Wine, not an emulator, not a VM, not an antivirus, and not a cloud service.

## Non-Negotiable Locked Rules

- MUST NOT implement a CPU emulator, DirectX implementation, graphics abstraction, or VM.
- MUST NOT add a root helper, privileged daemon, LaunchAgent, kernel extension, or always-running background process.
- MUST NOT add a database server, second database, message broker, or microservice boundaries (services are actors within one process).
- MUST NOT add AI/ML, a rule engine, constraint solver, optimizer, or configuration search of any kind.
- MUST NOT enumerate the Cartesian product of runtimes × providers × CPU paths and filter afterwards.
- MUST NOT put DMX code in the frame/input/audio hot path, poll running games, or intercept frames.
- MUST NOT bypass Gatekeeper, SIP, TCC, code signing, quarantine, DRM, or anti-cheat.
- MUST NOT redistribute third-party components (D3DMetal is user-imported).
- MUST NOT promote evidence automatically (no "ran 60 s without crash => WORKS"). UNKNOWN is a legitimate verdict.

## Fixed Vocabulary & Verdicts

| Gate | Question | Verdicts |
|---|---|---|
| Artifact admission | Is the artifact structurally valid? | `admitted`, `rejected` |
| Composition qualification | Does this exact RuntimeComposition execute on this HostIdentity? | `qualified`, `failed` |
| Application compatibility | Does this app behave correctly under this composition/host/scenario? | `works`, `partial`, `fails`, `blocked`, `unknown` |

`ADMITTED ≠ QUALIFIED ≠ WORKS ≠ GOOD PERFORMANCE`. Performance and feasibility are separate fields, never folded into compatibility.

## Process Topology

```
DimensionX (GUI, SwiftUI)  ──DCP/1 (Unix socket)──▶  dmx-core (authority, on-demand, flock single-instance)
                                                        ├──ICP/1 (socketpair fd3; fd4 = read-only PE)──▶ dmx-inspect (disposable PE parser)
                                                        └──WCP/1 (socketpair fd3)──────────────────────▶ dmx-worker (disposable execution supervisor)
```

- `ExecutionBroker` is the only code allowed to spawn `dmx-worker`.
- `StorageService` is the only code allowed to touch the database.
- The GUI holds no compatibility logic.
