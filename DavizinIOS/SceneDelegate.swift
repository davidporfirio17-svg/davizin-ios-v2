import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        // DavizinIOSApp ya maneja la creación de la ventana SwiftUI
        // No necesitamos hacer nada aquí
    }

    func sceneWillResignActive(_ scene: UIScene) {}
    func sceneDidBecomeActive(_ scene: UIScene) {}
}
