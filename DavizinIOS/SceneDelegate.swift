import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var bridge: DavizinBridge?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        if let url = connectionOptions.urlContexts.first?.url,
           url.scheme == "nyxelext",
           let action = NyxelAutoAction(rawValue: url.host ?? "") {
            NyxelAutoInjectCoordinator.shared.setPending(action)
            NyxelActivityLog.record("URL scheme en launch: \(url.absoluteString)")
        }

        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)

        // 1. Splash de marca (anillo dibujandose) — se muestra siempre al abrir.
        let splash = SplashViewController()
        splash.modalPresentationStyle = .fullScreen
        splash.onFinished = { [weak self] in
            self?.showMainApp(in: window)
        }

        window.rootViewController = splash
        self.window = window
        window.makeKeyAndVisible()
    }

    /// 2. Flujo principal real: login -> entorno -> mapa de mision -> operacion.
    private func showMainApp(in window: UIWindow) {
        let compatStatus = NyxelSupportPolicy.status.label
        nyxelLog("Scene loading: Compatibility status = \(compatStatus)", level: "INFO")

        let rootViewController = ViewController()
        rootViewController.modalPresentationStyle = .fullScreen

        let bridge = DavizinBridge()
        bridge.connect(to: rootViewController)
        self.bridge = bridge

        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {
            window.rootViewController = rootViewController
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url,
              url.scheme == "nyxelext",
              let action = NyxelAutoAction(rawValue: url.host ?? "") else { return }
        NyxelAutoInjectCoordinator.shared.setPending(action)
        NyxelActivityLog.record("URL scheme recibido: \(url.absoluteString)")

        if let bridge, let vc = window?.rootViewController as? ViewController,
           !bridge.currentKey.isEmpty {
            vc.showOperationScreen()
            NyxelAutoInjectCoordinator.shared.executeAfterLogin(bridge: bridge, viewController: vc)
        }
    }

    func sceneWillResignActive(_ scene: UIScene) {}
    func sceneDidBecomeActive(_ scene: UIScene) {}
}
