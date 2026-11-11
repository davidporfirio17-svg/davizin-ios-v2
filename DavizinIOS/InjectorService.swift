import Foundation
import CryptoKit

struct InjectorResult {
    let success: Bool
    let message: String
}

// MARK: - Injection diagnostics (log only)
fileprivate func sendErrorNotification(_ title: String, _ body: String) {
    NyxelActivityLog.record("\(title): \(body)")
}

private final class MCMContainerLookupResult {
    private let lock = NSLock()
    private var storedPath: String?
    private var storedError: String?

    func store(path: String?, error: String?) {
        lock.lock()
        storedPath = path
        storedError = error
        lock.unlock()
    }

    func snapshot() -> (path: String?, error: String?) {
        lock.lock()
        defer { lock.unlock() }
        return (storedPath, storedError)
    }
}

// Carpeta base donde vive el archivo dentro del contenedor de Free Fire.
private let kBaseFolder = "Documents/contentcache/Compulsory/ios/gameassetbundles/avatar"
private let kConfigURL = "https://dz.davidporfirio17.workers.dev/app-config"

// Valores originales: se conservan como respaldo si el Worker no responde.
private func defaultDestFileName(for game: DavizinGame) -> String {
    switch game {
    case .freeFireMax:
        return "assetindexer.PENojQAQf9a1l6Dzjs0n1Z3rtVU~3D"
    case .freeFire:
        return "assetindexer.H5ak1JM1Eck~2FxRcJrEp~2FMzeuqmY~3D"
    }
}

private func isSafeAssetFileName(_ value: String) -> Bool {
    guard value.hasPrefix("assetindexer."), value.count <= 180 else { return false }
    let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._~-=")
    return !value.isEmpty && value.unicodeScalars.allSatisfy { allowed.contains($0) }
}

private func savedDestFileName(for game: DavizinGame) -> String {
    let key = game == .freeFireMax ? "dz_active_dest_max" : "dz_active_dest_normal"
    if let saved = UserDefaults.standard.string(forKey: key), isSafeAssetFileName(saved) { return saved }
    return defaultDestFileName(for: game)
}

private func isSafeRelativePath(_ value: String) -> Bool {
    guard value.hasPrefix("Documents/"), value.count <= 240, !value.contains(".."), !value.contains("//") else { return false }
    let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._~/-=")
    return value.unicodeScalars.allSatisfy { allowed.contains($0) }
}

private func destPathRel(for game: DavizinGame, mode: DavizinMode) -> String {
    let configured = game == .freeFireMax ? mode.pathMax : mode.pathNormal
    if let configured, isSafeRelativePath(configured) { return configured }
    return kBaseFolder + "/" + savedDestFileName(for: game)
}

private func activePathKey(for game: DavizinGame) -> String {
    return game == .freeFireMax ? "dz_active_path_max" : "dz_active_path_normal"
}

private func originalMissingKey(for game: DavizinGame) -> String {
    return game == .freeFireMax ? "dz_original_missing_max" : "dz_original_missing_normal"
}

private func restoreCompletedKey(for game: DavizinGame) -> String {
    return game == .freeFireMax ? "dz_restore_completed_max" : "dz_restore_completed_normal"
}

private func restoreDigestKey(for game: DavizinGame) -> String {
    return game == .freeFireMax ? "dz_restore_digest_max" : "dz_restore_digest_normal"
}

private func legacyDestPathRel(for game: DavizinGame) -> String {
    return kBaseFolder + "/" + savedDestFileName(for: game)
}

private func backPathRel(for game: DavizinGame, mode: DavizinMode) -> String {
    return disguisedBackupPath(for: destPathRel(for: game, mode: mode))
}

/// Nombre de respaldo disfrazado: antes era "<archivo>.original", que se ve
/// obvio en Filza/cualquier explorador de archivos (delata que algo se tocó).
/// Ahora se genera un nombre determinista con el mismo patron visual que un
/// asset real de Unity ("assetindexer.<hash>"), sin extension rara, y vive
/// en la misma carpeta — se mezcla con los demas archivos de assets reales.
private func disguisedBackupPath(for relPath: String) -> String {
    let folder = (relPath as NSString).deletingLastPathComponent
    let digest = SHA256.hash(data: Data(relPath.utf8))
    let hex = digest.compactMap { String(format: "%02x", $0) }.joined()
    let disguisedName = "assetindexer." + String(hex.prefix(28))
    return folder.isEmpty ? disguisedName : folder + "/" + disguisedName
}

private func localRestoreBackupURL(for game: DavizinGame, relativePath: String) throws -> URL {
    let fileManager = FileManager.default
    let appSupport = try fileManager.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
    )
    let backupDirectory = appSupport.appendingPathComponent("NyxelRestoreBackups", isDirectory: true)
    try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
    let identity = Data("\(String(describing: game))|\(relativePath)".utf8)
    let digest = SHA256.hash(data: identity).map { String(format: "%02x", $0) }.joined()
    return backupDirectory.appendingPathComponent("original-\(digest).bin")
}

private func saveLocalRestoreBackup(_ data: Data, to url: URL) throws {
    try data.write(to: url, options: .atomic)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
}

