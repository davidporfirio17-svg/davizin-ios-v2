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
        // Restaurar el ultimo juego y modo elegidos
        if let g = UserDefaults.standard.string(forKey: "dz_last_game"), let game = ARIFIGame(rawValue: g) {
            selectedGame = game
        }
        if let m = UserDefaults.standard.string(forKey: "dz_last_mode"), let mode = ARIFIModeCatalog.mode(id: m) {
            selectedMode = mode
        }
        viewController.simulateUIStates = false

        // Login: validar key con Cloudflare
        viewController.onLoginContinue = { [weak self] key in
            self?.handleLogin(key: key)
        }

        // Game selection: el usuario elige y avanza
        viewController.onGameSelected = { [weak self] game in
            self?.selectedGame = game
            UserDefaults.standard.set(game.rawValue, forKey: "dz_last_game")
            self?.vc?.showModeSelectionScreen()
        }

        // Mode selection: guardamos el modo y avanzamos
        viewController.onModeSelected = { [weak self] mode in
            self?.selectedMode = mode
            UserDefaults.standard.set(mode.rawValue, forKey: "dz_last_mode")
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

    private func performInjection(game: ARIFIGame, mode: ARIFIMode, key: String, hwid: String) {
        vc?.setOperationState(.injecting)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let result = InjectorService.inject(game: game, mode: mode, key: key, hwid: hwid)
            if result.success && mode.oneTime && mode.id == "holograma" {
                self.consumeOneTimeMode(mode: mode, key: key, hwid: hwid, result: result)
            } else {
                DispatchQueue.main.async {
                    self.hapticFeedback(success: result.success)
                    self.vc?.setOperationState(result.success ? .succeeded(result.message) : .failed(result.message))
                }
            }
        }
    }

    private func consumeOneTimeMode(mode: ARIFIMode, key: String, hwid: String, result: InjectorResult) {
        guard let url = URL(string: "https://dz.davidporfirio17.workers.dev/consume-mode") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["key": key, "hwid": hwid, "mode": mode.id])
        URLSession.shared.dataTask(with: request) { [weak self] data, response, _ in
            let ok = (response as? HTTPURLResponse)?.statusCode == 200 && ((try? JSONSerialization.jsonObject(with: data ?? Data()) as? [String: Any])?["success"] as? Bool == true)
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.hapticFeedback(success: ok)
                if ok { ARIFIModeCatalog.markConsumed(mode.id) }
                self.vc?.setOperationState(ok ? .succeeded(result.message) : .failed("La inyección se realizó, pero no se pudo confirmar el consumo de Holograma. No vuelvas a intentarlo hasta revisar la conexión."))
            }
        }.resume()
    }

    private func handleOperation(_ operation: ARIFIOperationKind) {
        switch operation {

        case .runExploit:
            vc?.setOperationState(.running)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.vc?.setOperationState(.succeeded("Sistema listo ✓"))
            }

        case .inject:
            let mode = selectedMode
            let game = selectedGame
            let key = sessionKey
            let hwid = sessionHWID
            if mode.oneTime && mode.id == "holograma" && !mode.consumed {
                vc?.showNotice("⚠️ Holograma Pro — uso único\n\nUna vez inyectado correctamente, Holograma desaparecerá definitivamente de esta key. Si eliminas Free Fire o borras sus archivos, no será posible recuperarlo con esta misma key. Para volver a utilizarlo necesitarás una key Pro nueva. ¿Deseas continuar?") { [weak self] in
                    self?.vc?.showNotice("🔴 Confirmación final\n\nEsta acción consumirá permanentemente Holograma de esta key y no se puede deshacer. ¿Confirmas la inyección?") { [weak self] in
                        self?.performInjection(game: game, mode: mode, key: key, hwid: hwid)
                    }
                }
            } else {
                performInjection(game: game, mode: mode, key: key, hwid: hwid)
            }

        case .clean:
            vc?.setOperationState(.cleaning)
            let game = selectedGame
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                let result = InjectorService.uninject(game: game)
                DispatchQueue.main.async {
                    self.hapticFeedback(success: result.success)
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
        vc?.setCountdownColor(countdownColor())
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.remainingSeconds > 0 {
                self.remainingSeconds -= 1
            }
            // Actualizar el contador visible en el header cada segundo
            self.vc?.setCountdownText(self.countdownString())
            self.vc?.setCountdownColor(self.countdownColor())
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

    /// Color del contador segun el tiempo restante.
    private func countdownColor() -> UIColor {
        if remainingSeconds <= 3600 {          // menos de 1 hora -> rojo
            return AppTheme.failure
        } else if remainingSeconds <= 86400 {  // menos de 1 dia -> amarillo
            return AppTheme.accentWarm
        } else {                                // mas de 1 dia -> verde
            return AppTheme.success
        }
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

    /// Vibracion segun resultado: exito (suave) o error (fuerte).
    private func hapticFeedback(success: Bool) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(success ? .success : .error)
    }

}
