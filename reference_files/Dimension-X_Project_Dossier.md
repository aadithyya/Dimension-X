# Dimension X (DMX) — Project Dossier

**Project:** Dimension X  
**Short name:** DMX  
**Repository:** `aadithyya/Dimension-X`  
**Repository visibility:** Public  
**Target platform:** macOS, primarily Apple Silicon  
**Project type:** Open-source Windows compatibility platform for macOS  
**Current phase:** Local analysis + profile-management foundation  
**Execution status:** Windows execution intentionally unavailable in the current increment

---

## 1. Project Vision

Dimension X is intended to be a production-grade native macOS compatibility platform for running Windows applications and games on Apple Silicon Macs.

The project is **not** intended to be:

- a clone of CrossOver
- a clone of Whisky
- a Windows virtual machine
- a full Windows emulator
- a replacement for Wine
- a replacement for Apple's Game Porting Toolkit
- an antivirus
- a system-wide security product
- a claim that every Windows application can run

The central idea is to build an intelligent compatibility platform around existing mature technologies while adding:

- automatic application analysis
- per-application configuration
- runtime management
- security policy enforcement
- isolated environments
- monitoring
- diagnostics
- measurable optimization
- rollback/recovery
- launcher integration
- a native macOS interface
- a shared CLI/backend
- privacy-first local operation
- reproducible open-source engineering

The project should use mature components instead of recreating Windows compatibility technology from scratch.

Candidate technologies discussed:

- Wine / Wine WoW64
- Apple Game Porting Toolkit components where legally and technically appropriate
- D3DMetal / DXMT
- DXVK / MoltenVK where appropriate
- Metal
- native macOS security mechanisms
- Endpoint Security where justified by the final design

---

# 2. Core Product Philosophy

The original security/compatibility model was:

```text
Analyze → Restrict → Execute → Monitor → Enforce
```

rather than pretending that analysis itself makes an application safe:

```text
Analyze → Safe → Execute
```

A central architectural principle established during development is:

> **A Wine prefix is not a security boundary.**

Therefore DMX must not ship an unrestricted Wine launcher and call it "secure isolation".

The project must never weaken macOS security merely to improve compatibility.

DMX should not bypass:

- Gatekeeper
- System Integrity Protection (SIP)
- TCC
- code signing
- quarantine
- supported macOS security mechanisms

DMX must not bypass:

- unsupported kernel-driver requirements
- kernel anti-cheat
- unsupported Windows kernel facilities
- incompatible DRM
- hardware-dependent functionality

Applications requiring unsupported capabilities should be reported as unsupported, blocked, or unverified rather than having security controls bypassed.

---

# 3. Intended High-Level Architecture

The intended conceptual pipeline is:

```text
Windows Application
        ↓
Compatibility Engine
        ↓
Dimension Profile
        ↓
Runtime Manager
        ↓
Security Policy
        ↓
Isolated Environment
        ↓
Execution
        ↓
Monitoring
        ↓
Optimization
        ↓
Recovery
```

The more detailed intended flow is:

```text
EXE / MSI
    ↓
Analyzer
    ├── PE architecture
    ├── imported DLLs/APIs
    ├── graphics APIs
    ├── runtime dependencies
    ├── CLR / .NET evidence
    ├── services
    ├── driver/kernel evidence
    ├── launcher requirements
    ├── anti-cheat / DRM evidence
    └── known compatibility signatures
    ↓
Compatibility Profile
    ↓
Execution Plan
    ├── Wine/runtime version
    ├── graphics backend
    ├── sync mode
    ├── dependencies
    ├── DLL overrides
    ├── Windows-version emulation
    ├── security policy
    └── environment settings
    ↓
Execution Boundary / Broker
    ↓
Windows Process
    ↓
Monitoring / Diagnostics / Recovery
```

---

# 4. Proposed Repository Architecture

The eventual source layout discussed is:

```text
Sources/
├── DimensionX/              ← SwiftUI macOS application
│
├── DMXCore/
│   ├── Analysis/
│   ├── Profiles/
│   ├── Compatibility/
│   ├── Policies/
│   └── Diagnostics/
│
├── DMXRuntime/
│   ├── Wine/
│   ├── GPTK/
│   ├── Graphics/
│   ├── Prefix/
│   └── Process/
│
├── DMXSecurity/
│   ├── Filesystem/
│   ├── Network/
│   ├── Process/
│   └── Monitoring/
│
└── DMXCLI/
```

