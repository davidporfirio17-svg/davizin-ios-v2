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

        // Crear y conectar el bridge
        let bridge = DavizinBridge()
        bridge.connect(to: vc)
        self.bridge = bridge

        // Si hay sesión guardada, saltar el login
        if let saved = DavizinBridge.restoreSession() {
            bridge.connect(to: vc)
            vc.setLoginChecking(false)
            // Ir directo a la pantalla de operación
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                vc.showGameSelectionScreen()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    vc.showModeSelectionScreen()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        vc.showOperationScreen()
                    }
                }
            }
        }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = vc
        self.window = window
        window.makeKeyAndVisible()
    }
}
