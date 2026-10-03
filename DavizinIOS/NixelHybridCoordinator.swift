import Foundation
import Network
import NetworkExtension
import Security
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
    let tunnelPluginPresent: Bool
    let pairing: NixelCheckState
    let developerMode: NixelCheckState

    var summary: String {
        let configured = tunnelConfigured ? "configurado" : "sin configurar"
        let plugin = tunnelPluginPresent ? "presente" : "ausente"
        return "Dispositivo local: \(deviceModel) · iOS/iPadOS \(systemVersion) · Túnel: \(tunnelStatus) (\(configured), extensión \(plugin)) · Pairing: \(pairing.rawValue) · Developer Mode: \(developerMode.rawValue)"
    }
}

struct NixelRemotePairingService {
    let name: String
    let endpoint: NWEndpoint
}

enum NixelPairingProbeResult {
    case servicesFound([NixelRemotePairingService])
    case noService
    case unavailable(String)
}

enum NixelPairingTransportResult {
    case reachable(String)
    case unreachable(String)
}

/// Busca los anuncios Bonjour usados por Remote Pairing y comprueba el
/// alcance TCP del servicio. No solicita PIN, no guarda credenciales y no
/// afirma que el dispositivo esté emparejado o jailbroken.
final class NixelPairingProbe {
    static let shared = NixelPairingProbe()

    private var browsers: [NWBrowser] = []
    private var connection: NWConnection?
    private var timeoutWorkItem: DispatchWorkItem?
    private var completion: ((NixelPairingProbeResult) -> Void)?
    private var serviceMap: [String: NixelRemotePairingService] = [:]
    private let queue = DispatchQueue.main

    private init() {}

    func scan(timeout: TimeInterval = 8.0, completion: @escaping (NixelPairingProbeResult) -> Void) {
        stop()
        self.completion = completion
        serviceMap.removeAll()

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
                        self.serviceMap[name] = NixelRemotePairingService(name: name, endpoint: result.endpoint)
                    }
                }
                if !self.serviceMap.isEmpty {
                    self.finish(.servicesFound(Array(self.serviceMap.values).sorted { $0.name < $1.name }))
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
            if self.serviceMap.isEmpty {
                self.finish(.noService)
            }
        }
        timeoutWorkItem = work
        queue.asyncAfter(deadline: .now() + timeout, execute: work)
    }

    func probeTransport(
        service: NixelRemotePairingService,
        timeout: TimeInterval = 5.0,
        completion: @escaping (NixelPairingTransportResult) -> Void
    ) {
        connection?.cancel()
        let connection = NWConnection(to: service.endpoint, using: .tcp)
        self.connection = connection
        var completed = false
        func finish(_ result: NixelPairingTransportResult) {
            guard !completed else { return }
            completed = true
            connection.cancel()
            self.connection = nil
            completion(result)
        }
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                finish(.reachable(service.name))
            case .failed(let error):
                finish(.unreachable("\(service.name): \(error.localizedDescription)"))
            case .cancelled:
                finish(.unreachable("\(service.name): conexión cancelada"))
            default:
                break
            }
        }
        connection.start(queue: queue)
        queue.asyncAfter(deadline: .now() + timeout) {
            finish(.unreachable("\(service.name): tiempo de conexión agotado"))
        }
    }

    func stop() {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        browsers.forEach { $0.cancel() }
        browsers.removeAll()
        connection?.cancel()
        connection = nil
        completion = nil
        serviceMap.removeAll()
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

/// Guarda el registro de pairing como blob opaco en Keychain. El protocolo
/// que lo produce/consume se mantiene separado para no mezclar credenciales
/// con la UI o con la configuración VPN.
final class NixelPairingRecordStore {
    static let shared = NixelPairingRecordStore()
    private let service = "com.apple.mobile.MobileHouseArrest.nyxel.pairing"

    private init() {}

    func save(_ record: Data, deviceID: String) throws {
        let account = deviceID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !account.isEmpty, !record.isEmpty else { throw StoreError.invalidRecord }
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(base as CFDictionary)
        var item = base
        item[kSecValueData as String] = record
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw StoreError.keychain(status) }
    }

    func load(deviceID: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: deviceID,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    func remove(deviceID: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: deviceID
        ]
        SecItemDelete(query as CFDictionary)
    }

    enum StoreError: LocalizedError {
        case invalidRecord
        case keychain(OSStatus)

        var errorDescription: String? {
            switch self {
            case .invalidRecord: return "Registro de pairing vacío o sin identificador de dispositivo."
            case .keychain(let status): return "Keychain rechazó el registro de pairing (\(status))."
            }
        }
    }
}

enum NixelPairingSessionState {
    case idle
    case searching
    case serviceDetected(String)
    case transportReachable(String)
    case pairingRecordFound(String)
    case pairingRequired(String)
    case failed(String)

    var message: String {
        switch self {
        case .idle: return "Pairing sin iniciar"
        case .searching: return "Buscando Remote Pairing…"
        case .serviceDetected(let name): return "Servicio detectado: \(name)"
        case .transportReachable(let name): return "Transporte accesible: \(name)"
        case .pairingRecordFound(let name): return "Registro local encontrado para \(name); autenticación pendiente"
        case .pairingRequired(let name): return "Pairing autenticado requerido para \(name)"
        case .failed(let message): return message
        }
    }
}

/// Orquesta el tramo observable del flujo External: descubrimiento, alcance
/// del transporte y pausa explícita antes del PIN/registro de pairing.
/// La autenticación real se deja detrás de un adaptador porque requiere el
/// protocolo privado y el registro de pairing de la IPA de referencia.
final class NixelPairingSession {
    static let shared = NixelPairingSession()
    private(set) var state: NixelPairingSessionState = .idle
    private var service: NixelRemotePairingService?

    private init() {}

    func begin(onState: @escaping (NixelPairingSessionState) -> Void) {
        stop()
        update(.searching, onState: onState)
        NixelPairingProbe.shared.scan { [weak self] result in
            guard let self else { return }
            switch result {
            case .servicesFound(let services):
                guard let service = services.first else {
                    self.update(.failed("No hay un servicio Remote Pairing utilizable."), onState: onState)
                    return
                }
                self.service = service
                self.update(.serviceDetected(service.name), onState: onState)
                NixelPairingProbe.shared.probeTransport(service: service) { [weak self] transport in
                    guard let self else { return }
                    switch transport {
                    case .reachable(let name):
                        self.update(.transportReachable(name), onState: onState)
                        if NixelPairingRecordStore.shared.load(deviceID: name) != nil {
                            self.update(.pairingRecordFound(name), onState: onState)
                        }
                        self.update(.pairingRequired(name), onState: onState)
                    case .unreachable(let message):
                        self.update(.failed("Servicio detectado, pero transporte no accesible: \(message)"), onState: onState)
                    }
                }
            case .noService:
                self.update(.failed("No se detectó ningún servicio Remote Pairing."), onState: onState)
            case .unavailable(let message):
                self.update(.failed("Remote Pairing no disponible: \(message)"), onState: onState)
            }
        }
    }

    func stop() {
        NixelPairingProbe.shared.stop()
        service = nil
        state = .idle
    }

    private func update(_ next: NixelPairingSessionState, onState: @escaping (NixelPairingSessionState) -> Void) {
        state = next
        NyxelActivityLog.record("Pairing: \(next.message)")
        onState(next)
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
            tunnelPluginPresent: vpn.tunnelPluginPresent,
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
        NixelPairingSession.shared.stop()
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