For the first increment, the implementation is intentionally smaller:

```text
Sources/
├── DMXCore/
├── DMXCLI/
└── DimensionX/

Tests/
└── DMXCoreTests/

scripts/
.github/
```

---

# 5. Main Systems Planned for Full DMX

## 5.1 Compatibility Analyzer

Analyze Windows applications before execution.

Planned areas:

- PE format
- x86
- x86_64
- ARM64
- ARM64EC / ARM64X
- Windows APIs/imports
- DirectX
- Vulkan
- OpenGL
- .NET / CLR
- Visual C++ runtimes
- Windows services
- kernel drivers
- privileges
- launcher requirements
- anti-cheat
- DRM
- known compatibility patterns

Evidence should distinguish:

```text
confirmed
detected
inferred
unknown
```

Static evidence must never be treated as proof that a runtime behavior exists or that an application is safe.

---

## 5.2 Compatibility Database

Planned structured compatibility records:

```text
application
version
publisher
SHA-256
architecture
recommended runtime
graphics backend
sync configuration
dependencies
DLL overrides
environment variables
known workarounds
known failures
controller profile
security requirements
tested macOS versions
tested Apple Silicon generation
tested runtime version
```

The database should be versioned and reproducible, for example using structured JSON/YAML.

---

## 5.3 Automatic Configuration

DMX should be able to select:

- runtime
- graphics backend
- sync mode
- dependencies
- DLL overrides
- Windows-version emulation
- environment variables
- per-app launch settings

Changes should be reversible.

---

## 5.4 Isolated Environments

An environment should eventually include:

```text
virtual C: drive
registry
Windows profile
dependencies
runtime configuration
graphics configuration
environment variables
launch arguments
network policy
filesystem policy
security policy
logs
snapshots
```

Operations should eventually include:

- create
- delete
- rename
- duplicate
- clone
- import
- export
- backup
- restore
- move
- repair
- reset

---

## 5.5 Security

Possible policy modes:

```text
Standard
Strict
Compatibility
Custom
```

Planned control areas:

- filesystem
- network
- process behavior
- device/resource access
- child processes
- host resource visibility
- execution policy

DMX should use supported macOS mechanisms and be honest about enforcement limits.

A capability should be classified as:

```text
enforceable
partially enforceable
observable but not enforceable
impossible to guarantee
```

---

## 5.6 Performance and Optimization

Eventually measure, where technically possible:

- startup time
- FPS
- frame time
- CPU usage
- GPU usage
- memory
- crashes
- runtime behavior

Optimization must be measurable and reversible rather than a collection of unverified "boost" switches.

---

## 5.7 Recovery

Planned recovery model:

```text
last known-good configuration
        ↓
snapshot
        ↓
change
        ↓
test
        ↓
failure
        ↓
rollback
```

The first increment only snapshots profile metadata; it does not yet snapshot a complete Windows environment.

---

## 5.8 Diagnostics

Planned diagnostic data:

```text
macOS version
Apple Silicon / architecture
DMX version
runtime version
Wine configuration
graphics backend
dependencies
configuration
logs
crash data
security events
recent changes
```

Secrets, credentials, tokens, and private information must be redacted.

The first increment uses a much narrower allowlist and does not upload diagnostics.

---

## 5.9 Launchers / Controllers / Shortcuts

Planned integrations include:

- Steam
- Epic
- EA
- Rockstar
- Battle.net
- Ubisoft
- future launcher plugins

Planned controller features:

- native/SDL-compatible controller support
- per-game mappings
- shortcuts

---

## 5.10 CLI

The desired CLI surface discussed:

```bash
dmx list
dmx create <environment>
dmx install <environment> <installer>
dmx launch <environment> <program>
dmx diagnose <environment>
dmx snapshot <environment>
dmx restore <environment> <snapshot>
dmx export <environment>
dmx import <archive>
dmx runtime list
dmx runtime install <runtime>
dmx doctor
```

The first increment implements a subset of the command surface and explicitly rejects execution.

---

## 5.11 Update System

Eventually separate:

```text
DMX application updates
runtime updates
graphics backend updates
compatibility database updates
```

Users should be able to pin working runtime versions rather than being forced into potentially breaking updates.

---

## 5.12 Privacy

Design goal:

