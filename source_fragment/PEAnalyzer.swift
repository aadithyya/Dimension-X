
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


Finding(
    topic: "graphics",
    value: "\(api) may be required",
    certainty: .inferred,
    source: "Imported DLL: \(dll); backend compatibility untested"
)


let runtimeDLLs = dlls.filter {
    $0.hasPrefix("vcruntime") ||
        $0.hasPrefix("msvcp") ||
        $0.hasPrefix("msvcr")
}


if subsystem == 1 {
    blocks.append(
        "Native-subsystem image: unsupported system-level executable."
    )
}

let kernelNames: Set<String> = [
    "ntoskrnl.exe",
    "hal.dll",
    "wdfldr.sys",
]
