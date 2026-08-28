import UIKit

/// Conecta el UI de ARIFIxIOS con la lógica real de Davizin
final class DavizinBridge {

    private weak var vc: ViewController?
    private var countdownTimer: Timer?
    private var remainingSeconds: Int = 0
    private let bundleID = "com.dts.freefiremax"

    func connect(to viewController: ViewController) {
        self.vc = viewController
        viewController.simulateUIStates = false

        // ── Login: validar key con Cloudflare ──────────────────
        viewController.onLoginContinue = { [weak self] key in
            self?.handleLogin(key: key)
        }

        // ── Game selection: el usuario elige y avanza ──────────
        viewController.onGameSelected = { [weak self] _ in
            self?.vc?.showModeSelectionScreen()
        }

        // ── Mode selection: el usuario elige y avanza ──────────
        viewController.onModeSelected = { [weak self] _ in
            self?.vc?.showOperationScreen()
        }

        // ── Operaciones reales ─────────────────────────────────
        viewController.onOperation = { [weak self] operation in
            self?.handleOperation(operation)
        }

        viewController.onClose = {
            // Nada - no cerramos
        }
    }

    // ── Login ──────────────────────────────────────────────────
    private func handleLogin(key: String) {
        vc?.setLoginChecking(true)

        KeyValidator.validate(key: key.uppercased()) { [weak self] success, message, remaining in
            self?.vc?.setLoginChecking(false)

            if success && remaining > 0 {
                self?.vc?.setLoginStatus("Acceso concedido ✓", success: true)
                self?.remainingSeconds = remaining

                // Guardar sesión
                UserDefaults.standard.set(key.uppercased(), forKey: "dz_key")
                UserDefaults.standard.set(remaining, forKey: "dz_remaining")
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "dz_saved_at")

                self?.startCountdown()

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    // Solo hasta selección de juego. El usuario avanza manualmente.
                    self?.vc?.showGameSelectionScreen()
                }
            } else {
                self?.vc?.setLoginStatus(message ?? "Key inválida", success: false)
            }
        }
    }

    // ── Operaciones ────────────────────────────────────────────
    private func handleOperation(_ operation: ARIFIOperationKind) {
        switch operation {

        case .runExploit:
            vc?.setOperationState(.running)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.vc?.setOperationState(.succeeded("Sistema listo ✓"))
            }

        case .inject:
            vc?.setOperationState(.injecting)
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                let result = InjectorService.inject(bundleID: self.bundleID)
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
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                let result = InjectorService.uninject(bundleID: self.bundleID)
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

    // ── Countdown ──────────────────────────────────────────────
    private func startCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.remainingSeconds > 0 {
                self.remainingSeconds -= 1
                UserDefaults.standard.set(
                    UserDefaults.standard.double(forKey: "dz_saved_at"),
                    forKey: "dz_saved_at"
                )
            }
        }
    }

    func countdownString() -> String {
        let d = remainingSeconds / 86400
        let h = (remainingSeconds % 86400) / 3600
        let m = (remainingSeconds % 3600) / 60
        let s = remainingSeconds % 60
        if d > 0 { return String(format: "%dd %02dh %02dm %02ds", d, h, m, s) }
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    // ── Restaurar sesión ───────────────────────────────────────
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