- local-first
- no required account
- telemetry disabled by default
- no required analytics
- no automatic upload of executables/documents
- no silent collection of application contents

The first increment contains no network client, account system, telemetry, or upload mechanism.

---

## 5.13 Plugin Architecture

Potential plugin types:

- launcher
- compatibility database provider
- graphics backend
- runtime provider
- diagnostics extension
- controller profile provider

Plugins should have explicit capabilities and should not receive unrestricted privileged access.

---

# 6. Repository State

Repository:

```text
https://github.com/aadithyya/Dimension-X
```

The repository is public.

At the time this dossier was created, the repository page showed the repository existed but was essentially empty aside from GitHub's quick-start content.

Astra was initially unable to use the GitHub connector, so the workflow changed to:

```text
Astra builds locally
        ↓
Astra provides source
        ↓
User manually pushes source to GitHub
```

Astra was explicitly instructed:

> Do not ask further GitHub setup questions.

---

# 7. Current Increment — "Foundation"

The first implemented increment is intentionally **not** the final compatibility runner.

It implements:

| Component | Current state |
|---|---|
| Local executable analysis | Implemented in source |
| Persisted application profiles | Implemented in source |
| Profile snapshots | Implemented; metadata only |
| Profile restore | Implemented |
| Diagnostics | Implemented |
| Shared CLI backend | Implemented |
| Native SwiftUI application | Implemented |
| Unit tests | Implemented |
| Development app bundle script | Implemented |
| CI workflow | Implemented |
| Windows execution | Explicitly unavailable |
| Wine runtime download | Not implemented |
| Runtime execution | Not implemented |
| Enforced per-app isolation | Not implemented |
| MSI parsing | Not implemented |
| Steam/Epic/etc. integration | Not implemented |
| Graphics backend qualification | Not implemented |
| Production signing/notarization | Not implemented |

Astra explicitly stated that it could not compile or run macOS software in its session, so the source is **not yet build-verified**.

---

# 8. Current Source Tree

```text
Dimension-X/
├── Package.swift
├── Sources/
│   ├── DMXCore/
│   │   ├── Models.swift
│   │   ├── BoundedFile.swift
│   │   ├── PEAnalyzer.swift
│   │   ├── ProfileStore.swift
│   │   └── DMXService.swift
│   ├── DMXCLI/
│   │   └── main.swift
│   └── DimensionX/
│       └── DimensionXApp.swift
│
├── Tests/
│   └── DMXCoreTests/
│       └── DMXCoreTests.swift
│
├── scripts/
│   └── build-app.sh
│
├── .github/
│   └── workflows/
│       └── ci.yml
│
├── .gitignore
├── README.md
├── SECURITY.md
├── CONTRIBUTING.md
├── THIRD-PARTY-NOTICES
└── LICENSE
```

---

# 9. Important Code Snippets From the Current Increment

## 9.1 Package Definition

```swift
// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "DimensionX",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "DMXCore", targets: ["DMXCore"]),
        .executable(name: "dmx", targets: ["DMXCLI"]),
        .executable(name: "DimensionX", targets: ["DimensionX"]),
    ],
    targets: [
        .target(name: "DMXCore"),
        .executableTarget(
            name: "DMXCLI",
            dependencies: ["DMXCore"]
        ),
        .executableTarget(
            name: "DimensionX",
            dependencies: ["DMXCore"]
        ),
        .testTarget(
            name: "DMXCoreTests",
            dependencies: ["DMXCore"]
        ),
    ]
)
```

---

## 9.2 Evidence Model

```swift
public enum Certainty: String, Codable, Sendable {
    case confirmed
    case detected
    case inferred
    case unknown
}

public enum Provenance: String, Codable, Sendable {
    case localStaticAnalysis
    case importedUnverified
}

public struct Finding: Codable, Equatable, Sendable {
    public var topic: String
    public var value: String
    public var certainty: Certainty
    public var source: String
}
```

This is one of the most important design choices in the current system.

---

## 9.3 Analysis Report

```swift
public struct AnalysisReport: Codable, Equatable, Sendable {
    public var analyzerVersion: Int
    public var provenance: Provenance
    public var sha256: String
    public var byteCount: Int
    public var machine: String
    public var importedDLLs: [String]
    public var importedAPIs: [String]
    public var findings: [Finding]
    public var executionBlocks: [String]
}
```

---

## 9.4 Profile

