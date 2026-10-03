import Foundation
import NetworkExtension
import UIKit

enum NixelCheckState: String {
    case notChecked = "No verificado"
    case unavailable = "No disponible desde la API pública"
    case ready = "Listo"
}

struct NixelHybridDiagnostics {
    let deviceModel: String
    let systemVersion: String
    let tunnelStatus: String
    let tunnelConfigured: Bool
    let pairing: NixelCheckState
    let developerMode: NixelCheckState

    var summary: String {
        let configured = tunnelConfigured ? "configurado" : "sin configurar"
        return "Dispositivo local: \(deviceModel) · iOS/iPadOS \(systemVersion) · Túnel: \(tunnelStatus) (\(configured)) · Pairing: \(pairing.rawValue) · Developer Mode: \(developerMode.rawValue)"
    }
}

/// Punto único para el flujo Hybrid/Jailbreak.
///
/// La VPN es una dependencia de coordinación; una conexión exitosa no se
/// interpreta por sí sola como jailbreak exitoso. Pairing y Developer Mode
/// quedan expresamente sin verificar hasta integrar el transporte con el iPad.
enum NixelHybridCoordinator {
    static func diagnostics() -> NixelHybridDiagnostics {
        let device = UIDevice.current
        let vpn = NixelVPNManager.shared
        return NixelHybridDiagnostics(
            deviceModel: device.localizedModel,
            systemVersion: device.systemVersion,
            tunnelStatus: NixelVPNManager.statusText(vpn.status),
            tunnelConfigured: vpn.isConfigured,
            pairing: .notChecked,
            developerMode: .notChecked
        )
    }

    static func start(completion: @escaping (Result<Void, Error>) -> Void) {
        let before = diagnostics()
        NyxelActivityLog.record("Hybrid diagnóstico: \(before.summary)")
        NixelVPNManager.shared.start { result in
            switch result {
            case .success:
                NyxelActivityLog.record("Hybrid VPN: conectado; pairing aún no verificado")
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
