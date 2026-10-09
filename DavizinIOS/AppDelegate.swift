import UIKit
import UserNotifications

@_silgen_name("ALGetGrappaToken")
private func retainGrappaTokenSymbol(
    _ version: UInt32,
    _ deviceType: UInt32,
    _ protocolVersion: UInt32,
    _ output: UnsafeMutablePointer<UInt8>?,
    _ maximumLength: Int,
    _ outputLength: UnsafeMutablePointer<Int>?,
    _ errorBuffer: UnsafeMutablePointer<CChar>?,
    _ errorLength: Int
) -> Int32

@main
final class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Initialize Nyxel logging and system detection
        _ = retainGrappaTokenSymbol(0, 0, 0, nil, 0, nil, nil, 0)
        UNUserNotificationCenter.current().delegate = self
        application.logNyxelLaunchInfo()
        return true
    }

    /// Mostrar el recordatorio aunque Nyxel todavía esté en primer plano.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}
