import UIKit

/// Conecta el UI de ARIFIxIOS con la logica real de Davizin
final class DavizinBridge {

    private weak var vc: ViewController?
    private var countdownTimer: Timer?
    private var remainingSeconds: Int = 0

    /// Modo elegido por el usuario. Define que cache_res se inyecta.
    private var selectedMode: ARIFIMode = .drag

    /// Juego elegido. Define bundle ID y de que slots se descarga.
    private var selectedGame: ARIFIGame = .freeFireMax

    /// Credenciales de la sesion actual. Se usan para descargar el cache_res del Worker.
    private var sessionKey: String = ""
    private var sessionHWID: String = ""

    func connect(to viewController: ViewController) {
        self.vc = viewController
        viewController.simulateUIStates = false

        // Login: validar key con Cloudflare
        viewController.onLoginContinue = { [weak self] key in
            self?.handleLogin(key: key)
        }

        // Game selection: el usuario elige y avanza
        viewController.onGameSelected = { [weak self] game in
            self?.selectedGame = game
            self?.vc?.showModeSelectionScreen()
        }

        // Mode selection: guardamos el modo y avanzamos
        viewController.onModeSelected = { [weak self] mode in
            self?.selectedMode = mode
            self?.vc?.showOperationScreen()
        }

        // Operaciones reales
        viewController.onOperation = { [weak self] operation in
            self?.handleOperation(operation)
        }

        viewController.onClose = {
            // Nada - no cerramos
        }
    }

    // MARK: - Login

    private func handleLogin(key: String) {
        vc?.setLoginChecking(true)

        let upperKey = key.uppercased()

        KeyValidator.validate(key: upperKey) { [weak self] success, message, remaining, notice in
            self?.vc?.setLoginChecking(false)

            if success && remaining > 0 {
                self?.vc?.setLoginStatus("Acceso concedido ✓", success: true)
                self?.remainingSeconds = remaining

                // Guardar credenciales para las descargas de cache_res
                self?.sessionKey = upperKey
                self?.sessionHWID = KeyValidator.getDeviceHWID()

                UserDefaults.standard.set(upperKey, forKey: "dz_key")
                UserDefaults.standard.set(remaining, forKey: "dz_remaining")
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "dz_saved_at")

                self?.startCountdown()

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    // Si el cliente tiene un mensaje personalizado, mostrarlo antes de continuar
                    if let notice = notice, !notice.isEmpty {
                        self?.vc?.showNotice(notice) {
                            self?.vc?.showGameSelectionScreen()
                        }
                    } else {
                        self?.vc?.showGameSelectionScreen()
                    }
                }
            } else {
                self?.vc?.setLoginStatus(message ?? "Key invalida", success: false)
            }
        }
    }

    // MARK: - Operaciones

    private func handleOperation(_ operation: ARIFIOperationKind) {
        switch operation {

        case .runExploit:
            vc?.setOperationState(.running)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.vc?.setOperationState(.succeeded("Sistema listo ✓"))
            }

        case .inject:
            vc?.setOperationState(.injecting)
            let mode = selectedMode
            let game = selectedGame
            let key = sessionKey
            let hwid = sessionHWID
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                let result = InjectorService.inject(game: game, mode: mode, key: key, hwid: hwid)
                DispatchQueue.main.async {
                    self.vc?.setOperationState(
                        result.success
                            ? .succeeded(result.message)
                            : .failed(result.message)
                    )
                }
            }

        case .clean:
            vc?.setOperationState(.cleaning)
            let game = selectedGame
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                let result = InjectorService.uninject(game: game)
                DispatchQueue.main.async {
                    self.vc?.setOperationState(
                        result.success
                            ? .succeeded(result.message)
                            : .failed(result.message)
                    )
                }
            }
        }
    }

    // MARK: - Countdown

    private func startCountdown() {
        countdownTimer?.invalidate()
        // Pintar de inmediato al arrancar
        vc?.setCountdownText(countdownString())
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.remainingSeconds > 0 {
                self.remainingSeconds -= 1
            }
            // Actualizar el contador visible en el header cada segundo
            self.vc?.setCountdownText(self.countdownString())
        }
    }

    func countdownString() -> String {
        let d = remainingSeconds / 86400
        let h = (remainingSeconds % 86400) / 3600
        let m = (remainingSeconds % 3600) / 60
        let s = remainingSeconds % 60
        if d > 0 { return String(format: "⏳ %dd %02dh %02dm %02ds", d, h, m, s) }
        return String(format: "⏳ %02d:%02d:%02d", h, m, s)
    }

    // MARK: - Restaurar sesion

    static func restoreSession() -> (key: String, remaining: Int)? {
        guard let key = UserDefaults.standard.string(forKey: "dz_key"),
              !key.isEmpty else { return nil }
        let saved = UserDefaults.standard.double(forKey: "dz_saved_at")
        let total = UserDefaults.standard.integer(forKey: "dz_remaining")
        guard saved > 0, total > 0 else { return nil }
        let elapsed = Int(Date().timeIntervalSince1970 - saved)
        let rem = max(0, total - elapsed)
        return rem > 0 ? (key, rem) : nil
    }
}
