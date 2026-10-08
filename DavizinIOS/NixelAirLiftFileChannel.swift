import Foundation

private let nyxelAirliftLogCallback: ALLogCallback = { _, message in
    guard let message else { return }
    let line = String(cString: message).trimmingCharacters(in: .whitespacesAndNewlines)
    guard !line.isEmpty else { return }
    DispatchQueue.main.async {
        NyxelActivityLog.record("AirLift: \(line)")
    }
}

/// Canal AirLift basado en el flujo de Tekezuna.
/// No usa House Arrest/AFC ni `tunnel_create_rppairing`: el núcleo AirLift
/// resuelve el contenedor y abre su propio túnel RSD multihost para la operación.
enum NixelAirLiftFileChannel {
    struct ChannelError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static var isAvailable: Bool {
        NixelPairingRecordStore.shared.load(deviceID: "2424") != nil
    }

    private static func safeRelativePath(_ value: String) -> Bool {
        value.hasPrefix("Documents/") &&
        !value.contains("..") &&
        !value.contains("//") &&
        !value.hasPrefix("/")
    }

    private static func resolveContainer(pairingPath: String, bundleID: String) -> Result<String, ChannelError> {
        var containerPointer: UnsafeMutablePointer<CChar>?
        var errorPointer: UnsafeMutablePointer<CChar>?
        let code = pairingPath.withCString { pairing in
            bundleID.withCString { bundle in
                al_find_app_container(pairing, bundle, nyxelAirliftLogCallback, nil, &containerPointer, &errorPointer)
            }
        }
        defer {
            if let containerPointer { al_string_free(containerPointer) }
            if let errorPointer { al_string_free(errorPointer) }
        }
        guard code == 0, let containerPointer else {
            let detail = errorPointer.map { String(cString: $0) } ?? "No se pudo resolver el contenedor de la aplicación (AirLift: \(code))."
            return .failure(ChannelError(message: detail))
        }
        let path = String(cString: containerPointer)
        guard path.hasPrefix("/var/mobile/Containers/Data/Application/") else {
            return .failure(ChannelError(message: "AirLift devolvió una ruta de contenedor no válida."))
        }
        return .success(path)
    }

    static func write(_ data: Data, toRelativePath relativePath: String, bundleID: String) -> Result<Void, ChannelError> {
        guard let record = NixelPairingRecordStore.shared.load(deviceID: "2424") else {
            return .failure(ChannelError(message: "No hay un registro de pairing guardado."))
        }
        guard safeRelativePath(relativePath) else {
            return .failure(ChannelError(message: "La ruta remota no es segura."))
        }
        let pairingURL = FileManager.default.temporaryDirectory.appendingPathComponent("nyxel-airlift-pairing-\(UUID().uuidString).plist")
        do {
            try record.write(to: pairingURL, options: .atomic)
            defer { try? FileManager.default.removeItem(at: pairingURL) }
            switch resolveContainer(pairingPath: pairingURL.path, bundleID: bundleID) {
            case .failure(let error): return .failure(error)
            case .success(let container):
                let target = URL(fileURLWithPath: container, isDirectory: true).appendingPathComponent(relativePath)
                let staging = FileManager.default.temporaryDirectory.appendingPathComponent("nyxel-airlift-write-\(UUID().uuidString)", isDirectory: true)
                try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
                defer { try? FileManager.default.removeItem(at: staging) }
                try data.write(to: staging.appendingPathComponent(target.lastPathComponent), options: .atomic)
                var errorPointer: UnsafeMutablePointer<CChar>?
                let code = pairingURL.path.withCString { pairing in
                    staging.path.withCString { source in
                        target.deletingLastPathComponent().path.withCString { destination in
                            al_exploit_write_dir(pairing, source, destination, nyxelAirliftLogCallback, nil, &errorPointer)
                        }
                    }
                }
                let detail = errorPointer.map { String(cString: $0) }
                if let errorPointer { al_string_free(errorPointer) }
                guard code == 0 else {
                    return .failure(ChannelError(message: detail ?? "AirLift no pudo escribir el archivo (\(code))."))
                }
                return .success(())
            }
        } catch {
            return .failure(ChannelError(message: "No se pudo preparar la escritura AirLift: \(error.localizedDescription)"))
        }
    }

    static func read(relativePath: String, bundleID: String) -> Result<Data, ChannelError> {
        guard let record = NixelPairingRecordStore.shared.load(deviceID: "2424") else {
            return .failure(ChannelError(message: "No hay un registro de pairing guardado."))
        }
        guard safeRelativePath(relativePath) else {
            return .failure(ChannelError(message: "La ruta remota no es segura."))
        }
        let pairingURL = FileManager.default.temporaryDirectory.appendingPathComponent("nyxel-airlift-pairing-\(UUID().uuidString).plist")
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("nyxel-airlift-read-\(UUID().uuidString)")
        do {
            try record.write(to: pairingURL, options: .atomic)
            defer {
                try? FileManager.default.removeItem(at: pairingURL)
                try? FileManager.default.removeItem(at: outputURL)
            }
            switch resolveContainer(pairingPath: pairingURL.path, bundleID: bundleID) {
            case .failure(let error): return .failure(error)
            case .success(let container):
                let target = URL(fileURLWithPath: container, isDirectory: true).appendingPathComponent(relativePath)
                var errorPointer: UnsafeMutablePointer<CChar>?
                let code = pairingURL.path.withCString { pairing in
                    target.path.withCString { remote in
                        outputURL.path.withCString { output in
                            al_exploit_read_file(pairing, remote, output, nyxelAirliftLogCallback, nil, &errorPointer)
                        }
                    }
                }
                let detail = errorPointer.map { String(cString: $0) }
                if let errorPointer { al_string_free(errorPointer) }
                guard code == 0 else {
                    return .failure(ChannelError(message: detail ?? "AirLift no pudo leer el archivo (\(code))."))
                }
                return .success(try Data(contentsOf: outputURL, options: .mappedIfSafe))
            }
        } catch {
            return .failure(ChannelError(message: "No se pudo preparar la lectura AirLift: \(error.localizedDescription)"))
        }
    }
}
