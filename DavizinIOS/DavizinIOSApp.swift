import SwiftUI

@main
struct DavizinIOSApp: App {
    @StateObject var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
        }
    }
}
