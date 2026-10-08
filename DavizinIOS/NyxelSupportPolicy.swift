import Foundation
import Darwin
import UIKit

// MARK: - Device Information Utilities
enum NyxelDeviceInfo {
    static var osVersion: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }
    
    static var versionTuple: (major: Int, minor: Int, patch: Int) {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return (v.majorVersion, v.minorVersion, v.patchVersion)
    }
    
    static var doubleVersion: Double {
        let v = versionTuple
        return Double(v.major) + Double(v.minor) / 10.0
    }
    
    static var machineName: String {
        var s = utsname()
        uname(&s)
        return Mirror(reflecting: s.machine).children.reduce("") { id, e in
            guard let v = e.value as? Int8, v != 0 else { return id }
            return id + String(UnicodeScalar(UInt8(v)))
        }
    }
    
    static var displayMachineName: String {
#if targetEnvironment(simulator)
        return ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? machineName
#else
        return machineName
#endif
    }
    
    static var deviceModel: String {
        switch displayMachineName {
        // iPhone Pro models
        case "iPhone15,2": return "iPhone 14 Pro"
        case "iPhone15,3": return "iPhone 14 Pro Max"
        case "iPhone16,1": return "iPhone 15 Pro"
        case "iPhone16,2": return "iPhone 15 Pro Max"
        // iPhone standard models
        case "iPhone14,4": return "iPhone 13 mini"
        case "iPhone14,5": return "iPhone 13"
        case "iPhone15,4": return "iPhone 14"
        case "iPhone15,5": return "iPhone 14 Plus"
        case "iPhone16,3": return "iPhone 15"
        case "iPhone16,4": return "iPhone 15 Plus"
        // Fallback
        default: return displayMachineName
        }
    }
    
    static var isHomeButton: Bool {
        let sel = NSSelectorFromString("_hasHomeButton")
        return UIDevice.responds(to: sel) && (UIDevice.perform(sel)?.takeUnretainedValue() as? Bool ?? false)
    }
    
    static var osBuild: String {
        var size = 0
        guard sysctlbyname("kern.osversion", nil, &size, nil, 0) == 0, size > 0 else {
            return ""
        }

        var buffer = [CChar](repeating: 0, count: size)
        let result = buffer.withUnsafeMutableBufferPointer { pointer in
            sysctlbyname("kern.osversion", pointer.baseAddress, &size, nil, 0)
        }
        guard result == 0 else { return "" }
        return String(cString: buffer)
    }
    
    static var systemDescription: String {
        let version = versionTuple
        let versionText = "\(version.major).\(version.minor).\(version.patch)"
        let build = osBuild
        return build.isEmpty ? "iOS \(versionText)" : "iOS \(versionText) (\(build))"
    }
}

// MARK: - Nyxel Support Policy (Enhanced)
enum NyxelSupportPolicy {
    enum Status {
        case supported
        case unsupported

        var label: String { self == .supported ? "Compatible" : "No compatible" }
    }

    static let verifiedIOS17Range = "17.0–17.7.x"
    static let verifiedIOS18Range = "18.0–18.7.1"
    static let verifiedIOS26Range = "26.0–26.6.2"

    static let verifiedIOS27Builds: [(beta: Int, publicBeta: Int?, build: String)] = [
        (1, nil, "24A5355q"),
        (2, nil, "24A5370h"),
        (3, 1, "24A5380h"),
        (4, 2, "24A5390f")
    ]

    /// Builds de explotación verificados en SupportPatch. El deployment target
    /// de la app puede ser iOS 16, pero eso no convierte iOS 16 en un sistema
    /// compatible con la inyección.
    private static let verifiedBuilds: Set<String> = [
        "17.0.0|21A329", "17.0.1|21A340", "17.0.2|21A350", "17.0.2|21A351",
        "17.0.3|21A360", "17.1.0|21B74", "17.1.0|21B80", "17.1.1|21B91",
        "17.1.2|21B101", "17.2.0|21C62", "17.2.1|21C66", "17.3.0|21D50",
        "17.3.1|21D61", "17.4.0|21E219", "17.4.1|21E236", "17.4.1|21E237",
        "17.5.0|21F79", "17.5.1|21F90", "17.6.0|21G80", "17.6.1|21G93",
        "17.6.1|21G101", "17.7.0|21H16", "17.7.1|21H216", "17.7.2|21H221",
        "18.0.0|22A3354", "18.0.1|22A3370", "18.1.0|22B83", "18.1.1|22B91",
        "18.2.0|22C152", "18.2.1|22C161", "18.3.0|22D63", "18.3.1|22D72",
        "18.3.2|22D82", "18.4.0|22E240", "18.4.1|22E252", "18.5.0|22F76",
        "18.6.0|22G86", "18.6.1|22G90", "18.6.2|22G100", "18.7.0|22H20",
        "18.7.1|22H31", "18.7.2|22H124", "18.7.3|22H217", "18.7.4|22H218",
        "18.7.5|22H311", "18.7.6|22H320", "18.7.7|22H333", "18.7.7|22H340",
        "18.7.8|22H352", "18.7.9|22H355", "18.7.10|22H374",
        "26.0.0|23A341", "26.0.0|23A345", "26.0.1|23A355", "26.1.0|23B85",
        "26.2.0|23C55", "26.2.1|23C71", "26.3.0|23D127", "26.3.1|23D8133",
        "26.4.0|23E246", "26.4.1|23E254", "26.4.2|23E261", "26.5.0|23F77",
        "26.5.1|23F81", "26.5.2|23F84", "26.6.0|23G71", "26.6.1|23G83",
        "26.6.2|23G90", "26.7.0|23H24", "27.2.0|24B5084k", "27.2.0|24B5089g"
    ]