```swift
public struct ApplicationProfile:
    Codable, Identifiable, Equatable, Sendable
{
    public var schemaVersion: Int
    public var id: UUID
    public var name: String
    public var createdAt: Date
    public var updatedAt: Date
    public var analysis: AnalysisReport
}
```

The profile is versioned and locally persisted.

---

## 9.5 PE Validation

The parser validates:

```text
MZ DOS header
        ↓
PE signature
        ↓
COFF machine
        ↓
optional header
        ↓
section table
        ↓
RVA-to-file mapping
        ↓
import directory
```

Architecture mapping currently includes:

```swift
switch machineCode {
case 0x014C:
    machine = "x86 (PE machine field)"
case 0x8664:
    machine = "x86_64 (PE machine field)"
case 0xAA64:
    machine = "ARM64 (PE machine field)"
case 0xA641:
    machine = "ARM64EC (PE machine field)"
default:
    machine = String(format: "Unknown PE machine 0x%04X", machineCode)
}
```

---

## 9.6 Graphics Evidence

Current import-based graphics evidence recognizes:

```text
d3d9.dll      → Direct3D 9
d3d10.dll     → Direct3D 10
d3d10_1.dll   → Direct3D 10.1
d3d11.dll     → Direct3D 11
d3d12.dll     → Direct3D 12
vulkan-1.dll  → Vulkan
opengl32.dll  → OpenGL
```

The finding is deliberately marked as inferred:

```swift
Finding(
    topic: "graphics",
    value: "\(api) may be required",
    certainty: .inferred,
    source: "Imported DLL: \(dll); backend compatibility untested"
)
```

---

## 9.7 Visual C++ Evidence

Current static heuristic:

```swift
let runtimeDLLs = dlls.filter {
    $0.hasPrefix("vcruntime") ||
        $0.hasPrefix("msvcp") ||
        $0.hasPrefix("msvcr")
}
```

It then records:

```text
Visual C++ runtime dependency may be required
```

but does not claim an exact redistributable version.

---

## 9.8 CLR Evidence

Current analyzer checks the PE CLR directory.

When found:

```text
CLR header declared
```

When absent:

```text
No CLR directory; bootstrapper requirements remain unknown
```

The latter is intentionally not treated as proof that .NET is unnecessary.

---

## 9.9 Execution Blocking

The current analyzer can block profiles for certain detected system-level indicators.

Example:

```swift
if subsystem == 1 {
    blocks.append(
        "Native-subsystem image: unsupported system-level executable."
    )
}
```

Kernel-related evidence also results in blocking:

```swift
let kernelNames: Set<String> = [
    "ntoskrnl.exe",
    "hal.dll",
    "wdfldr.sys",
]
```

However, the system does not claim that the absence of these imports proves an application is safe.

---

# 10. Profile Store

Profiles are persisted locally.

Conceptually:

```text
~/Library/Application Support/DimensionX/state.json
```

The store uses:

- local JSON
- atomic writes
- `0700` directory permissions
- `0600` state/profile file permissions
- a lock file
- validation
- schema versions
- maximum sizes/counts

The locking system is explicitly **not** a security boundary against hostile software running as the same macOS user.

---

# 11. Snapshots

Current snapshots contain:

```text
profile metadata
analysis
findings
timestamps
snapshot reason
```

They do **not** contain:

- Wine prefix
- Windows filesystem
- registry state
- runtime binaries
- application data
- APFS snapshot
- complete environment state

Important distinction:

> Current "snapshot" = profile metadata snapshot.

Future "environment snapshot" = runtime + environment + configuration recovery system.

---

# 12. Import/Export

Profiles can be exported to JSON.

Import behavior intentionally downgrades trust:

```swift
profile.analysis.provenance = .importedUnverified

profile.analysis.findings = profile.analysis.findings.map {
    Finding(
        topic: $0.topic,
        value: $0.value,
        certainty: .unknown,
        source: "Imported document; not locally verified"
    )
}
```

This prevents imported claims from being treated as locally verified analysis.

---

# 13. Execution Gate

The current service explicitly refuses execution:

```swift
public func requireExecution(_ profileID: UUID) throws {
    let profile = try store.get(profileID)

    if !profile.analysis.executionBlocks.isEmpty {
        throw DMXError.unavailable(
            "Execution is blocked by static-analysis findings. " +
            "Inspect this profile before proceeding."
        )
    }

    throw DMXError.unavailable(
        "Windows execution is unavailable. " +
        "DMX will not fall back to unrestricted Wine execution."
    )
}
```

