import Foundation

struct InjectorResult {
    let success: Bool
    let message: String
}

// Rutas del cache_res dentro del contenedor de Free Fire
private let kCacheResRelative = "Documents/contentcache/Compulsory/ios/gameassetbundles/cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D"
private let kCacheResBackup  = "Documents/contentcache/Compulsory/ios/gameassetbundles/cache_res.original"

// Rutas de contenedores según tipo de jailbreak
private let kContainerPaths = [
    "/var/mobile/Containers/Data/Application",           // Rootful
    "/var/jb/var/mobile/Containers/Data/Application",   // Rootless (Dopamine, etc.)
    "/private/var/mobile/Containers/Data/Application",  // Alternativo
]

class InjectorService {
    
    // MARK: - Jailbreak detection
    static func isJailbroken() -> Bool {
        let jbPaths = [
            "/bin/bash", "/usr/sbin/sshd", "/etc/apt",
            "/var/jb", "/var/jb/usr/bin/sileo",
            "/Applications/Cydia.app", "/usr/libexec/ssh-keysign"
        ]
        for path in jbPaths {
            if FileManager.default.fileExists(atPath: path) { return true }
        }
        // Test escritura fuera del sandbox
        let testPath = "/private/jb_davizin_test.txt"
        do {
            try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: testPath)
            return true
        } catch { }
        return false
    }
    
    // MARK: - Find container
    static func findContainer(bundleID: String) -> String? {
        let fm = FileManager.default
        
        for basePath in kContainerPaths {
            guard let uuids = try? fm.contentsOfDirectory(atPath: basePath) else { continue }
            
            for uuid in uuids {
                let metaPath = "\(basePath)/\(uuid)/.com.apple.mobile_container_manager.metadata.plist"
                guard let meta = NSDictionary(contentsOfFile: metaPath),
                      let id = meta["MCMMetadataIdentifier"] as? String,
                      id == bundleID else { continue }
                return "\(basePath)/\(uuid)"
            }
        }
        return nil
    }
    
    // MARK: - Inject
    static func inject(bundleID: String) -> InjectorResult {
        let fm = FileManager.default
        
        // 1. Verificar jailbreak
        guard isJailbroken() else {
            return InjectorResult(success: false, message: "Requiere jailbreak activo")
        }
        
        // 2. Encontrar contenedor del juego
        guard let container = findContainer(bundleID: bundleID) else {
            return InjectorResult(success: false, message: "Free Fire no encontrado. ¿Está instalado?")
        }
        
        // 3. Buscar cache_res dentro del bundle de la app
        guard let sourcePath = Bundle.main.path(forResource: "cache_res", ofType: nil) else {
            return InjectorResult(success: false, message: "cache_res no encontrado en la app")
        }
        
        let destPath   = container + "/" + kCacheResRelative
        let backupPath = container + "/" + kCacheResBackup
        let destDir    = (destPath as NSString).deletingLastPathComponent
        
        // 4. Crear directorio destino
        try? fm.createDirectory(atPath: destDir, withIntermediateDirectories: true)
        
        // 5. Backup del original (si no existe ya)
        if fm.fileExists(atPath: destPath) && !fm.fileExists(atPath: backupPath) {
            do {
                try fm.copyItem(atPath: destPath, toPath: backupPath)
            } catch {
                return InjectorResult(success: false, message: "Error haciendo backup: \(error.localizedDescription)")
            }
        }
        
        // 6. Matar el juego si está corriendo
        killApp(bundleID: bundleID)
        Thread.sleep(forTimeInterval: 0.8)
        
        // 7. Reemplazar cache_res
        if fm.fileExists(atPath: destPath) {
            try? fm.removeItem(atPath: destPath)
        }
        
        do {
            try fm.copyItem(atPath: sourcePath, toPath: destPath)
            try fm.setAttributes([.posixPermissions: 0o644], ofItemAtPath: destPath)
        } catch {
            return InjectorResult(success: false, message: "Error inyectando: \(error.localizedDescription)")
        }
        
        return InjectorResult(success: true, message: "¡Inyectado! Abre Free Fire ahora.")
    }
    
    // MARK: - Uninject
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
        
        // Verificar que existe el backup
        guard fm.fileExists(atPath: backupPath) else {
            return InjectorResult(success: false, message: "No hay backup original para restaurar")
        }
        
        // Matar el juego
        killApp(bundleID: bundleID)
        Thread.sleep(forTimeInterval: 0.8)
        
        // Eliminar el mod
        if fm.fileExists(atPath: destPath) {
            try? fm.removeItem(atPath: destPath)
        }
        
        // Restaurar el backup
        do {
            try fm.copyItem(atPath: backupPath, toPath: destPath)
            try? fm.removeItem(atPath: backupPath) // Eliminar el backup después de restaurar
            try fm.setAttributes([.posixPermissions: 0o644], ofItemAtPath: destPath)
        } catch {
            return InjectorResult(success: false, message: "Error restaurando: \(error.localizedDescription)")
        }
        
        return InjectorResult(success: true, message: "¡Restaurado! El original está activo.")
    }
    
    // MARK: - Kill app
    private static func killApp(bundleID: String) {
        let appName = bundleID.components(separatedBy: ".").last ?? bundleID
        var pid: pid_t = 0
        let cmd = "killall -9 \"\(appName)\""
        var args: [UnsafeMutablePointer<CChar>?] = [
            strdup("/bin/bash"),
            strdup("-c"),
            strdup(cmd),
            nil
        ]
        posix_spawn(&pid, "/bin/bash", nil, nil, &args, nil)
        waitpid(pid, nil, 0)
        args.forEach { free($0) }
    }
}
