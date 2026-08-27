import Foundation

struct InjectorResult {
    let success: Bool
    let message: String
}

private let kDestPath = "Documents/contentcache/Compulsory/ios/gameassetbundles/cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D"
private let kBackPath = "Documents/contentcache/Compulsory/ios/gameassetbundles/cache_res.original"

class InjectorService {

    static func checkIsInjected(bundleID: String) -> Bool {
        var err: NSString?
        guard let container = DavizinGetContainerPath(bundleID, &err) else { return false }
        return FileManager.default.fileExists(atPath: container + "/" + kBackPath)
    }

    static func inject(bundleID: String) -> InjectorResult {
        let fm = FileManager.default

        // Obtener container via MCM
        var mcmErr: NSString?
        guard let container = DavizinGetContainerPath(bundleID, &mcmErr) else {
            return InjectorResult(success: false,
                message: (mcmErr as String?) ?? "Container no encontrado")
        }

        // Verificar que tenemos el cache_res en el bundle
        guard let sourcePath = Bundle.main.path(forResource: "cache_res", ofType: nil) else {
            return InjectorResult(success: false,
                message: "cache_res no encontrado en la app")
        }

        let destPath   = container + "/" + kDestPath
        let backupPath = container + "/" + kBackPath
        let destDir    = (destPath as NSString).deletingLastPathComponent

        // Crear directorio destino si no existe
        try? fm.createDirectory(atPath: destDir,
                                withIntermediateDirectories: true)

        // Backup del original
        if fm.fileExists(atPath: destPath) && !fm.fileExists(atPath: backupPath) {
            do {
                let original = try Data(contentsOf: URL(fileURLWithPath: destPath))
                try original.write(to: URL(fileURLWithPath: backupPath))
            } catch {
                return InjectorResult(success: false,
                    message: "Error haciendo backup: \(error.localizedDescription)")
            }
        }

        // Copiar nuestro cache_res
        do {
            let sourceData = try Data(contentsOf: URL(fileURLWithPath: sourcePath))
            try sourceData.write(to: URL(fileURLWithPath: destPath), options: .atomic)
            try? fm.setAttributes([.posixPermissions: 0o644], ofItemAtPath: destPath)
        } catch {
            return InjectorResult(success: false,
                message: "Error al inyectar: \(error.localizedDescription)")
        }

        return InjectorResult(success: true,
            message: "¡Inyectado! Cierra y abre Free Fire.")
    }

    static func uninject(bundleID: String) -> InjectorResult {
        let fm = FileManager.default

        var mcmErr: NSString?
        guard let container = DavizinGetContainerPath(bundleID, &mcmErr) else {
            return InjectorResult(success: false,
                message: (mcmErr as String?) ?? "Container no encontrado")
        }

        let destPath   = container + "/" + kDestPath
        let backupPath = container + "/" + kBackPath

        guard fm.fileExists(atPath: backupPath) else {
            return InjectorResult(success: false,
                message: "No hay backup para restaurar")
        }

        do {
            let backupData = try Data(contentsOf: URL(fileURLWithPath: backupPath))
            try backupData.write(to: URL(fileURLWithPath: destPath), options: .atomic)
            try? fm.removeItem(atPath: backupPath)
            try? fm.setAttributes([.posixPermissions: 0o644], ofItemAtPath: destPath)
        } catch {
            return InjectorResult(success: false,
                message: "Error al restaurar: \(error.localizedDescription)")
        }

        return InjectorResult(success: true,
            message: "¡Restaurado! Cierra y abre Free Fire.")
    }
}