    static var currentVersion: OperatingSystemVersion {
        ProcessInfo.processInfo.operatingSystemVersion
    }

    /// Obtiene el build Darwin exacto, por ejemplo 24A5355q.
    static var currentBuild: String {
        var size = 0
        guard sysctlbyname("kern.osversion", nil, &size, nil, 0) == 0, size > 0 else {
            return ""
        }

        var buffer = [CChar](repeating: 0, count: size)
        let result = buffer.withUnsafeMutableBufferPointer { pointer in
            sysctlbyname("kern.osversion", pointer.baseAddress, &size, nil, 0)
        }
        guard result == 0 else { return "" }
        return String(cString: buffer)
    }

    static func iOS27BetaNumber(for build: String) -> Int? {
        verifiedIOS27Builds.first { $0.build == build }?.beta
    }

    static func iOS27PublicBetaNumber(for build: String) -> Int? {
        verifiedIOS27Builds.first { $0.build == build }?.publicBeta
    }

    static func supportsVerifiedSystem(major: Int, minor: Int, patch: Int, build: String) -> Bool {
        verifiedBuilds.contains("\(major).\(minor).\(patch)|\(build)")
    }

    static func isSupported(major: Int, minor: Int, patch: Int, build: String) -> Bool {
        supportsVerifiedSystem(major: major, minor: minor, patch: patch, build: build)
    }

    static var status: Status { isCurrentSystemSupported ? .supported : .unsupported }

    static var isCurrentSystemSupported: Bool {
        let version = currentVersion
        return supportsVerifiedSystem(
            major: version.majorVersion,
            minor: version.minorVersion,
            patch: version.patchVersion,
            build: currentBuild
        )
    }

    static var currentSystemDescription: String {
        NyxelDeviceInfo.systemDescription
    }

    static var supportedRangesDescription: String {
        "iOS 17.0–17.7.2 · iOS 18.0–18.7.10 · iOS 26.0–26.7.0 · iOS 27.2 builds verificados"
    }
    
    // MARK: - Device Information
    static var currentDeviceModel: String {
        NyxelDeviceInfo.deviceModel
    }
    
    static var currentMachineIdentifier: String {
        NyxelDeviceInfo.displayMachineName
    }
    
    static var hasHomeButton: Bool {
        NyxelDeviceInfo.isHomeButton
    }
    
    // MARK: - Diagnostic Information
    static func getFullSystemInfo() -> String {
        let v = currentVersion
        return """
        ═══ NYXEL SYSTEM INFO ═══
        Device: \(currentDeviceModel)
        Identifier: \(currentMachineIdentifier)
        iOS Version: \(v.majorVersion).\(v.minorVersion).\(v.patchVersion)
        Build: \(currentBuild)
        Has Home Button: \(hasHomeButton)
        Compatibility Status: \(status.label)
        Supported Range: \(supportedRangesDescription)
        ════════════════════════
        """
    }
}

// MARK: - App Logger (for debugging & diagnostics)
class NyxelLogger {
    static let shared = NyxelLogger()
    
    @Published var logEntries: [String] = []
    private var logFile: URL? {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        guard let documentsDirectory = paths.first else { return nil }
        return documentsDirectory.appendingPathComponent("nyxel_debug.log")
    }
    
    func log(_ message: String, level: String = "INFO") {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let formatted = "[\(timestamp)] [\(level)] \(message)"
        
        DispatchQueue.main.async {
            self.logEntries.append(formatted)
            if self.logEntries.count > 500 {
                self.logEntries.removeFirst(100)
            }
        }
        
        // Also write to file for persistence
        writeToFile(formatted)
    }
    
    func logInfo(_ message: String) { log(message, level: "INFO") }
    func logWarning(_ message: String) { log(message, level: "WARN") }
    func logError(_ message: String) { log(message, level: "ERROR") }
    func logSuccess(_ message: String) { log(message, level: "SUCCESS") }
    
    private func writeToFile(_ message: String) {
        guard let logFile = logFile else { return }
        let data = (message + "\n").data(using: .utf8) ?? Data()
        
        if FileManager.default.fileExists(atPath: logFile.path) {
            if let fileHandle = FileHandle(forWritingAtPath: logFile.path) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            }
        } else {
            try? data.write(to: logFile, options: .atomic)
        }
    }
    
    func getAllLogs() -> String {
        logEntries.joined(separator: "\n")
    }
    
    func clearLogs() {
        logEntries.removeAll()
        guard let logFile = logFile else { return }
        try? FileManager.default.removeItem(at: logFile)
    }
}

// MARK: - Global logging function
func nyxelLog(_ message: String, level: String = "INFO") {
    NyxelLogger.shared.log(message, level: level)
}
