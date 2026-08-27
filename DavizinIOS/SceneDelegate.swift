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

        let vc = ViewController()

        // Conectar lógica real
        let bridge = DavizinBridge()
        bridge.connect(to: vc)
        self.bridge = bridge

        // Crear ventana con tamaño COMPLETO de la pantalla
        let window = UIWindow(windowScene: windowScene)
        window.frame = UIScreen.main.bounds
        window.rootViewController = vc
        self.window = window
        window.makeKeyAndVisible()

        // Restaurar sesión si existe
        if let saved = DavizinBridge.restoreSession() {
            _ = saved
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                vc.showGameSelectionScreen()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    vc.showModeSelectionScreen()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        vc.showOperationScreen()
                    }
                }
            }
        }
    }

    func sceneWillResignActive(_ scene: UIScene) {}
    func sceneDidBecomeActive(_ scene: UIScene) {}
}
