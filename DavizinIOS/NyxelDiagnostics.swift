import Foundation

enum NyxelErrorCode {
    static let unsupportedSystem = "NYX-001"
    static let workerUnavailable = "NYX-002"
    static let invalidConfiguration = "NYX-003"
    static let gameUnavailable = "NYX-004"
    static let containerUnavailable = "NYX-005"
    static let operationCancelled = "NYX-006"
}

/// Metadatos mínimos de la última configuración remota aceptada.
enum NyxelRemoteConfigStore {
    private static let savedAtKey = "nyxel.config.savedAt"
    private static let versionKey = "nyxel.config.version"
    private static let statusKey = "nyxel.config.status"

    static var savedAt: Date? {
        let value = UserDefaults.standard.double(forKey: savedAtKey)
        return value > 0 ? Date(timeIntervalSince1970: value) : nil
    }

    static var version: Int { UserDefaults.standard.integer(forKey: versionKey) }
    static var status: String { UserDefaults.standard.string(forKey: statusKey) ?? "Sin sincronizar" }

    static var ageDescription: String {
        guard let savedAt else { return "Nunca sincronizada" }
        let seconds = max(0, Int(Date().timeIntervalSince(savedAt)))
        if seconds < 60 { return "Hace unos segundos" }
        if seconds < 3600 { return "Hace \(seconds / 60) min" }
        if seconds < 86400 { return "Hace \(seconds / 3600) h" }
        return "Hace \(seconds / 86400) días"
    }

    static func recordAccepted(version: Int = 0) {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: savedAtKey)
        UserDefaults.standard.set(version, forKey: versionKey)
        UserDefaults.standard.set("Configuración válida", forKey: statusKey)
    }

    static func recordFailure(_ message: String) {
        UserDefaults.standard.set(message, forKey: statusKey)
    }
}
