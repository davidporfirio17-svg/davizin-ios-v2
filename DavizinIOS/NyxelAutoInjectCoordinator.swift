import UIKit

enum NyxelAutoAction: String {
    case inject
    case clean
}

final class NyxelAutoInjectCoordinator {

    static let shared = NyxelAutoInjectCoordinator()
    private init() {}

    private(set) var pendingAction: NyxelAutoAction?
    private var isRunning = false

    func setPending(_ action: NyxelAutoAction) {
        pendingAction = action
    }

    func consumePending() -> NyxelAutoAction? {
        let action = pendingAction
        pendingAction = nil
        return action
    }

    func hasPending() -> Bool {
        pendingAction != nil
    }

    func executeAfterLogin(bridge: DavizinBridge, viewController: ViewController) {
        guard let action = consumePending() else { return }
        guard !isRunning else { return }
        isRunning = true

        switch action {
        case .inject:
            runAutoInject(bridge: bridge, viewController: viewController)
        case .clean:
            runAutoClean(bridge: bridge, viewController: viewController)
        }
    }

    private func runAutoInject(bridge: DavizinBridge, viewController: ViewController) {
        let game = savedGame()
        let mode = savedMode()

        guard let mode else {
            isRunning = false
            showAlert(on: viewController, title: "Auto-Inject", message: "No hay un modo guardado. Selecciona un modo manualmente primero.")
            return
        }

        NyxelActivityLog.record("AutoInject: iniciando flujo automático — game=\(game.rawValue) mode=\(mode.id)")

        viewController.setOperationProgress("Preparando inyección automática...")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let key = bridge.currentKey
            let hwid = bridge.currentHWID

            guard !key.isEmpty else {
                DispatchQueue.main.async {
                    self?.isRunning = false
                    self?.showAlert(on: viewController, title: "Auto-Inject", message: "No hay sesión activa.")
                }
                return
            }

            let result = InjectorService.inject(game: game, mode: mode, key: key, hwid: hwid)

            DispatchQueue.main.async {
                self?.isRunning = false
                if result.success {
                    NyxelActivityLog.record("AutoInject: inyección exitosa, abriendo juego...")
                    viewController.setOperationState(.succeeded(result.message))
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        Self.openGame(game, from: viewController)
                    }
                } else {
                    NyxelActivityLog.record("AutoInject: inyección falló — \(result.message)")
                    viewController.setOperationState(.failed(result.message))
                }
            }
        }
    }

    private func runAutoClean(bridge: DavizinBridge, viewController: ViewController) {
        let game = savedGame()

        NyxelCleanupFlow.markReturnedToNyxel()

        guard NyxelCleanupFlow.stage == .needsCleaning else {
            isRunning = false
            showAlert(on: viewController, title: "Auto-Clean", message: "No hay una sesión pendiente de limpiar.")
            return
        }

        NyxelActivityLog.record("AutoClean: limpiando sesión — game=\(game.rawValue)")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = InjectorService.uninject(game: game)

            DispatchQueue.main.async {
                self?.isRunning = false
                if result.success {
                    NyxelCleanupFlow.markCleaningSucceeded(for: game)
                    NyxelActivityLog.record("AutoClean: limpieza exitosa, abriendo juego...")
                    viewController.setOperationState(.succeeded(result.message))
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        Self.openGame(game, from: viewController)
                    }
                } else {
                    NyxelActivityLog.record("AutoClean: limpieza falló — \(result.message)")
                    viewController.setOperationState(.failed(result.message))
                }
            }
        }
    }

    private func savedGame() -> DavizinGame {
        if let raw = UserDefaults.standard.string(forKey: "dz_last_game"),
           let game = DavizinGame(rawValue: raw) {
            return game
        }
        return .freeFireMax
    }

    private func savedMode() -> DavizinMode? {
        if let id = UserDefaults.standard.string(forKey: "dz_last_mode") {
            return DavizinModeCatalog.mode(id: id)
        }
        return nil
    }

    private static func openGame(_ game: DavizinGame, from viewController: UIViewController) {
        let urls: [URL]
        switch game {
        case .freeFireMax:
            urls = ["freefiremax://", "freefire://"].compactMap(URL.init(string:))
        case .freeFire:
            urls = ["freefireth://", "freefire://"].compactMap(URL.init(string:))
        }

        func attemptOpen(at index: Int) {
            guard index < urls.count else {
                NyxelActivityLog.record("AutoInject: no se pudo abrir el juego")
                return
            }
            UIApplication.shared.open(urls[index], options: [:]) { success in
                if success {
                    NyxelCleanupFlow.markGameOpened()
                    NyxelActivityLog.record("AutoInject: juego abierto — \(game.rawValue)")
                } else {
                    DispatchQueue.main.async { attemptOpen(at: index + 1) }
                }
            }
        }
        attemptOpen(at: 0)
    }

    private func showAlert(on vc: UIViewController, title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        vc.present(alert, animated: true)
    }
}
