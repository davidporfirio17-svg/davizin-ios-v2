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
    let jailbreakIndicator: String
    let tunnelStatus: String
    let tunnelConfigured: Bool
    let tunnelPluginPresent: Bool
    let pairing: NixelCheckState
    let developerMode: NixelCheckState

    var summary: String {
        let configured = tunnelConfigured ? "configurado" : "sin configurar"
        let plugin = tunnelPluginPresent ? "presente" : "ausente"
        return "Dispositivo local: \(deviceModel) · iOS/iPadOS \(systemVersion) · Jailbreak: \(jailbreakIndicator) · Túnel: \(tunnelStatus) (\(configured), extensión \(plugin)) · Pairing: \(pairing.rawValue) · Developer Mode: \(developerMode.rawValue)"
    }
}

enum NixelJailbreakEnvironment {
    static func indicator() -> String {
        let fm = FileManager.default
        let rootlessPaths = [
            "/var/jb",
            "/private/var/jb",
            "/var/containers/Bundle/jb"
        ]
        if let path = rootlessPaths.first(where: { fm.fileExists(atPath: $0) }) {
            return "indicio rootless visible (\(path)); falta confirmar estado"
        }
        let rootfulPaths = [
            "/usr/libexec/sshd",
            "/Library/MobileSubstrate/DynamicLibraries"
        ]
        if let path = rootfulPaths.first(where: { fm.fileExists(atPath: $0) }) {
            return "indicio rootful visible (\(path)); falta confirmar estado"
        }
        return "sin indicios visibles desde la app"
    }
}

enum NixelExploitPhase: String {
    case compatibilityCheck = "Comprobando compatibilidad"
    case developerModeRequired = "Developer Mode requerido"
    case kernelAccessPending = "Acceso al kernel pendiente"
    case kernelAccessActive = "Acceso al kernel verificado"
    case exploitReady = "Exploit compatible"
    case exploitUnavailable = "Exploit no integrado"
    case unsupported = "Sistema no verificado"
}

struct NixelExploitAssessment {
    let phase: NixelExploitPhase
    let system: String
    let environment: String
    let message: String

    var summary: String {
        "Exploit: \(phase.rawValue) · \(system) · \(environment) · \(message)"
    }
}

enum NixelExploitExecutionResult {
    case completed(String)
    case blocked(String)
}

struct NixelExploitPreflight {
    let pairingAuthenticated: Bool
    let developerModeEnabled: Bool
    let kernelAccessActive: Bool

    static let notReady = NixelExploitPreflight(
        pairingAuthenticated: false,
        developerModeEnabled: false,
        kernelAccessActive: false
    )

    var blockingReason: String? {
        if !pairingAuthenticated { return "Pairing autenticado pendiente." }
        if !developerModeEnabled { return "Developer Mode no confirmado." }
        if !kernelAccessActive { return "Acceso al kernel no verificado." }
        return nil
    }
}

protocol NixelExploitBackend {
    func execute(completion: @escaping (NixelExploitExecutionResult) -> Void)
}

/// Backend nulo hasta integrar una implementación compatible con el
/// dispositivo. Evita que la UI convierta una simulación en “Jailbreak”.
final class NixelUnavailableExploitBackend: NixelExploitBackend {
    func execute(completion: @escaping (NixelExploitExecutionResult) -> Void) {
        completion(.blocked("Backend de exploit no instalado."))
    }
}

/// Evalúa prerequisitos sin ejecutar código de exploit. El acceso al kernel
/// solo podrá pasar a activo mediante un backend verificado que devuelva una
/// señal explícita; no se infiere desde una carpeta, VPN o pairing.
enum NixelExploitCoordinator {
    static func assess() -> NixelExploitAssessment {
        let system = NyxelSupportPolicy.currentSystemDescription
        let environment = NixelJailbreakEnvironment.indicator()
        guard NyxelSupportPolicy.isCurrentSystemSupported else {
            return NixelExploitAssessment(
                phase: .unsupported,
                system: system,
                environment: environment,
                message: "La versión/build no está en la matriz verificada de Nyxel."
            )
        }
        return NixelExploitAssessment(
            phase: .exploitUnavailable,
            system: system,
            environment: environment,
            message: "El backend de exploit todavía no está integrado; no se ejecutó ninguna operación."
        )
    }

