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

        // Backup del original si no existe ya
        if fm.fileExists(atPath: destPath) && !fm.fileExists(atPath: backupPath) {
            guard (try? fm.copyItem(atPath: destPath, toPath: backupPath)) != nil else {
                return InjectorResult(success: false, message: "Error haciendo backup")
            }
        }

        // Eliminar destino antes de copiar
        if fm.fileExists(atPath: destPath) {
            try? fm.removeItem(atPath: destPath)
        }

        do {
            try fm.copyItem(atPath: sourcePath, toPath: destPath)
            try fm.setAttributes([.posixPermissions: 0o644], ofItemAtPath: destPath)
        } catch {
            return InjectorResult(success: false, message: "Error copiando: \(error.localizedDescription)")
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
        if fm.fileExists(atPath: destPath) {
            try? fm.removeItem(atPath: destPath)
        }
        do {
            try fm.copyItem(atPath: backupPath, toPath: destPath)
            try? fm.removeItem(atPath: backupPath)
            try fm.setAttributes([.posixPermissions: 0o644], ofItemAtPath: destPath)
        } catch {
            return InjectorResult(success: false, message: "Error: \(error.localizedDescription)")
        }
        return InjectorResult(success: true, message: "¡Restaurado! Cierra y abre Free Fire.")
    }
}
