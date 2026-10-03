import Foundation
import Network
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

enum NixelPairingProbeResult {
    case servicesFound([String])
    case noService
    case unavailable(String)
}

/// Busca los anuncios Bonjour usados por Remote Pairing.
/// Esta sonda detecta presencia en la red local, pero no intenta emparejar,
/// pedir PIN ni afirmar que el dispositivo esté jailbroken.
final class NixelPairingProbe {
    static let shared = NixelPairingProbe()

    private var browsers: [NWBrowser] = []
    private var timeoutWorkItem: DispatchWorkItem?
    private var completion: ((NixelPairingProbeResult) -> Void)?
    private var serviceNames = Set<String>()
    private let queue = DispatchQueue.main

    private init() {}

    func scan(timeout: TimeInterval = 8.0, completion: @escaping (NixelPairingProbeResult) -> Void) {
        stop()
        self.completion = completion
        serviceNames.removeAll()

        let serviceTypes = [
            "_remotepairing._tcp",
            "_remotepairing-pairable-host._tcp"
        ]
        browsers = serviceTypes.map { serviceType in
            let browser = NWBrowser(for: .bonjour(type: serviceType, domain: nil), using: .tcp)
            browser.browseResultsChangedHandler = { [weak self] results, _ in
                guard let self else { return }
                for result in results {
                    if case let .service(name, _, _, _) = result.endpoint {
                        self.serviceNames.insert(name)
                    }
                }
                if !self.serviceNames.isEmpty {
                    self.finish(.servicesFound(self.serviceNames.sorted()))
                }
            }
            browser.stateChangedHandler = { [weak self] state in
                guard let self else { return }
                if case .failed(let error) = state, self.browsers.allSatisfy({
                    if case .failed = $0.state { return true }
                    return false
                }) {
                    self.finish(.unavailable(error.localizedDescription))
                }
            }
            browser.start(queue: queue)
            return browser
        }

        let work = DispatchWorkItem { [weak self] in
            guard let self, self.completion != nil else { return }
            if self.serviceNames.isEmpty {
                self.finish(.noService)
            }
        }
        timeoutWorkItem = work
        queue.asyncAfter(deadline: .now() + timeout, execute: work)
    }

    func stop() {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        browsers.forEach { $0.cancel() }
        browsers.removeAll()
        completion = nil
        serviceNames.removeAll()
    }

    private func finish(_ result: NixelPairingProbeResult) {
        guard let completion else { return }
        self.completion = nil
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        browsers.forEach { $0.cancel() }
        browsers.removeAll()
        completion(result)
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
        NixelPairingProbe.shared.stop()
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