    static func execute(
        preflight: NixelExploitPreflight = .notReady,
        backend: NixelExploitBackend = NixelUnavailableExploitBackend(),
        completion: @escaping (NixelExploitExecutionResult) -> Void
    ) {
        let assessment = assess()
        if case .unsupported = assessment.phase {
            completion(.blocked(assessment.message))
            return
        }
        if let reason = preflight.blockingReason {
            completion(.blocked(reason))
            return
        }
        backend.execute(completion: completion)
    }
}

struct NixelRemotePairingService {
    let name: String
    let endpoint: Network.NWEndpoint
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
            browser.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                if case .failed(let error) = state {
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

enum NixelPairingAuthenticationResult {
    case authenticated(record: Data)
    case rejected(String)
    case unavailable(String)
}

protocol NixelPairingAuthenticator {
    func authenticate(
        service: NixelRemotePairingService,
        pin: String,
        storedRecord: Data?,
        completion: @escaping (NixelPairingAuthenticationResult) -> Void
    )
}

/// Adaptador deliberadamente aislado. Aquí se conectará el protocolo de
/// pairing de External/Xtar cuando se disponga de su formato de registro y
/// handshake; no acepta un PIN como éxito sin una respuesta autenticada.
final class NixelExternalPairingAuthenticator: NixelPairingAuthenticator {
    func authenticate(
        service: NixelRemotePairingService,
        pin: String,
        storedRecord: Data?,
        completion: @escaping (NixelPairingAuthenticationResult) -> Void
    ) {
        completion(.unavailable("El handshake autenticado de Remote Pairing aún no está integrado para \(service.name)."))
    }
}

enum NixelPairingSessionState {
    case idle
    case searching
    case serviceDetected(String)
    case transportReachable(String)
    case pairingRecordFound(String)
    case pairingRequired(String)
    case paired(String)
    case developerModeRequired(String)
    case ready(String)
    case failed(String)

    var message: String {
        switch self {
        case .idle: return "Pairing sin iniciar"
        case .searching: return "Buscando Remote Pairing…"
        case .serviceDetected(let name): return "Servicio detectado: \(name)"
        case .transportReachable(let name): return "Transporte accesible: \(name)"
        case .pairingRecordFound(let name): return "Registro local encontrado para \(name); autenticación pendiente"
        case .pairingRequired(let name): return "Pairing autenticado requerido para \(name)"
        case .paired(let name): return "Pairing autenticado: \(name)"
        case .developerModeRequired(let name): return "Developer Mode requerido para \(name)"
        case .ready(let name): return "Dispositivo listo para la siguiente fase: \(name)"
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
    private let authenticator: NixelPairingAuthenticator = NixelExternalPairingAuthenticator()

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

    func submitPIN(_ pin: String, onState: @escaping (NixelPairingSessionState) -> Void) {
        guard let service else {
            update(.failed("No hay un servicio Remote Pairing seleccionado."), onState: onState)
            return
        }
        let normalized = pin.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count >= 4,
              normalized.count <= 8,
              normalized.allSatisfy({ $0.isNumber }) else {
            update(.failed("El PIN de pairing debe tener entre 4 y 8 dígitos."), onState: onState)
            return
        }
        // El PIN no se persiste. El adaptador debe devolver un registro
        // autenticado antes de que se pueda marcar la sesión como paired.
        let stored = NixelPairingRecordStore.shared.load(deviceID: service.name)
        authenticator.authenticate(service: service, pin: normalized, storedRecord: stored) { [weak self] result in
            guard let self else { return }
            switch result {
            case .authenticated(let record):
                do {
                    try NixelPairingRecordStore.shared.save(record, deviceID: service.name)
                    self.update(.paired(service.name), onState: onState)
                    self.update(.developerModeRequired(service.name), onState: onState)
                } catch {
                    self.update(.failed("No se pudo guardar el registro autenticado: \(error.localizedDescription)"), onState: onState)
                }
            case .rejected(let message):
                self.update(.failed("Pairing rechazado: \(message)"), onState: onState)
            case .unavailable(let message):
                self.update(.failed(message), onState: onState)
            }
        }
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
            jailbreakIndicator: NixelJailbreakEnvironment.indicator(),
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
        NyxelActivityLog.record(NixelExploitCoordinator.assess().summary)
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
