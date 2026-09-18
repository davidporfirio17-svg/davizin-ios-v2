import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var bridge: DavizinBridge?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)

        // 1. Splash de marca (anillo dibujandose) — se muestra siempre al abrir.
        let splash = SplashViewController()
        splash.modalPresentationStyle = .fullScreen
        splash.onFinished = { [weak self] in
            self?.afterSplash(in: window)
        }

        window.rootViewController = splash
        self.window = window
        window.makeKeyAndVisible()
    }

    /// 2. Consulta si hay un aviso activo publicado. Si lo hay, se muestra antes
    ///    del login. Si no, entra directo — sin pantalla vacia, sin parpadeo.
    private func afterSplash(in window: UIWindow) {
        NoticeService.fetchActiveNotice { [weak self] notice in
            DispatchQueue.main.async {
                if let notice = notice {
                    let noticeVC = NoticeViewController(notice: notice)
                    noticeVC.modalPresentationStyle = .fullScreen
                    noticeVC.onContinue = { [weak self] in
                        self?.showMainApp(in: window)
                    }
                    window.rootViewController = noticeVC
                } else {
                    self?.showMainApp(in: window)
                }
            }
        }
    }

    /// 3. Flujo principal real: login -> entorno -> mapa de mision -> operacion.
    private func showMainApp(in window: UIWindow) {
        let rootViewController = ViewController()
        rootViewController.modalPresentationStyle = .fullScreen

        let bridge = DavizinBridge()
        bridge.connect(to: rootViewController)
        self.bridge = bridge

        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {
            window.rootViewController = rootViewController
        }
    }

    func sceneWillResignActive(_ scene: UIScene) {}
    func sceneDidBecomeActive(_ scene: UIScene) {}
}