This is deliberate.

Even a "clean" profile cannot execute yet.

---

# 14. Runtime Status

Current runtime response is explicitly:

```swift
RuntimeStatus(
    installedRuntimeCount: 0,
    executionAvailable: false,
    reason:
        "Runtime provisioning and an independently validated " +
        "execution boundary are not implemented in this increment."
)
```

Therefore the project does not pretend that Wine/GPTK is already integrated.

---

# 15. Diagnostics

Current diagnostics are intentionally narrow.

They include:

```text
macOS version
process architecture
logical processor count
physical memory
profile count
execution-blocked profile count
imported/unverified profile count
runtime availability
telemetry state
upload state
```

They intentionally exclude:

```text
application names
paths
hashes
raw logs
environment variables
executable contents
runtime metrics
security-event collection
```

The current report is allowlisted rather than "collect everything and redact later".

---

# 16. SwiftUI Application

The current app includes these sections:

```text
Home
Applications
Runtime Manager
Security
Diagnostics
Settings
```

The app can currently:

- analyze an EXE
- display profile information
- display findings
- snapshot metadata
- list snapshots
- export metadata
- import profiles
- display runtime status
- generate diagnostics

The UI explicitly says execution is unavailable.

This is an operational management UI, not a fake Windows launcher.

---

# 17. CLI

Current command surface:

```bash
dmx list
dmx create <file.exe>
dmx install <profile-id>
dmx launch <profile-id>
dmx diagnose
dmx snapshot <profile-id>
dmx snapshot list <profile-id>
dmx restore <snapshot-id>
dmx export <profile-id> <new-file.json>
dmx import <file.json>
dmx runtime
dmx doctor
```

`install` and `launch` deliberately return an unavailable-capability error.

`doctor` reports the current readiness and returns exit code 2 because Windows execution is unavailable.

---

# 18. Current Tests

The first test suite covers:

- normal import and graphics evidence
- truncated PE rejection
- invalid PE offset
- native-subsystem execution blocking
- invalid import-name mapping
- profile snapshot/restore
- automatic restore backup
- persistence across store instances
- imported evidence downgrade
- execution refusal
- private diagnostic exclusion
- symlink rejection

Important test philosophy:

> These tests are initial regression tests, not a substitute for fuzzing, adversarial testing, process-concurrency testing, or a security audit.

---

# 19. Development App Bundle

The current `build-app.sh` script:

```bash
swift build -c release --arch arm64
```

then builds:

```text
build/Dimension X.app
```

and performs an ad-hoc signature.

Important limitation:

```text
not notarized
not a production release
```

The build does not bypass Gatekeeper or remove quarantine.

---

# 20. CI

The CI workflow:

```text
macos-15
    ↓
Swift build
    ↓
Swift test
    ↓
CLI help check
    ↓
Apple Silicon development bundle
```

Warnings are intended to be treated as errors.

The CI workflow is not yet a production distribution pipeline.

---

# 21. Current Documentation Files

Astra also prepared:

```text
README.md
SECURITY.md
CONTRIBUTING.md
THIRD-PARTY-NOTICES
LICENSE
```

The README records current implementation limitations.

`SECURITY.md` explicitly states that:

> The development GUI and CLI are ordinary macOS processes. They are not represented as independently sandboxed execution environments.

That is an important and correct limitation.

---

# 22. Licensing Decision Still Worth Revisiting

The current generated repository uses:

```text
MIT License
```

Earlier project discussion had considered:

```text
Apache-2.0
```

This should be consciously decided.

For future third-party runtime components, each artifact requires independent license and redistribution review.

In particular, future integrations may include:

```text
Wine
DXMT
DXVK
MoltenVK
D3DMetal / GPTK components
Windows redistributables
launchers
```

They should not be bundled or redistributed merely because the software can technically run them.

---

# 23. What Is Still Missing for Full DMX

The current implementation is only a foundation.

Major systems still required:

```text
Wine/WoW64 runtime manager
GPTK integration where appropriate
D3DMetal/DXMT integration
DXVK/MoltenVK integration where appropriate
runtime download + signature/hash verification
runtime pinning
prefix creation
MSI support
dependency installation
registry management
Windows-version configuration
DLL overrides
real launch/process lifecycle
Steam/Epic/etc. integration
controller support
application shortcuts
filesystem policy enforcement
network policy enforcement
process isolation policy
device/resource policy
security broker / IPC
macOS security integration
runtime monitoring
crash handling
rollback
environment snapshots
performance instrumentation
compatibility database
compatibility reports
graphics backend selection
automatic optimization
production signing
notarization
DMG distribution
release/update system
```

