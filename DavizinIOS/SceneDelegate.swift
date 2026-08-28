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
        let rootViewController = ViewController()
        rootViewController.modalPresentationStyle = .fullScreen

        // Conecta la lógica real (login, inyección, limpieza).
        // Sin esto el ViewController queda en modo simulación.
        let bridge = DavizinBridge()
        bridge.connect(to: rootViewController)
        self.bridge = bridge

        window.rootViewController = rootViewController
        self.window = window
        window.makeKeyAndVisible()
    }

    func sceneWillResignActive(_ scene: UIScene) {}
    func sceneDidBecomeActive(_ scene: UIScene) {}
}
