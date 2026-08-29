import Foundation
import CryptoKit

struct InjectorResult {
    let success: Bool
    let message: String
}

private let kDestPath = "Documents/contentcache/Compulsory/ios/gameassetbundles/cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D"
private let kBackPath = "Documents/contentcache/Compulsory/ios/gameassetbundles/cache_res.original"

// Base del Worker que sirve los cache_res desde KV.
private let kCacheBaseURL = "https://dz.davidporfirio17.workers.dev"

// Debe coincidir EXACTO con SIGN_SECRET del Worker (variable de entorno en Cloudflare).
private let kSignSecret = "78ae85be57c27ab1525e0af061fa4ce012e2f2b1484209bf64dc8834be7e0fc4"

class InjectorService {

    /// Ruta del Worker para cada modo (descarga desde KV).
    private static func remoteSlot(for mode: ARIFIMode) -> String {
        switch mode {
        case .drag:    return "drag"
        case .pecho:   return "pecho"
        case .body100: return "body100"
        }
    }

    /// Deriva la clave AES-256 igual que el Worker: SHA-256 de "dzcache:" + secreto.
    private static func cacheKey() -> SymmetricKey {
        let material = Data(("dzcache:" + kSignSecret).utf8)
        let digest = SHA256.hash(data: material)
        return SymmetricKey(data: Data(digest))
    }

    /// Descifra un blob AES-GCM con formato [12 bytes IV][ciphertext+tag].
    /// Devuelve nil si el blob no es válido o la clave no corresponde.
    private static func decrypt(_ blob: Data) -> Data? {
        guard blob.count > 12 + 16 else { return nil }
        do {
            // blob = [12 IV][ciphertext][16 tag] -> es exactamente el formato 'combined' de CryptoKit
            let sealed = try AES.GCM.SealedBox(combined: blob)
            let plain = try AES.GCM.open(sealed, using: cacheKey())
            return plain
        } catch {
            return nil
        }
    }

    /// Descarga el cache_res del modo desde el Worker. Devuelve el contenido YA DESCIFRADO.
    private static func downloadResource(for mode: ARIFIMode, key: String, hwid: String) -> Data? {
        guard !key.isEmpty else { return nil }
        guard let url = URL(string: "\(kCacheBaseURL)/cache/\(remoteSlot(for: mode))") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(key, forHTTPHeaderField: "X-DZ-Key")
        request.setValue(hwid, forHTTPHeaderField: "X-DZ-HWID")
        request.timeoutInterval = 20

        let semaphore = DispatchSemaphore(value: 0)
        var result: Data?

        let task = URLSession.shared.dataTask(with: request) { data, response, _ in
            defer { semaphore.signal() }
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
            guard let data = data, data.count > 28 else { return }

            // Robusto: intentamos descifrar SIEMPRE. Si el descifrado funciona,
            // el dato venia cifrado y usamos el resultado. Si falla, el dato ya
            // venia en claro y lo usamos tal cual. No dependemos del header.
            if let plain = decrypt(data) {
                result = plain
            } else {
                result = data
            }
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 22)
        return result
    }

    static func checkIsInjected(bundleID: String) -> Bool {
        var err: NSString?
        guard let container = DavizinGetContainerPath(bundleID, &err) else { return false }
        return FileManager.default.fileExists(atPath: container + "/" + kBackPath)
    }

    static func inject(bundleID: String, mode: ARIFIMode, key: String, hwid: String) -> InjectorResult {
        let fm = FileManager.default

        var mcmErr: NSString?
        guard let container = DavizinGetContainerPath(bundleID, &mcmErr) else {
            return InjectorResult(success: false,
                message: (mcmErr as String?) ?? "Container no encontrado")
        }

        // Descargar + descifrar el cache_res del modo (unica fuente).
        guard let finalData = downloadResource(for: mode, key: key, hwid: hwid),
              finalData.count > 1000 else {
            return InjectorResult(success: false,
                message: "No se pudo obtener el recurso. Revisa tu conexión e inténtalo de nuevo.")
        }

        let destPath   = container + "/" + kDestPath
        let backupPath = container + "/" + kBackPath
        let destDir    = (destPath as NSString).deletingLastPathComponent

        try? fm.createDirectory(atPath: destDir,
                                withIntermediateDirectories: true)

        if fm.fileExists(atPath: destPath) && !fm.fileExists(atPath: backupPath) {
            do {
                let original = try Data(contentsOf: URL(fileURLWithPath: destPath))
                try original.write(to: URL(fileURLWithPath: backupPath))
            } catch {
                return InjectorResult(success: false,
                    message: "Error haciendo backup: \(error.localizedDescription)")
            }
        }

        do {
            try finalData.write(to: URL(fileURLWithPath: destPath), options: .atomic)
            try? fm.setAttributes([.posixPermissions: 0o644], ofItemAtPath: destPath)
        } catch {
            return InjectorResult(success: false,
                message: "Error al inyectar: \(error.localizedDescription)")
        }

        return InjectorResult(success: true,
            message: "¡\(mode.rawValue) inyectado! Cierra y abre Free Fire.")
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