---

# 24. Immediate Technical Assessment

## What is strong

### Architecture

The separation between:

```text
analysis
profiles
diagnostics
CLI
SwiftUI
```

is a good foundation.

### Safety posture

The project does not pretend that:

```text
Wine prefix = sandbox
```

and does not enable unrestricted execution simply because it is easier.

### Evidence model

The distinction between:

```text
confirmed
detected
inferred
unknown
```

is valuable.

### Privacy

The current increment has:

```text
no account
no telemetry
no upload
no network client
```

by design.

### Reversibility

Profile snapshots and automatic backups are already established as part of the architecture.

---

# 25. Current Weaknesses

## 25.1 Not build-verified yet

Astra did not have a macOS build/test environment.

This must be verified locally.

---

## 25.2 Analyzer is incomplete

Still missing or incomplete:

```text
delay imports
manifests
resources/version information
packed executables
dynamic LoadLibrary-style dependency behavior
transitive dependencies
exact runtime versions
real installer analysis
MSI custom actions
signing/Authenticode details
full CLR framework analysis
```

---

## 25.3 Snapshots are metadata-only

They are not environment recovery.

---

## 25.4 Security boundary does not exist yet

This is the largest technical gap.

The current application reads data safely enough for this stage, but it does not yet execute an untrusted Windows process inside a demonstrated, enforced boundary.

---

## 25.5 No runtime system

Wine/GPTK/graphics backends are not integrated.

---

## 25.6 No compatibility database yet

Current findings are generated dynamically from static evidence but there is not yet a mature app/version compatibility knowledge base.

---

# 26. Next Engineering Milestone

The recommended next milestone is:

# DMX Execution Boundary Prototype

Do **not** jump directly to:

```text
EXE → Wine → launch
```

Instead:

```text
DMX GUI / CLI
       ↓
Execution Manager
       ↓
Policy Engine
       ↓
Execution Broker
       ↓
Wine Runtime
       ↓
Windows Process
```

The purpose is to determine exactly what DMX can enforce on macOS.

---

# 27. Execution-Boundary Test Matrix

The next milestone should investigate:

| Area | Question |
|---|---|
| Filesystem | Can one profile be prevented from accessing another? |
| Host files | Which host directories can be blocked or exposed? |
| Network | Can traffic be restricted per profile? |
| Processes | Can child-process creation be observed/controlled? |
| Environment | Can per-profile environment variables be isolated? |
| Devices | What device/resource access is possible? |
| Runtime | Can runtime provenance be verified? |
| Signing | What must be signed and how? |
| Teardown | Can every process be reliably terminated? |
| Crash recovery | Can a failed process leave resources behind? |
| Monitoring | What events are observable? |
| Enforcement | Which controls are actually enforceable? |

Every capability should be classified:

```text
ENFORCEABLE
PARTIALLY ENFORCEABLE
OBSERVABLE ONLY
NOT GUARANTEED
```

---

# 28. Crucial Security Rule for the Next Stage

No one should implement:

```text
if launchWorks:
    call it secure
```

Instead, each security claim should have a reproducible test.

Example:

```text
Requirement:
Wine process must not read profile B's private data.

Test:
Create profile A and profile B.
Place a sentinel file in B.
Launch A.
Attempt read from B.
Observe result.
Repeat across restarts.
Document enforcement mechanism.
```

If the test fails, DMX must not claim isolation.

---

# 29. Recommended Development Sequence

```text
PHASE 1
Local analysis + profiles
        ↓
PHASE 2
Execution boundary experiment
        ↓
PHASE 3
Runtime manager
        ↓
PHASE 4
Wine environment/prefix management
        ↓
PHASE 5
Graphics backends
        ↓
PHASE 6
Compatibility database
        ↓
PHASE 7
Monitoring + optimization
        ↓
PHASE 8
Launchers/controllers/shortcuts
        ↓
PHASE 9
Recovery / snapshots
        ↓
PHASE 10
Production signing + notarization + distribution
```

The project should not skip Phase 2 merely because Phase 3 is easier to demonstrate.

