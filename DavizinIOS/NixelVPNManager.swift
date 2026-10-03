import Foundation
import NetworkExtension

/// Gestiona el túnel local que acompaña al flujo Hybrid/Jailbreak de Nyxel.
///
/// Esta capa solo prepara y supervisa NetworkExtension. No declara que el
/// dispositivo esté jailbroken: ese resultado deberá venir de una fase de
/// pairing/diagnóstico independiente.
final class NixelVPNManager: NSObject {
    static let shared = NixelVPNManager()
    static let tunnelBundleIdentifier = "com.apple.mobile.MobileHouseArrest.ExternalTunnel"

    enum TunnelError: LocalizedError {
        case extensionUnavailable
        case preferencesUnavailable
        case startFailed(String)
        case connectionTimeout

        var errorDescription: String? {
            switch self {
            case .extensionUnavailable:
                return "La extensión ExternalTunnel no está disponible en esta instalación."
            case .preferencesUnavailable:
                return "iOS no permitió leer o guardar la configuración del túnel."
            case .startFailed(let detail):
                return detail.isEmpty ? "iOS no pudo iniciar el túnel Hybrid." : detail
            case .connectionTimeout:
                return "El túnel Hybrid no llegó al estado conectado a tiempo."
            }
        }
    }

    private(set) var manager: NETunnelProviderManager?
    private(set) var lastError: Error?
    private var statusObserver: NSObjectProtocol?

    private override init() {
        super.init()
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.recordStatus()
        }
    }

    deinit {
        if let statusObserver {
            NotificationCenter.default.removeObserver(statusObserver)
        }
    }

    var status: NEVPNStatus { manager?.connection.status ?? .invalid }
    var isActive: Bool {
        status == .connected || status == .connecting || status == .reasserting
    }
    var isConfigured: Bool {
        guard let proto = manager?.protocolConfiguration as? NETunnelProviderProtocol else { return false }
        return proto.providerBundleIdentifier == Self.tunnelBundleIdentifier && manager?.isEnabled == true
    }

    func load(completion: @escaping (Result<Void, Error>) -> Void) {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.lastError = error
                    completion(.failure(error))
                    return
                }
                let existing = managers?.first {
                    ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == Self.tunnelBundleIdentifier
                }
                self.manager = existing ?? NETunnelProviderManager()
                completion(.success(()))
            }
        }
    }

    func installOrUpdate(completion: @escaping (Result<Void, Error>) -> Void) {
        load { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success:
                guard NSClassFromString("NETunnelProviderManager") != nil else {
                    let error = TunnelError.extensionUnavailable
                    self.lastError = error
                    completion(.failure(error))
                    return
                }

                let manager = self.manager ?? NETunnelProviderManager()
                let proto = (manager.protocolConfiguration as? NETunnelProviderProtocol) ?? NETunnelProviderProtocol()
                proto.providerBundleIdentifier = Self.tunnelBundleIdentifier
                proto.serverAddress = "10.7.0.1"
                proto.providerConfiguration = [
                    "TunnelIfaceIP": "10.7.1.1/32",
                    "TunnelPeerIP": "10.7.0.1/32",
                    "HybridMode": true,
                    "Flow": "jailbreak-hybrid"
                ]
                manager.protocolConfiguration = proto
                manager.localizedDescription = "Nyxel External Hybrid"
                manager.isEnabled = true
                manager.saveToPreferences { error in
                    DispatchQueue.main.async {
                        if let error {
                            self.lastError = error
                            completion(.failure(error))
                        } else {
                            self.manager = manager
                            completion(.success(()))
                        }
                    }
                }
            }
        }
    }

    /// Instala la configuración, inicia el túnel y espera un estado real.
    func start(timeout: TimeInterval = 15.0, completion: @escaping (Result<Void, Error>) -> Void) {
        installOrUpdate { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success:
                guard let connection = self.manager?.connection else {
                    let error = TunnelError.preferencesUnavailable
                    self.lastError = error
                    completion(.failure(error))
                    return
                }
                if connection.status == .connected {
                    completion(.success(()))
                    return
                }

                do {
                    try connection.startVPNTunnel()
                } catch {
                    let wrapped = TunnelError.startFailed(error.localizedDescription)
                    self.lastError = wrapped
                    completion(.failure(wrapped))
                    return
                }
                self.waitForConnected(timeout: timeout, completion: completion)
            }
        }
    }

    func stop() {
        manager?.connection.stopVPNTunnel()
        NyxelActivityLog.record("Hybrid VPN: detención solicitada")
    }

    private func waitForConnected(timeout: TimeInterval, completion: @escaping (Result<Void, Error>) -> Void) {
        let deadline = Date().addingTimeInterval(timeout)
        func poll() {
            let current = self.status
            switch current {
            case .connected:
                completion(.success(()))
            case .disconnecting, .disconnected, .invalid:
                if Date() >= deadline {
                    let error = TunnelError.startFailed(Self.statusText(current))
                    self.lastError = error
                    completion(.failure(error))
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: poll)
                }
            case .connecting, .reasserting:
                if Date() >= deadline {
                    let error = TunnelError.connectionTimeout
                    self.lastError = error
                    completion(.failure(error))
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: poll)
                }
            @unknown default:
                let error = TunnelError.startFailed("Estado de túnel no reconocido.")
                self.lastError = error
                completion(.failure(error))
            }
        }
        poll()
    }

    private func recordStatus() {
        let text = Self.statusText(status)
        NyxelActivityLog.record("Hybrid VPN: \(text)")
    }

    static func statusText(_ status: NEVPNStatus) -> String {
        switch status {
        case .connected: return "Conectado"
        case .connecting: return "Conectando"
        case .reasserting: return "Reconectando"
        case .disconnecting: return "Desconectando"
        case .disconnected: return "Desconectado"
        default: return "No configurado"
        }
    }
}
