import Foundation
import Darwin

/// Información de dispositivo disponible mediante APIs de diagnóstico del sistema.
/// No realiza pairing, escape de sandbox ni acceso a contenedores de terceros.
struct NyxelDeviceInfo: Equatable {
    let osVersion: String
    let major: Int
    let minor: Int
    let patch: Int
    let build: String
    let machineIdentifier: String

    var compatibility: NyxelCompatibilityPolicy.Result {
        NyxelCompatibilityPolicy.evaluate(
            major: major,
            minor: minor,
            patch: patch,
            build: build
        )
    }

    static var current: NyxelDeviceInfo {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return NyxelDeviceInfo(
            osVersion: "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)",
            major: version.majorVersion,
            minor: version.minorVersion,
            patch: version.patchVersion,
            build: currentBuild,
            machineIdentifier: currentMachineIdentifier
        )
    }

    private static var currentBuild: String {
        var size: size_t = 0
        guard sysctlbyname("kern.osversion", nil, &size, nil, 0) == 0, size > 0 else {
            return "Unknown"
        }

        var value = [CChar](repeating: 0, count: size)
        guard sysctlbyname("kern.osversion", &value, &size, nil, 0) == 0 else {
            return "Unknown"
        }
        return String(cString: value)
    }

    private static var currentMachineIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return Mirror(reflecting: systemInfo.machine).children.reduce(into: "") { result, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            result.append(Character(UnicodeScalar(UInt8(value))))
        }
    }
}