---

# 30. Build Verification Checklist

Before adding major runtime functionality:

```bash
swift build -Xswiftc -warnings-as-errors
swift test -Xswiftc -warnings-as-errors
swift run dmx --help
swift run dmx list
swift run DimensionX
bash scripts/build-app.sh
```

Then verify:

```text
[ ] CLI builds
[ ] SwiftUI app launches
[ ] tests pass
[ ] PE analyzer rejects malformed input
[ ] profile persistence works
[ ] snapshots work
[ ] restore creates automatic backup
[ ] import downgrades evidence
[ ] diagnostic output excludes private profile details
[ ] symlink input is rejected
[ ] Windows execution remains unavailable
```

---

# 31. Important Project Decisions Already Made

These should be treated as project-level decisions unless deliberately changed later.

### Decision 1
**Dimension X / DMX** is the project name.

### Decision 2
The project is open source.

### Decision 3
The repository is:

```text
aadithyya/Dimension-X
```

### Decision 4
The initial application is native SwiftUI.

### Decision 5
The CLI and GUI share the same backend.

### Decision 6
Local-first and privacy-first are core principles.

### Decision 7
A Wine prefix is not considered a security boundary.

### Decision 8
No security-control bypasses for compatibility.

### Decision 9
Windows execution stays disabled until the execution boundary is genuinely implemented and tested.

### Decision 10
Static analysis evidence must be labeled by certainty/provenance.

### Decision 11
Unsupported capabilities should be reported rather than bypassed.

### Decision 12
Production readiness requires actual tests, not documentation claims.

---

# 32. Suggested Message to Astra for the Next Step

```text
The first increment is acceptable as the foundation.

Before adding any Windows launcher, Wine prefix creation, game launcher integration, performance presets, or UI buttons for execution, move to the next engineering milestone:

DMX Execution Boundary Prototype

Do not simply add:
EXE → Wine → launch.

Instead, design and implement a real execution architecture around:

DMX GUI/CLI
→ Execution Manager
→ Policy Engine
→ Execution Broker
→ Wine Runtime
→ Windows Process

The objective of this milestone is to experimentally establish what macOS can actually enforce around a Windows process running through Wine.

Implement the architecture and tests needed to investigate:

1. Per-profile filesystem access
2. Cross-profile isolation
3. Network policy enforcement
4. Process creation/termination
5. Child-process behavior
6. Environment-variable isolation
7. Access to sensitive macOS locations
8. Device/resource access
9. Runtime and executable provenance
10. Clean process teardown
11. Crash recovery
12. Audit/diagnostic events

Do not claim that Wine prefixes provide isolation.

Do not bypass:
- Gatekeeper
- SIP
- TCC
- code signing
- quarantine
- macOS security controls

Do not implement kernel anti-cheat bypasses or unsupported driver workarounds.

Most importantly, create a capability matrix that distinguishes:

- enforceable by supported macOS mechanisms
- partially enforceable
- observable but not enforceable
- impossible to guarantee

For anything that cannot currently be enforced, do not label it "secure". Mark it explicitly as unsupported/unverified.

Keep Windows execution disabled by default until the boundary has reproducible tests demonstrating the required controls.

Also fix any build/test issues discovered in Increment 1 before extending the architecture.

Do not optimize graphics, add Steam/Epic support, or build a game launcher yet. The execution boundary is the priority.
```

---

# 33. Current Bottom Line

Dimension X has moved from a concept into a real codebase foundation.

Current state:

```text
                    DIMENSION X

        ┌───────────────────────────────┐
        │      Native SwiftUI App       │
        └───────────────┬───────────────┘
                        │
        ┌───────────────▼───────────────┐
        │        Shared DMXCore         │
        │                               │
        │ PE Analysis                   │
        │ Profiles                      │
        │ Snapshots                     │
        │ Diagnostics                   │
        └───────────────┬───────────────┘
                        │
        ┌───────────────▼───────────────┐
        │          CLI backend          │
        └───────────────────────────────┘

                EXECUTION
                    │
                    X
         intentionally unavailable
```

The project has not yet solved the hardest part:

```text
How do you execute an arbitrary Windows program through Wine
while giving DMX meaningful, tested, enforceable control over
what that Windows program can access on macOS?
```

That is now the central engineering problem.

The next milestone should therefore be the **execution-boundary prototype**, not more launcher UI.
