import UIKit

enum NyxelAutoAction: String {
    case inject
    case clean
    case auto
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
        case .auto:
            runAutoFull(bridge: bridge, viewController: viewController)
        }
    }

    private func runAutoFull(bridge: DavizinBridge, viewController: ViewController) {
        let game = savedGame()
        let mode = savedMode()

        guard let mode else {
            isRunning = false
            showAlert(on: viewController, title: "Auto", message: "No hay un modo guardado. Selecciona un modo manualmente primero.")
            return
        }

        NyxelCleanupFlow.markReturnedToNyxel()

        if NyxelCleanupFlow.stage == .needsCleaning {
            NyxelActivityLog.record("Auto: limpieza pendiente, limpiando primero...")
            viewController.setOperationProgress("Limpiando sesión anterior...")

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let result = InjectorService.uninject(game: game)

                DispatchQueue.main.async {
                    if result.success {
                        NyxelCleanupFlow.markCleaningSucceeded(for: game)
                        NyxelCleanupFlow.finishCycle()
                        NyxelActivityLog.record("Auto: limpieza exitosa, continuando con inyección...")
                        self?.runAutoFullInject(bridge: bridge, viewController: viewController, game: game, mode: mode)
                    } else {
                        self?.isRunning = false
                        NyxelActivityLog.record("Auto: limpieza falló — \(result.message)")
                        viewController.setOperationState(.failed("Limpieza falló: \(result.message)"))
                    }
                }
            }
        } else {
            runAutoFullInject(bridge: bridge, viewController: viewController, game: game, mode: mode)
        }
    }

    private func runAutoFullInject(bridge: DavizinBridge, viewController: ViewController, game: DavizinGame, mode: DavizinMode) {
        NyxelActivityLog.record("Auto: inyectando — game=\(game.rawValue) mode=\(mode.id)")
        viewController.setOperationProgress("Inyectando automáticamente...")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let key = bridge.currentKey
            let hwid = bridge.currentHWID

            guard !key.isEmpty else {
                DispatchQueue.main.async {
                    self?.isRunning = false
                    self?.showAlert(on: viewController, title: "Auto", message: "No hay sesión activa.")
                }
                return
            }

            let result = InjectorService.inject(game: game, mode: mode, key: key, hwid: hwid)

            DispatchQueue.main.async {
                self?.isRunning = false
                if result.success {
                    NyxelActivityLog.record("Auto: inyección exitosa, abriendo juego...")
                    viewController.setOperationState(.succeeded(result.message))
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        Self.openGame(game, from: viewController)
                        Self.scheduleBackgroundClean(for: game, delay: 6.0)
                    }
                } else {
                    NyxelActivityLog.record("Auto: inyección falló — \(result.message)")
                    viewController.setOperationState(.failed(result.message))
                }
            }
        }
    }

    private static func scheduleBackgroundClean(for game: DavizinGame, delay: TimeInterval) {
        var bgTask: UIBackgroundTaskIdentifier = .invalid
        bgTask = UIApplication.shared.beginBackgroundTask {
            UIApplication.shared.endBackgroundTask(bgTask)
            bgTask = .invalid
        }

        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + delay) {
            NyxelCleanupFlow.markReturnedToNyxel()
            NyxelCleanupFlow.prepareForRelaunch()

            let result = InjectorService.uninject(game: game)
            if result.success {
                NyxelCleanupFlow.markCleaningSucceeded(for: game)
                NyxelCleanupFlow.finishCycle()
                NyxelActivityLog.record("Auto: limpieza automática en background — exitosa")
            } else {
                NyxelActivityLog.record("Auto: limpieza automática en background — falló: \(result.message)")
            }

            UIApplication.shared.endBackgroundTask(bgTask)
            bgTask = .invalid
        }
    }

    private func runAutoInject(bridge: DavizinBridge, viewController: ViewController) {
        let game = savedGame()
        let mode = savedMode()

        guard let mode else {
            isRunning = false
            showAlert(on: viewController, title: "Auto", message: "No hay un modo guardado. Selecciona un modo manualmente primero.")
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
                    self?.showAlert(on: viewController, title: "Auto", message: "No hay sesión activa.")
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
                    NyxelCleanupFlow.finishCycle()
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
                NyxelActivityLog.record("Auto: no se pudo abrir el juego")
                return
            }
            UIApplication.shared.open(urls[index], options: [:]) { success in
                if success {
                    NyxelCleanupFlow.markGameOpened()
                    NyxelActivityLog.record("Auto: juego abierto — \(game.rawValue)")
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
