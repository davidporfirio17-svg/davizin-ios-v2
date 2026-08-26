import Foundation
import Darwin

struct InjectorResult {
    let success: Bool
    let message: String
}

private let kCacheResRelative = "Documents/contentcache/Compulsory/ios/gameassetbundles/cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D"
private let kCacheResBackup   = "Documents/contentcache/Compulsory/ios/gameassetbundles/cache_res.original"

private let kContainerPaths = [
    "/var/mobile/Containers/Data/Application",
    "/var/jb/var/mobile/Containers/Data/Application",
    "/private/var/mobile/Containers/Data/Application",
]

class InjectorService {

    static func isJailbroken() -> Bool {
        let paths = ["/bin/bash","/usr/sbin/sshd","/etc/apt","/var/jb","/Applications/Cydia.app"]
        for p in paths { if FileManager.default.fileExists(atPath: p) { return true } }
        let t = "/private/jb_dz_test.txt"
        if (try? "x".write(toFile: t, atomically: true, encoding: .utf8)) != nil {
            try? FileManager.default.removeItem(atPath: t)
            return true
        }
        return false
    }

    static func findContainer(bundleID: String) -> String? {
        let fm = FileManager.default
        for base in kContainerPaths {
            guard let uuids = try? fm.contentsOfDirectory(atPath: base) else { continue }
            for uuid in uuids {
                let meta = "\(base)/\(uuid)/.com.apple.mobile_container_manager.metadata.plist"
                if let d = NSDictionary(contentsOfFile: meta),
                   d["MCMMetadataIdentifier"] as? String == bundleID {
                    return "\(base)/\(uuid)"
                }
            }
        }
        return nil
    }

    static func checkIsInjected(bundleID: String) -> Bool {
        guard let container = findContainer(bundleID: bundleID) else { return false }
        return FileManager.default.fileExists(atPath: container + "/" + kCacheResBackup)
    }

    static func inject(bundleID: String) -> InjectorResult {
        let fm = FileManager.default
        guard isJailbroken() else {
            return InjectorResult(success: false, message: "Requiere jailbreak activo")
        }
        guard let container = findContainer(bundleID: bundleID) else {
            return InjectorResult(success: false, message: "Free Fire no encontrado. ¿Está instalado?")
        }
        guard let sourcePath = Bundle.main.path(forResource: "cache_res", ofType: nil) else {
            return InjectorResult(success: false, message: "cache_res no encontrado en la app")
        }
        let destPath   = container + "/" + kCacheResRelative
        let backupPath = container + "/" + kCacheResBackup
        let destDir    = (destPath as NSString).deletingLastPathComponent
        try? fm.createDirectory(atPath: destDir, withIntermediateDirectories: true)
        if fm.fileExists(atPath: destPath) && !fm.fileExists(atPath: backupPath) {
            guard (try? fm.copyItem(atPath: destPath, toPath: backupPath)) != nil else {
                return InjectorResult(success: false, message: "Error haciendo backup del original")
            }
        }
        killApp(bundleID: bundleID)
        Thread.sleep(forTimeInterval: 0.8)
        try? fm.removeItem(atPath: destPath)
        do {
            try fm.copyItem(atPath: sourcePath, toPath: destPath)
            try fm.setAttributes([.posixPermissions: 0o644], ofItemAtPath: destPath)
        } catch {
            return InjectorResult(success: false, message: "Error inyectando: \(error.localizedDescription)")
        }
        return InjectorResult(success: true, message: "¡Inyectado! Abre Free Fire ahora.")
    }

    static func uninject(bundleID: String) -> InjectorResult {
        let fm = FileManager.default
        guard isJailbroken() else {
            return InjectorResult(success: false, message: "Requiere jailbreak activo")
        }
        guard let container = findContainer(bundleID: bundleID) else {
            return InjectorResult(success: false, message: "Free Fire no encontrado")
        }
        let destPath   = container + "/" + kCacheResRelative
        let backupPath = container + "/" + kCacheResBackup
        guard fm.fileExists(atPath: backupPath) else {
            return InjectorResult(success: false, message: "No hay backup para restaurar")
        }
        killApp(bundleID: bundleID)
        Thread.sleep(forTimeInterval: 0.8)
        try? fm.removeItem(atPath: destPath)
        do {
            try fm.copyItem(atPath: backupPath, toPath: destPath)
            try? fm.removeItem(atPath: backupPath)
            try fm.setAttributes([.posixPermissions: 0o644], ofItemAtPath: destPath)
        } catch {
            return InjectorResult(success: false, message: "Error restaurando: \(error.localizedDescription)")
        }
        return InjectorResult(success: true, message: "¡Restaurado! El original está activo.")
    }

    private static func killApp(bundleID: String) {
        let name = bundleID.components(separatedBy: ".").last ?? bundleID
        _ = system("killall -9 \"\(name)\"")
    }
}