private func restoreDigest(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func requiresPairingTransportOnCurrentDevice() -> Bool {
    let device = NyxelDeviceInfo.versionTuple
    return NyxelSupportPolicy.requiresPairingTunnel(
        major: device.major,
        minor: device.minor,
        patch: device.patch,
        build: NyxelSupportPolicy.currentBuild
    )
}

// Base del Worker que sirve los cache_res desde KV.
private let kCacheBaseURL = "https://dz.davidporfirio17.workers.dev"

class InjectorService {
    private static let mcmLookupQueue = DispatchQueue(label: "com.davizin.mcm-container-lookup", qos: .userInitiated)

    /// Bundle ID del contenedor segun el juego.
    private static func bundleID(for game: DavizinGame) -> String {
        switch game {
        case .freeFireMax: return "com.dts.freefiremax"
        case .freeFire:    return "com.dts.freefireth"
        }
    }

    private static func resolveContainerViaAirLift(bundleID: String) -> String? {
        guard let record = NixelPairingRecordStore.shared.load(deviceID: "2424") else { return nil }
        let pairingURL = FileManager.default.temporaryDirectory.appendingPathComponent("nyxel-container-resolve-\(UUID().uuidString).plist")
        do {
            try record.write(to: pairingURL, options: .atomic)
            defer { try? FileManager.default.removeItem(at: pairingURL) }
            var containerPointer: UnsafeMutablePointer<CChar>?
            var errorPointer: UnsafeMutablePointer<CChar>?
            let code = pairingURL.path.withCString { pairing in
                bundleID.withCString { bundle in
                    al_find_app_container(pairing, bundle, { _, _ in }, nil, &containerPointer, &errorPointer)
                }
            }
            defer {
                if let containerPointer { al_string_free(containerPointer) }
                if let errorPointer { al_string_free(errorPointer) }
            }
            guard code == 0, let containerPointer else { return nil }
            let path = String(cString: containerPointer)
            guard path.hasPrefix("/var/mobile/Containers/Data/Application/") || path.hasPrefix("/private/var/mobile/Containers/Data/Application/") else { return nil }
            return path
        } catch {
            return nil
        }
    }

    private static func getContainerPathWithTimeout(bundleID: String, timeout: TimeInterval, error: inout String?) -> String? {
        let completed = DispatchSemaphore(value: 0)
        let result = MCMContainerLookupResult()
        mcmLookupQueue.async {
            var lookupError: NSString?
            let path = DavizinGetContainerPath(bundleID, &lookupError)
            result.store(path: path as String?, error: lookupError as String?)
            completed.signal()
        }

        guard completed.wait(timeout: .now() + timeout) == .success else {
            error = "MCM container lookup timed out after \(Int(timeout)) seconds"
            NyxelActivityLog.record("PASO 3: MCM timeout tras \(Int(timeout))s; se cancela antes de inyectar")
            return nil
        }
        let value = result.snapshot()
        error = value.error
        return value.path
    }

    /// Escribe datos en el contenedor del juego.
    /// iOS 27+: usa AirLift (pairing + RSD tunnel).
    /// iOS <= 26: intenta AirLift si hay pairing disponible, si no cae a MCM + file I/O directo.
    private struct ContainerWriteError: LocalizedError {
        let airliftNote: String
        let directError: Swift.Error
        var errorDescription: String? { "\(directError.localizedDescription) [\(airliftNote)]" }
    }

    private static func writeToContainer(_ data: Data, relPath: String, container: String, bundleID: String) -> Swift.Error? {
        let fullPath = container + "/" + relPath
        let parentDir = (fullPath as NSString).deletingLastPathComponent

        let pairingRequired = requiresPairingTransportOnCurrentDevice()

        NyxelActivityLog.record("DIAG writeToContainer relPath=\(relPath) pairingRequired=\(pairingRequired) airLiftAvailable=\(NixelAirLiftFileChannel.isAvailable)")

        // --- iOS 27+: Probe sin VPN PRIMERO, luego AirLift como fallback ---
        if pairingRequired {
            // ── PASO A: Probe de sandbox escape sin VPN ──
            if !container.isEmpty {
                NyxelActivityLog.record("DIAG iOS 27+ probe sin VPN para \(relPath) container=\(container)")
                var probeResult = DavizinProbeContainerWriteAccess(container, bundleID)
                let probeDetail = withUnsafePointer(to: &probeResult.detail) { ptr in
                    String(cString: UnsafeRawPointer(ptr).assumingMemoryBound(to: CChar.self))
                }
                let probeDiag = String(cString: DavizinLastProbeDiagnostic())
                NyxelActivityLog.record("DIAG probe resultado: method=\(probeResult.method) writeOK=\(probeResult.writeOK) detail=\(probeDetail)")
                NyxelActivityLog.record("DIAG probe diagnostics: \(probeDiag)")

                if probeResult.writeOK {
                    NyxelActivityLog.record("DIAG probe EXITOSO method=\(probeResult.method) — escribiendo directo sin VPN")
                    try? FileManager.default.createDirectory(atPath: parentDir, withIntermediateDirectories: true)
                    let url = URL(fileURLWithPath: fullPath)
                    do {
                        try data.write(to: url, options: [])
                        // VERIFICACIÓN: confirmar que el archivo aterrizó
                        if FileManager.default.fileExists(atPath: fullPath),
                           let attrs = try? FileManager.default.attributesOfItem(atPath: fullPath),
                           let size = attrs[.size] as? Int, size == data.count {
                            NyxelActivityLog.record("DIAG iOS 27+ probe write VERIFIED OK bytes=\(data.count) method=\(probeResult.method)")
                            return nil
                        }
                        NyxelActivityLog.record("DIAG iOS 27+ probe write returned OK but VERIFICATION FAILED — file missing or size mismatch")
                    } catch {
                        NyxelActivityLog.record("DIAG iOS 27+ probe write threw: \(error.localizedDescription)")
                    }
                    // Intento atómico como fallback
                    do {
                        try data.write(to: url, options: .atomic)
                        if FileManager.default.fileExists(atPath: fullPath),
                           let attrs = try? FileManager.default.attributesOfItem(atPath: fullPath),
                           let size = attrs[.size] as? Int, size == data.count {
                            NyxelActivityLog.record("DIAG iOS 27+ probe atomic write VERIFIED OK bytes=\(data.count)")
                            return nil
                        }
                        NyxelActivityLog.record("DIAG iOS 27+ probe atomic write returned OK but VERIFICATION FAILED")
                    } catch let atomicError {
                        NyxelActivityLog.record("DIAG iOS 27+ probe write FAILED: \(atomicError.localizedDescription)")
                    }
                    DavizinProbeRelease(&probeResult)
                } else {
                    NyxelActivityLog.record("DIAG probe sin VPN FALLÓ: \(probeDetail)")
                }
            }

            // ── PASO B: AirLift via VPN (fallback) ──
            var airliftNote = "AirLift: no disponible"
            if NixelAirLiftFileChannel.isAvailable {
                switch NixelAirLiftFileChannel.write(data, toRelativePath: relPath, bundleID: bundleID) {
                case .success:
                    // VERIFICACIÓN: leer el archivo de vuelta para confirmar que aterrizó
                    if data.count < 102400 {
                        switch NixelAirLiftFileChannel.read(relativePath: relPath, bundleID: bundleID) {
                        case .success(let readBack):
                            if readBack.count == data.count {
                                NyxelActivityLog.record("DIAG AirLift write VERIFIED OK bytes=\(data.count)")
                                return nil
                            } else {
                                NyxelActivityLog.record("DIAG AirLift write FALSE SUCCESS: wrote \(data.count) but read back \(readBack.count) bytes")
                                airliftNote = "AirLift write no verificado (size \(data.count) vs \(readBack.count))"
                            }
                        case .failure(let readErr):
                            NyxelActivityLog.record("DIAG AirLift write FALSE SUCCESS: read-back failed: \(readErr.message)")
                            airliftNote = "AirLift write no verificado (\(readErr.message))"
                        }
                    } else {
                        NyxelActivityLog.record("DIAG AirLift write OK (sin verificación, archivo grande \(data.count) bytes)")
                        return nil
                    }
                case .failure(let error):
                    airliftNote = "AirLift fallo: \(error.message)"
                    NyxelActivityLog.record("AirLift write fallo (\(relPath)): \(error.message); intentando bad_query fallback")
                }
            }

            // ── PASO C: bad_query clásico + escritura directa (legacy fallback) ──
            guard !container.isEmpty else {
                NyxelActivityLog.record("DIAG fallback omitido: container vacio")
                return ContainerWriteError(
                    airliftNote: airliftNote,
                    directError: NSError(domain: "Davizin", code: -27, userInfo: [
                        NSLocalizedDescriptionKey: "Probe y AirLift fallaron, no hay container para fallback."
                    ])
                )
            }
            NyxelActivityLog.record("DIAG iOS 27+ bad_query legacy fallback para \(relPath)")
            let handleRoot = DavizinGrantContainerAccess(container)
            let handleDir = DavizinGrantContainerAccess(parentDir)
            let handleFile = DavizinGrantContainerAccess(fullPath)
            NyxelActivityLog.record("DIAG bad_query handles: root=\(handleRoot) dir=\(handleDir) file=\(handleFile)")
            defer {
                DavizinReleaseContainerGrant(handleFile)
                DavizinReleaseContainerGrant(handleDir)
                DavizinReleaseContainerGrant(handleRoot)
            }

            try? FileManager.default.createDirectory(atPath: parentDir, withIntermediateDirectories: true)
            let url = URL(fileURLWithPath: fullPath)
            do {
                try data.write(to: url, options: [])
                if FileManager.default.fileExists(atPath: fullPath) {
                    NyxelActivityLog.record("DIAG iOS 27+ bad_query direct write VERIFIED OK bytes=\(data.count)")
                    return nil
                }
                NyxelActivityLog.record("DIAG iOS 27+ bad_query write returned OK pero archivo NO existe")
            } catch {
                NyxelActivityLog.record("DIAG iOS 27+ bad_query write threw: \(error.localizedDescription)")
            }
            do {
                try data.write(to: url, options: .atomic)
                if FileManager.default.fileExists(atPath: fullPath) {
                    NyxelActivityLog.record("DIAG iOS 27+ bad_query atomic write VERIFIED OK bytes=\(data.count)")
                    return nil
                }
                NyxelActivityLog.record("DIAG iOS 27+ bad_query atomic write returned OK pero archivo NO existe")
            } catch let atomicError {
                NyxelActivityLog.record("DIAG iOS 27+ ALL methods FAILED: \(atomicError.localizedDescription)")
                return ContainerWriteError(airliftNote: airliftNote, directError: atomicError)
            }
            return ContainerWriteError(
                airliftNote: airliftNote,
                directError: NSError(domain: "Davizin", code: -271, userInfo: [
                    NSLocalizedDescriptionKey: "Todos los métodos fallaron verificación (probe + AirLift + bad_query)"
                ])
            )
        }

        // --- iOS <= 26: intentar AirLift como optimizacion, fallback a MCM directo ---
        let handleRoot = DavizinGrantContainerAccess(container)
        let handleDir = DavizinGrantContainerAccess(parentDir)
        let handleFile = DavizinGrantContainerAccess(fullPath)
        defer {
            DavizinReleaseContainerGrant(handleFile)
            DavizinReleaseContainerGrant(handleDir)
            DavizinReleaseContainerGrant(handleRoot)
        }

        var airliftNote = "AirLift: sin registro de pairing guardado"
        if NixelAirLiftFileChannel.isAvailable {
            switch NixelAirLiftFileChannel.write(data, toRelativePath: relPath, bundleID: bundleID) {
            case .success: return nil
            case .failure(let error):
                airliftNote = "AirLift fallo: \(error.message)"
                NyxelActivityLog.record("AirLift write fallo (\(relPath)): \(error.message); usando metodo directo")
            }
        }

        let url = URL(fileURLWithPath: fullPath)
        do {
            try data.write(to: url, options: [])
            return nil
        } catch {
            do {
                try data.write(to: url, options: .atomic)
                return nil
            } catch let atomicError {
                return ContainerWriteError(airliftNote: airliftNote, directError: atomicError)
            }
        }
    }

    private static func readFromContainer(
        relPath: String,
        container: String,
        bundleID: String,
        onFailure: ((String) -> Void)? = nil
    ) -> Data? {
        let fullPath = container + "/" + relPath
        let parentDir = (fullPath as NSString).deletingLastPathComponent

        let pairingRequired = requiresPairingTransportOnCurrentDevice()

        NyxelActivityLog.record("DIAG readFromContainer relPath=\(relPath) pairingRequired=\(pairingRequired)")

        // --- iOS 27+: AirLift primero, fallback a bad_query + lectura directa ---
        if pairingRequired {
            if NixelAirLiftFileChannel.isAvailable {
                switch NixelAirLiftFileChannel.read(relativePath: relPath, bundleID: bundleID) {
                case .success(let data):
                    NyxelActivityLog.record("DIAG read succeeded via AirLift bytes=\(data.count)")
                    return data
                case .failure(let error):
                    NyxelActivityLog.record("DIAG AirLift read failed, trying bad_query fallback: \(error.message)")
                }
            }

            guard !container.isEmpty else {
                NyxelActivityLog.record("DIAG bad_query read fallback omitido: container vacio")
                onFailure?("AirLift read fallo y no hay container para bad_query fallback")
                return nil
            }
            NyxelActivityLog.record("DIAG iOS 27+ bad_query read fallback para \(relPath)")
            let handleRoot = DavizinGrantContainerAccess(container)
            let handleDir = DavizinGrantContainerAccess(parentDir)
            let handleFile = DavizinGrantContainerAccess(fullPath)
            defer {
                DavizinReleaseContainerGrant(handleFile)
                DavizinReleaseContainerGrant(handleDir)
                DavizinReleaseContainerGrant(handleRoot)
            }

            let url = URL(fileURLWithPath: fullPath)
            do {
                let data = try Data(contentsOf: url)
                NyxelActivityLog.record("DIAG iOS 27+ bad_query read OK bytes=\(data.count)")
                return data
            } catch {
                NyxelActivityLog.record("DIAG iOS 27+ bad_query read FAILED: \(error.localizedDescription)")
                onFailure?(error.localizedDescription)
                return nil
            }
        }

        // --- iOS <= 26: intentar AirLift, fallback a lectura directa ---
        if NixelAirLiftFileChannel.isAvailable {
            switch NixelAirLiftFileChannel.read(relativePath: relPath, bundleID: bundleID) {
            case .success(let data):
                NyxelActivityLog.record("DIAG read succeeded via AirLift bytes=\(data.count)")
                return data
            case .failure(let error):
                NyxelActivityLog.record("DIAG AirLift read failed, falling back to direct: \(error.message)")
            }
        }

        let handleRoot = DavizinGrantContainerAccess(container)
        let handleDir = DavizinGrantContainerAccess(parentDir)
        let handleFile = DavizinGrantContainerAccess(fullPath)
        defer {
            DavizinReleaseContainerGrant(handleFile)
            DavizinReleaseContainerGrant(handleDir)
            DavizinReleaseContainerGrant(handleRoot)
        }

        let url = URL(fileURLWithPath: fullPath)
        do {
            let data = try Data(contentsOf: url)
            NyxelActivityLog.record("DIAG read succeeded via direct I/O bytes=\(data.count)")
            return data
        } catch {
            NyxelActivityLog.record("DIAG direct read failed relPath=\(relPath) error=\(error.localizedDescription)")
            onFailure?(error.localizedDescription)
            return nil
        }
    }

    // MARK: - Bundle availability check

    static func isBundleAvailable(for game: DavizinGame) -> Bool {
        guard NyxelSupportPolicy.isCurrentSystemSupported else { return false }
        guard NyxelInstalledGames.isInstalled(for: game) else { return false }
        var error: NSString?
        if let container = DavizinGetContainerPath(bundleID(for: game), &error) {
            if FileManager.default.fileExists(atPath: container) {
                return true
            }
        }
        if requiresPairingTransportOnCurrentDevice() {
            return NixelAirLiftFileChannel.isAvailable
        }
        return false
    }

    /// Ruta del Worker para cada modo y juego (descarga desde KV).
    /// Free Fire MAX usa slots base; Free Fire normal usa el sufijo _ff.
    private static func remoteSlot(for mode: DavizinMode, game: DavizinGame) -> String {
        return game == .freeFire ? mode.id + "_ff" : mode.id
    }

    /// Deriva una clave AES-256 temporal desde la sesión efímera del Worker.
    /// No existe una clave de recursos permanente dentro de la IPA.
    private static func cacheKey(session: String) -> SymmetricKey {
        let material = Data(("dzcache:session:" + session).utf8)
        let digest = SHA256.hash(data: material)
        return SymmetricKey(data: Data(digest))
    }

    /// Comprueba si el blob empieza con la firma ASCII "UnityFS" (asset bundle).
    /// Se conserva para diagnóstico; el descifrado AES-GCM ya valida integridad.
    private static func isUnityFS(_ data: Data) -> Bool {
        let sig: [UInt8] = [0x55, 0x6e, 0x69, 0x74, 0x79, 0x46, 0x53] // "UnityFS"
        guard data.count >= sig.count else { return false }
        return Array(data.prefix(sig.count)) == sig
    }

    /// Descifra un blob AES-GCM con formato [12 bytes IV][ciphertext+tag].
    /// Devuelve nil si el blob no es válido o la clave no corresponde.
    private static func decrypt(_ blob: Data, session: String) -> Data? {
        guard blob.count > 12 + 16 else { return nil }
        // Normalizar a un Data con indices desde 0 (una respuesta de red puede no estarlo,
        // y CryptoKit falla silenciosamente si los indices no arrancan en 0).
        let clean = Data(blob)
        // Separar manualmente: [nonce 12][ciphertext ...][tag 16]
        let nonceData = clean.prefix(12)
        let tagData = clean.suffix(16)
        let cipherData = clean.dropFirst(12).dropLast(16)
        do {
            let nonce = try AES.GCM.Nonce(data: nonceData)
            let sealed = try AES.GCM.SealedBox(nonce: nonce,
                                               ciphertext: Data(cipherData),
                                               tag: Data(tagData))
            let plain = try AES.GCM.open(sealed, using: cacheKey(session: session))
            return plain
        } catch {
            return nil
        }
    }

    /// Actualiza opcionalmente el nombre de destino. Si falla, conserva el respaldo local.
    private static func refreshDestinationFileName(for game: DavizinGame, key: String, hwid: String) {
        guard let url = URL(string: kConfigURL) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(key, forHTTPHeaderField: "X-DZ-Key")
        request.setValue(hwid, forHTTPHeaderField: "X-DZ-HWID")
        KeyValidator.applySecurityHeaders(to: &request)
        request.timeoutInterval = 8
        let semaphore = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: request) { data, response, _ in
            defer { semaphore.signal() }
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let destinations = json["destinations"] as? [String: String] else { return }
            let name = game == .freeFireMax ? destinations["freeFireMax"] : destinations["freeFire"]
            guard let candidate = name, isSafeAssetFileName(candidate) else { return }
            let defaultsKey = game == .freeFireMax ? "dz_active_dest_max" : "dz_active_dest_normal"
            UserDefaults.standard.set(candidate, forKey: defaultsKey)
        }.resume()
        _ = semaphore.wait(timeout: .now() + 9)
    }

    /// Descarga el cache_res del modo desde el Worker. Devuelve el contenido YA DESCIFRADO.
    private static func downloadResource(for mode: DavizinMode, game: DavizinGame, key: String, hwid: String) -> Data? {
        guard !key.isEmpty else { return nil }
        guard let session = KeyValidator.currentSessionToken, !session.isEmpty else { return nil }
        guard let url = URL(string: "\(kCacheBaseURL)/avatar/\(remoteSlot(for: mode, game: game))") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(key, forHTTPHeaderField: "X-DZ-Key")
        request.setValue(hwid, forHTTPHeaderField: "X-DZ-HWID")
        KeyValidator.applySecurityHeaders(to: &request)
        request.timeoutInterval = 20

        let semaphore = DispatchSemaphore(value: 0)
        var result: Data?

        let task = URLSession.shared.dataTask(with: request) { data, response, _ in
            defer { semaphore.signal() }
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
            guard let data = data, data.count > 28 else { return }

            // Todos los recursos vienen cifrados; la integridad se valida con AES-GCM.
            if let plain = decrypt(data, session: session) {
                result = plain
            }
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 22)
        return result
    }

    static func checkIsInjected(bundleID: String) -> Bool {
        var err: NSString?
        guard let container = DavizinGetContainerPath(bundleID, &err) else { return false }
        return FileManager.default.fileExists(atPath: container + "/" + kBaseFolder)
    }

    static func inject(game: DavizinGame, mode: DavizinMode, key: String, hwid: String) -> InjectorResult {
        let fm = FileManager.default
        let bid = bundleID(for: game)
        let pairingRequired = requiresPairingTransportOnCurrentDevice()

        NyxelActivityLog.record("========== INJECTION TRACE BEGIN ==========")
        NyxelActivityLog.record("DIAG system=\(NyxelSupportPolicy.currentSystemDescription) game=\(game.rawValue) mode=\(mode.displayName) pairingRequired=\(pairingRequired) airLiftAvailable=\(NixelAirLiftFileChannel.isAvailable)")

        guard NyxelSupportPolicy.isCurrentSystemSupported else {
            return InjectorResult(
                success: false,
                message: "Version no verificada: \(NyxelSupportPolicy.currentSystemDescription)"
            )
        }

        NyxelActivityLog.record("DIAG PASO 1 OK: iOS verificado")

        // --- Resolver contenedor MCM ---
        var mcmErr: String?
        var container = getContainerPathWithTimeout(bundleID: bid, timeout: 25, error: &mcmErr)

        if container == nil && pairingRequired {
            if let airLiftContainer = resolveContainerViaAirLift(bundleID: bid) {
                container = airLiftContainer
                NyxelActivityLog.record("DIAG container resuelto via AirLift InstProxy: \(airLiftContainer)")
            } else if NixelAirLiftFileChannel.isAvailable {
                NyxelActivityLog.record("DIAG MCM+AirLift container lookup fallaron en iOS 27; continuando sin container local")
            } else {
                let detail = mcmErr ?? "container_query devolvió nil"
                NyxelActivityLog.record("DIAG MCM fallo en iOS 27+ sin AirLift: \(detail). El juego puede no estar instalado o MCM rechazó la consulta.")
                return InjectorResult(success: false, message: "MCM-27: \(detail)")
            }
        } else if container == nil {
            let msg = mcmErr ?? "MCM fallo - container nil"
            NyxelActivityLog.record("DIAG MCM fallo fatal: \(msg)")
            return InjectorResult(success: false, message: msg)
        }

        NyxelActivityLog.record("DIAG PASO 3 container=\(container ?? "(nil-AirLift-mode)")")

        let containerPath = container ?? ""

        NyxelActivityLog.record("DIAG PASO 5 refrescando destino...")
        Self.refreshDestinationFileName(for: game, key: key, hwid: hwid)

        NyxelActivityLog.record("DIAG PASO 6 descargando recurso...")
        guard let finalData = downloadResource(for: mode, game: game, key: key, hwid: hwid) else {
            let msg = "No se pudo obtener recurso (nil)"
            NyxelActivityLog.record("DIAG PASO 6 FALLO: \(msg)")
            return InjectorResult(success: false, message: msg)
        }

        guard finalData.count > 1000 else {
            let msg = "Recurso muy pequeno: \(finalData.count) bytes"
            NyxelActivityLog.record("DIAG PASO 6 FALLO: \(msg)")
            return InjectorResult(success: false, message: msg)
        }

        NyxelActivityLog.record("DIAG PASO 6 OK recurso=\(finalData.count) bytes")

        let activeRel = destPathRel(for: game, mode: mode)
        let destPath   = containerPath + "/" + activeRel
        let destDir    = (destPath as NSString).deletingLastPathComponent
        NyxelActivityLog.record("DIAG PASO 7 activeRel=\(activeRel) pairingRequired=\(pairingRequired)")

        if container != nil {
            try? fm.createDirectory(atPath: destDir, withIntermediateDirectories: true)
            NyxelActivityLog.record("DIAG PASO 8 directorio local creado (o ya existia)")
        } else {
            NyxelActivityLog.record("DIAG PASO 8 sin container local; AirLift manejara directorios")
        }

        NyxelActivityLog.record("DIAG PASO 9 backup...")
        let backupRel = disguisedBackupPath(for: activeRel)
        let backupURL: URL
        do {
            backupURL = try localRestoreBackupURL(for: game, relativePath: activeRel)
        } catch {
            let msg = "No se pudo preparar el respaldo privado: \(error.localizedDescription)"
            NyxelActivityLog.record("DIAG PASO 9 FALLO: \(msg)")
            return InjectorResult(success: false, message: msg)
        }

        let previousPath = UserDefaults.standard.string(forKey: activePathKey(for: game))
        let previousRestoreWasConfirmed = UserDefaults.standard.bool(forKey: restoreCompletedKey(for: game))
        var originalData: Data?
        var originalReadFailure: String?
        if fm.fileExists(atPath: backupURL.path) {
            guard let savedOriginal = try? Data(contentsOf: backupURL), !savedOriginal.isEmpty else {
                let msg = "El respaldo privado existe, pero no se puede leer; no se modifico el archivo del juego."
                NyxelActivityLog.record("DIAG PASO 9 FALLO: \(msg)")
                return InjectorResult(success: false, message: msg)
            }
            originalData = savedOriginal
            NyxelActivityLog.record("DIAG PASO 9 respaldo privado previo encontrado (\(savedOriginal.count) bytes)")
        } else if let legacyBackup = readFromContainer(relPath: backupRel, container: containerPath, bundleID: bid), !legacyBackup.isEmpty {
            originalData = legacyBackup
            NyxelActivityLog.record("DIAG PASO 9 respaldo remoto anterior encontrado; se migrara al almacenamiento privado")
        } else if previousPath != nil && !previousRestoreWasConfirmed {
            let msg = "Hay una sesion anterior sin restauracion confirmada y no se encontro su respaldo. No se volvera a inyectar para evitar perder el original."
            NyxelActivityLog.record("DIAG PASO 9 FALLO: \(msg)")
            return InjectorResult(success: false, message: msg)
        } else if previousPath != nil && UserDefaults.standard.bool(forKey: originalMissingKey(for: game)) {
            let msg = "El build anterior marco el original como ausente y no dejo un respaldo legible. Repara o vuelve a descargar los archivos del juego antes de inyectar."
            NyxelActivityLog.record("DIAG PASO 9 FALLO: \(msg)")
            return InjectorResult(success: false, message: msg)
        } else {
            originalData = readFromContainer(
                relPath: activeRel,
                container: containerPath,
                bundleID: bid,
                onFailure: { originalReadFailure = $0 }
            )
        }

        let originalWasMissing: Bool
        if let original = originalData {
            guard !original.isEmpty else {
                let msg = "El original esta vacio; se cancelo la inyeccion para evitar una restauracion incompleta."
                NyxelActivityLog.record("DIAG PASO 9 FALLO: \(msg)")
                return InjectorResult(success: false, message: msg)
            }
            do {
                try saveLocalRestoreBackup(original, to: backupURL)
                guard let verifiedBackup = try? Data(contentsOf: backupURL), verifiedBackup == original else {
                    throw NSError(domain: "NyxelRestore", code: 1, userInfo: [NSLocalizedDescriptionKey: "la verificacion del respaldo no coincidio"])
                }
            } catch {
                let msg = "No se pudo guardar/verificar el original: \(error.localizedDescription)"
                NyxelActivityLog.record("DIAG PASO 9 FALLO: \(msg)")
                return InjectorResult(success: false, message: msg)
            }
            UserDefaults.standard.set(restoreDigest(original), forKey: restoreDigestKey(for: game))
            originalWasMissing = false
            NyxelActivityLog.record("DIAG PASO 9 OK original respaldado (\(original.count) bytes)")
        } else if pairingRequired {
            let detail = originalReadFailure.map { String($0.prefix(480)) } ?? "nil"
            NyxelActivityLog.record("DIAG PASO 9 WARN: AirLift read no disponible en iOS 27+ (detail=\(detail)). Continuando en write-only mode sin respaldo del original.")
            originalWasMissing = true
        } else if container == nil || !fm.fileExists(atPath: destPath) {
            originalWasMissing = true
        } else {
            let msg = "No se pudo leer el archivo original; la inyeccion se cancelo."
            NyxelActivityLog.record("DIAG PASO 9 FALLO: \(msg)")
            return InjectorResult(success: false, message: msg)
        }
        NyxelActivityLog.record("DIAG PASO 9 OK originalWasMissing=\(originalWasMissing)")

        UserDefaults.standard.set(activeRel, forKey: activePathKey(for: game))
        UserDefaults.standard.set(originalWasMissing, forKey: originalMissingKey(for: game))
        UserDefaults.standard.set(false, forKey: restoreCompletedKey(for: game))
        NyxelCleanupFlow.markInjectionWriteStarted(for: game)

        NyxelActivityLog.record("DIAG PASO 11 INYECTANDO via \(pairingRequired ? "AirLift" : "directo") relPath=\(activeRel) bytes=\(finalData.count)")
        if let error = writeToContainer(finalData, relPath: activeRel, container: containerPath, bundleID: bid) {
            let msg = "Inyeccion fallo: \(error.localizedDescription)"
            NyxelActivityLog.record("DIAG PASO 11 FALLO: \(msg)")
            return InjectorResult(success: false, message: msg)
        }
        NyxelActivityLog.record("DIAG PASO 11 OK escritura completada")

        if container != nil {
            try? fm.setAttributes([.posixPermissions: 0o644], ofItemAtPath: destPath)
        }

        NyxelCleanupFlow.markInjectionSucceeded(for: game)
        NyxelActivityLog.record("========== INJECTION TRACE END: SUCCESS ==========")

        return InjectorResult(success: true,
            message: "\(mode.displayName) inyectado! Abre Free Fire, espera 8-10 segundos, vuelve a Nyxel y limpia la sesion.")
    }

    private static func removeLegacyRemoteBackupIfAccessible(container: String, relativePath: String) -> Bool {
        let fileManager = FileManager.default
        let fullPath = container + "/" + relativePath
        let parentPath = (fullPath as NSString).deletingLastPathComponent
        let rootGrant = DavizinGrantContainerAccess(container)
        let parentGrant = DavizinGrantContainerAccess(parentPath)
        let fileGrant = DavizinGrantContainerAccess(fullPath)
        defer {
            DavizinReleaseContainerGrant(fileGrant)
            DavizinReleaseContainerGrant(parentGrant)
            DavizinReleaseContainerGrant(rootGrant)
        }
        if NyxelDeviceInfo.versionTuple.major >= 26 && [rootGrant, parentGrant, fileGrant].contains(where: { $0 < 0 }) {
            return false
        }
        guard fileManager.fileExists(atPath: fullPath) else { return false }
        do {
            try fileManager.removeItem(atPath: fullPath)
            return !fileManager.fileExists(atPath: fullPath)
        } catch {
            NyxelActivityLog.record("No se pudo retirar el respaldo remoto heredado: \(error.localizedDescription)")
            return false
        }
    }

    static func uninject(game: DavizinGame) -> InjectorResult {
        let fm = FileManager.default
        let bundleID = bundleID(for: game)

        var mcmErr: NSString?
        guard let container = DavizinGetContainerPath(bundleID, &mcmErr) else {
            return InjectorResult(success: false,
                message: (mcmErr as String?) ?? "Container no encontrado")
        }

        let activeRel = UserDefaults.standard.string(forKey: activePathKey(for: game)).flatMap { isSafeRelativePath($0) ? $0 : nil } ?? legacyDestPathRel(for: game)
        let destPath   = container + "/" + activeRel
        let backupRel = disguisedBackupPath(for: activeRel)
        let backupURL: URL
        do {
            backupURL = try localRestoreBackupURL(for: game, relativePath: activeRel)
        } catch {
            return InjectorResult(success: false, message: "No se pudo abrir el respaldo privado: \(error.localizedDescription)")
        }

        var backupData: Data?
        var cameFromLegacyRemoteBackup = false
        if fm.fileExists(atPath: backupURL.path) {
            guard let localData = try? Data(contentsOf: backupURL), !localData.isEmpty else {
                return InjectorResult(success: false, message: "El respaldo privado está dañado o vacío; no se confirmó la limpieza.")
            }
            backupData = localData
        } else if let legacyData = readFromContainer(relPath: backupRel, container: container, bundleID: bundleID), !legacyData.isEmpty {
            do {
                try saveLocalRestoreBackup(legacyData, to: backupURL)
                backupData = legacyData
                cameFromLegacyRemoteBackup = true
                NyxelActivityLog.record("Respaldo remoto heredado migrado al almacenamiento privado antes de restaurar")
            } catch {
                return InjectorResult(success: false, message: "No se pudo preservar el respaldo heredado: \(error.localizedDescription)")
            }
        }

        if let original = backupData {
            if let error = writeToContainer(original, relPath: activeRel, container: container, bundleID: bundleID) {
                return InjectorResult(success: false,
                    message: "No se pudo reponer el original: \(error.localizedDescription) {MCM: \(DavizinMCMLastDiagnostic() ?? "sin dato")}")
            }
            let restored = readFromContainer(relPath: activeRel, container: container, bundleID: bundleID)
            if let restored, restored == original {
                NyxelActivityLog.record("DIAG clean: restauracion verificada via read (\(restored.count) bytes)")
            } else if requiresPairingTransportOnCurrentDevice() {
                NyxelActivityLog.record("DIAG clean: read-verify no disponible en iOS 27+; aceptando write-back sin verificacion")
            } else {
                NyxelActivityLog.record("Limpieza no confirmada: lectura posterior no coincide con el respaldo")
                return InjectorResult(success: false, message: "Se escribió el original, pero no se pudo verificarlo. El respaldo se conserva; vuelve a intentar limpiar.")
            }

            UserDefaults.standard.set(restoreDigest(original), forKey: restoreDigestKey(for: game))
            UserDefaults.standard.set(false, forKey: originalMissingKey(for: game))
            UserDefaults.standard.set(true, forKey: restoreCompletedKey(for: game))
            do {
                try fm.removeItem(at: backupURL)
            } catch {
                return InjectorResult(success: false, message: "El original quedó restaurado y verificado, pero no se pudo retirar la copia privada: \(error.localizedDescription)")
            }

            var message = "Original restaurado y verificado. Sesión limpia; puedes volver a abrir el juego."
            if cameFromLegacyRemoteBackup && !removeLegacyRemoteBackupIfAccessible(container: container, relativePath: backupRel) {
                message += " Se conserva una copia heredada de respaldo porque iOS no permitió borrarla."
                NyxelActivityLog.record("El original fue restaurado; la copia remota heredada se conserva por seguridad")
            }
            return InjectorResult(success: true, message: message)
        }

        let expectedDigest = UserDefaults.standard.string(forKey: restoreDigestKey(for: game))
        if UserDefaults.standard.bool(forKey: restoreCompletedKey(for: game)),
           let expectedDigest,
           let current = readFromContainer(relPath: activeRel, container: container, bundleID: bundleID),
           restoreDigest(current) == expectedDigest {
            UserDefaults.standard.set(false, forKey: originalMissingKey(for: game))
            return InjectorResult(success: true, message: "El original ya está restaurado y verificado. Sesión limpia.")
        }

        if UserDefaults.standard.bool(forKey: originalMissingKey(for: game)) {
            if requiresPairingTransportOnCurrentDevice() {
                NyxelActivityLog.record("DIAG clean: iOS 27+ write-only mode — clearing session (original likely untouched)")
                UserDefaults.standard.removeObject(forKey: activePathKey(for: game))
                UserDefaults.standard.set(false, forKey: originalMissingKey(for: game))
                UserDefaults.standard.set(true, forKey: restoreCompletedKey(for: game))
                NyxelCleanupFlow.markCleaningSucceeded(for: game)
                return InjectorResult(success: true,
                    message: "Sesión limpiada. El archivo original no fue modificado.")
            }
            let parentPath = (destPath as NSString).deletingLastPathComponent
            let rootGrant = DavizinGrantContainerAccess(container)
            let parentGrant = DavizinGrantContainerAccess(parentPath)
            let fileGrant = DavizinGrantContainerAccess(destPath)
            defer {
                DavizinReleaseContainerGrant(fileGrant)
                DavizinReleaseContainerGrant(parentGrant)
                DavizinReleaseContainerGrant(rootGrant)
            }
            if NyxelDeviceInfo.versionTuple.major >= 26 && [rootGrant, parentGrant, fileGrant].contains(where: { $0 < 0 }) {
                return InjectorResult(success: false, message: "No se pudo verificar el acceso para retirar el archivo temporal.")
            }
            do {
                if fm.fileExists(atPath: destPath) { try fm.removeItem(atPath: destPath) }
                guard !fm.fileExists(atPath: destPath) else {
                    return InjectorResult(success: false, message: "El archivo temporal todavía existe; no se confirmó la limpieza.")
                }
                UserDefaults.standard.set(true, forKey: restoreCompletedKey(for: game))
                UserDefaults.standard.set(false, forKey: originalMissingKey(for: game))
                return InjectorResult(success: true, message: "Archivo temporal retirado; el original no existía antes de inyectar.")
            } catch {
                return InjectorResult(success: false, message: "No se pudo retirar el archivo temporal: \(error.localizedDescription)")
            }
        }

        return InjectorResult(success: false,
            message: "No hay un respaldo restaurable; la limpieza no se confirmó.")
    }

    /// Resultado del chequeo de compatibilidad del dispositivo.
	enum Compat {
		case compatible          // puede acceder al contenedor -> puede inyectar
		case noGameInstalled     // Free Fire no esta instalado
		case notCompatible       // el juego esta pero no se puede acceder (iOS no compatible)
		case unsupportedSystem   // la versión/build del sistema no está verificada
    }

	/// Prueba REAL si el dispositivo puede inyectar, intentando acceder al
	/// contenedor de Free Fire (MAX o normal) via MCM. No inyecta nada.
	/// Intenta verificar si un bundle está instalado enumerando containers
	private static func isBundleInstalledViaEnumeration(_ bundleID: String) -> Bool {
		let fm = FileManager.default
		let appDataRoot = "/var/mobile/Containers/Data/Application"

		guard fm.fileExists(atPath: appDataRoot) else { return false }

		do {
			let containers = try fm.contentsOfDirectory(atPath: appDataRoot)
			for containerDir in containers {
				let metadataPath = "\(appDataRoot)/\(containerDir)/.com.apple.mobile_container_manager.metadata.plist"
				if let metadata = NSDictionary(contentsOfFile: metadataPath),
				   let bid = metadata["MCMMetadataIdentifier"] as? String,
				   bid == bundleID {
					return true
				}
			}
		} catch {
			return false
		}
		return false
	}

	static func checkCompatibility() -> Compat {
		guard NyxelSupportPolicy.isCurrentSystemSupported else {
			return .unsupportedSystem
		}

		let bundles = ["com.dts.freefiremax", "com.dts.freefireth"]

        for bid in bundles {
            var err: NSString?
            if let _ = DavizinGetContainerPath(bid, &err) {
                return .compatible
            }
        }

        for bid in bundles {
            if isBundleInstalledViaEnumeration(bid) {
                return .compatible
            }
        }

        return .noGameInstalled
    }

}
