import Foundation

struct InjectorResult {
    let success: Bool
    let message: String
}

private let kCacheResRelative = "Documents/contentcache/Compulsory/ios/gameassetbundles/cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D"
private let kCacheResBackup   = "Documents/contentcache/Compulsory/ios/gameassetbundles/cache_res.original"

class InjectorService {

    static func isJailbroken() -> Bool { return true }

    static func findContainer(bundleID: String) -> String? {
        var errorMsg: NSString? = nil
        return DavizinGetContainerPath(bundleID, &errorMsg)
    }

    static func checkIsInjected(bundleID: String) -> Bool {
        guard let container = findContainer(bundleID: bundleID) else { return false }
        return FileManager.default.fileExists(atPath: container + "/" + kCacheResBackup)
    }

    static func inject(bundleID: String) -> InjectorResult {
        let fm = FileManager.default
        var mcmError: NSString? = nil
        guard let container = DavizinGetContainerPath(bundleID, &mcmError) else {
            return InjectorResult(success: false, message: "Error: \((mcmError as String?) ?? "desconocido")")
        }
        guard let sourcePath = Bundle.main.path(forResource: "cache_res", ofType: nil) else {
            return InjectorResult(success: false, message: "cache_res no encontrado en la app")
        }
        let destPath   = container + "/" + kCacheResRelative
        let backupPath = container + "/" + kCacheResBackup
        let destDir    = (destPath as NSString).deletingLastPathComponent

        try? fm.createDirectory(atPath: destDir, withIntermediateDirectories: true)

        // Backup del original usando escritura directa
        if fm.fileExists(atPath: destPath) && !fm.fileExists(atPath: backupPath) {
            if let originalData = try? Data(contentsOf: URL(fileURLWithPath: destPath)) {
                try? originalData.write(to: URL(fileURLWithPath: backupPath))
            }
        }

        // Escribir directamente sobreescribiendo el archivo existente
        do {
            let sourceData = try Data(contentsOf: URL(fileURLWithPath: sourcePath))
            try sourceData.write(to: URL(fileURLWithPath: destPath), options: .atomic)
        } catch {
            return InjectorResult(success: false, message: "Error escribiendo: \(error.localizedDescription)")
        }

        return InjectorResult(success: true, message: "¡Inyectado! Cierra y abre Free Fire.")
    }

    static func uninject(bundleID: String) -> InjectorResult {
        let fm = FileManager.default
        var mcmError: NSString? = nil
        guard let container = DavizinGetContainerPath(bundleID, &mcmError) else {
            return InjectorResult(success: false, message: "Error: \((mcmError as String?) ?? "desconocido")")
        }
        let destPath   = container + "/" + kCacheResRelative
        let backupPath = container + "/" + kCacheResBackup

        guard fm.fileExists(atPath: backupPath) else {
            return InjectorResult(success: false, message: "No hay backup para restaurar")
        }

        do {
            let backupData = try Data(contentsOf: URL(fileURLWithPath: backupPath))
            try backupData.write(to: URL(fileURLWithPath: destPath), options: .atomic)
            try? fm.removeItem(atPath: backupPath)
        } catch {
            return InjectorResult(success: false, message: "Error restaurando: \(error.localizedDescription)")
        }

        return InjectorResult(success: true, message: "¡Restaurado! Cierra y abre Free Fire.")
    }
}
