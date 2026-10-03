import Foundation

/// Punto único para el flujo Hybrid: prepara el túnel local y deja que el
/// inyector existente siga siendo responsable de los bundles de juego.
enum NixelHybridCoordinator {
    static func start(completion: @escaping (Result<Void, Error>) -> Void) {
        NixelVPNManager.shared.start(completion: completion)
    }

    static func stop() {
        NixelVPNManager.shared.stop()
    }

    static var statusText: String {
        NixelVPNManager.statusText(NixelVPNManager.shared.status)
    }
}
