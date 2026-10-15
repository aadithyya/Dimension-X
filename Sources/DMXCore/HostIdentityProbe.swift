import Foundation
import Metal
import DMXModel

public enum HostIdentityProbe {

    public static func probe() -> HostIdentity {
        let (macOSVersion, macOSBuild) = getMacOSVersionAndBuild()
        let cpuArch = getCPUArchitecture()
        let chipFamily = getChipFamily()
        let metalFamily = getHighestMetalGPUFamily()
        let memoryClass = getMemoryClass()
        let x8664Exec = getX8664Execution()

        return HostIdentity(
            macOSVersion: macOSVersion,
            macOSBuild: macOSBuild,
            cpuArchitecture: cpuArch,
            chipFamily: chipFamily,
            metalGPUFamily: metalFamily,
            memoryClass: memoryClass,
            x8664Execution: x8664Exec
        )
    }

    private static func getMacOSVersionAndBuild() -> (String, String) {
        var version = "unknown"
        var build = "unknown"

        var size = 256
        var buffer = [CChar](repeating: 0, count: size)
        if sysctlbyname("kern.osproductversion", &buffer, &size, nil, 0) == 0 {
            version = String(cString: buffer)
        } else {
            let os = ProcessInfo.processInfo.operatingSystemVersion
            version = "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
        }

        size = 256
        var buildBuffer = [CChar](repeating: 0, count: size)
        if sysctlbyname("kern.osversion", &buildBuffer, &size, nil, 0) == 0 {
            build = String(cString: buildBuffer)
        }

        return (version, build)
    }

    private static func getCPUArchitecture() -> String {
        var size = 256
        var buffer = [CChar](repeating: 0, count: size)
        if sysctlbyname("hw.machine", &buffer, &size, nil, 0) == 0 {
            return String(cString: buffer)
        }
        return "arm64"
    }

    private static func getChipFamily() -> String {
        var size = 256
        var buffer = [CChar](repeating: 0, count: size)
        if sysctlbyname("machdep.cpu.brandstring", &buffer, &size, nil, 0) == 0 {
            let brand = String(cString: buffer).trimmingCharacters(in: .whitespacesAndNewlines)
            if !brand.isEmpty {
                return brand
            }
        }
        return "Apple Silicon"
    }

    private static func getHighestMetalGPUFamily() -> String {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return "unknown"
        }

        if #available(macOS 14.0, *) {
            if device.supportsFamily(.metal3) {
                return "metal3"
            }
            if device.supportsFamily(.apple8) {
                return "apple8"
            }
            if device.supportsFamily(.apple7) {
                return "apple7"
            }
        }

        if device.supportsFamily(.apple6) {
            return "apple6"
        }
        if device.supportsFamily(.mac2) {
            return "mac2"
        }

        return "metal2"
    }

    private static func getMemoryClass() -> String {
        let bytes = ProcessInfo.processInfo.physicalMemory
        let gigabytes = bytes / (1024 * 1024 * 1024)

        if gigabytes < 12 {
            return "8GB"
        } else if gigabytes < 20 {
            return "16GB"
        } else if gigabytes < 28 {
            return "24GB"
        } else {
            return "32GB+"
        }
    }

    private static func getX8664Execution() -> X8664Execution {
        // Check if Rosetta 2 runtime library or oah daemon exists
        let rosettaPath = "/Library/Apple/usr/libexec/oah/libRosettaRuntime"
        if FileManager.default.fileExists(atPath: rosettaPath) {
            return .available
        }

        var val: Int32 = 0
        var size = MemoryLayout<Int32>.size
        if sysctlbyname("sysctl.proc_translated", &val, &size, nil, 0) == 0 {
            return .available
        }

        // Check if rosetta is installed via pkgutil
        let checkProcess = Process()
        checkProcess.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        checkProcess.arguments = ["-x", "oahd"]
        do {
            try checkProcess.run()
            checkProcess.waitUntilExit()
            if checkProcess.terminationStatus == 0 {
                return .available
            }
        } catch {
            // Ignore failure
        }

        return .available // Default on Apple Silicon macOS with Rosetta available
    }
}
