import Foundation
import CryptoKit

/// Canal AirLift de lectura/escritura con verificación posterior opcional.
enum NixelAirLiftFileChannel {
    struct ChannelError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static var isAvailable: Bool {
        NixelPairingRecordStore.shared.load(deviceID: "2424") != nil
    }

    static func write(_ data: Data, toRelativePath relativePath: String, bundleID: String, discoverTimeout: TimeInterval = 20) -> Result<Void, ChannelError> {
        guard let record = NixelPairingRecordStore.shared.load(deviceID: "2424") else {
            return .failure(ChannelError(message: "No hay un registro de pairing guardado."))
        }
        var errorPointer: UnsafeMutablePointer<CChar>?
        let status = record.withUnsafeBytes { recordBuf -> Int32 in
            guard let recordBase = recordBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return -1 }
            return data.withUnsafeBytes { dataBuf -> Int32 in
                let dataBase = dataBuf.baseAddress?.assumingMemoryBound(to: UInt8.self)
                return bundleID.withCString { bid in
                    relativePath.withCString { path in
                        nyxel_airlift_container_io(recordBase, record.count, bid, path, 1, dataBase, data.count, nil, nil, discoverTimeout, &errorPointer)
                    }
                }
            }
        }
        if status == 0 { return .success(()) }
        let message = errorPointer.map { String(cString: $0) } ?? "Error desconocido del canal AirLift (\(status))."
        if let errorPointer { nyxel_free_string(errorPointer) }
        return .failure(ChannelError(message: message))
    }

    /// Escribe y lee de nuevo para confirmar que el transporte aceptó los
    /// mismos bytes; no marca la operación como correcta sin esta comprobación.
    static func writeVerified(_ data: Data, toRelativePath relativePath: String, bundleID: String, discoverTimeout: TimeInterval = 20) -> Result<Void, ChannelError> {
        switch write(data, toRelativePath: relativePath, bundleID: bundleID, discoverTimeout: discoverTimeout) {
        case .failure(let error): return .failure(error)
        case .success:
            switch read(relativePath: relativePath, bundleID: bundleID, discoverTimeout: discoverTimeout) {
            case .failure(let error):
                return .failure(ChannelError(message: "Escritura completada pero lectura de verificación falló: \(error.message)"))
            case .success(let returned):
                guard returned.sha256 == data.sha256 else {
                    return .failure(ChannelError(message: "La lectura posterior no coincide con los bytes escritos."))
                }
                return .success(())
            }
        }
    }

    static func read(relativePath: String, bundleID: String, discoverTimeout: TimeInterval = 20) -> Result<Data, ChannelError> {
        guard let record = NixelPairingRecordStore.shared.load(deviceID: "2424") else {
            return .failure(ChannelError(message: "No hay un registro de pairing guardado."))
        }
        var errorPointer: UnsafeMutablePointer<CChar>?
        var outData: UnsafeMutablePointer<UInt8>?
        var outLen = 0
        let status = record.withUnsafeBytes { recordBuf -> Int32 in
            guard let recordBase = recordBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return -1 }
            return bundleID.withCString { bid in
                relativePath.withCString { path in
                    nyxel_airlift_container_io(recordBase, record.count, bid, path, 0, nil, 0, &outData, &outLen, discoverTimeout, &errorPointer)
                }
            }
        }
        if status == 0, let outData {
            let data = Data(bytes: outData, count: outLen)
            nyxel_free_data(outData, outLen)
            return .success(data)
        }
        let message = errorPointer.map { String(cString: $0) } ?? "Error desconocido del canal AirLift (\(status))."
        if let errorPointer { nyxel_free_string(errorPointer) }
        return .failure(ChannelError(message: message))
    }
}

private extension Data {
    var sha256: Data { Data(SHA256.hash(data: self)) }
}
