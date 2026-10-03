import Foundation
import NetworkExtension

/// Punto único para el flujo Hybrid/Jailbreak.
///
/// La VPN es una dependencia de coordinación; una conexión exitosa no se
/// interpreta por sí sola como jailbreak exitoso.
enum NixelHybridCoordinator {
    static func start(completion: @escaping (Result<Void, Error>) -> Void) {
        NyxelActivityLog.record("Hybrid VPN: preparando configuración")
        NixelVPNManager.shared.start { result in
            switch result {
            case .success:
                NyxelActivityLog.record("Hybrid VPN: conectado")
            case .failure(let error):
                NyxelActivityLog.record("Hybrid VPN: error — \(error.localizedDescription)")
            }
            completion(result)
        }
    }

    static func stop() {
        NixelVPNManager.shared.stop()
    }

    static var status: NEVPNStatus {
        NixelVPNManager.shared.status
    }

    static var statusText: String {
        NixelVPNManager.statusText(status)
    }

    static var isActive: Bool {
        NixelVPNManager.shared.isActive
    }
}
