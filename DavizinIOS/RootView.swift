import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Group {
            if appState.isAuthenticated {
                HomeView(onContinue: {
                    // Continuaremos integrando UIKit después
                })
            } else {
                KeyGateView(onSuccess: {
                    // KeyGateView ya llamó appState.saveKey()
                })
            }
        }
        .animation(.easeInOut(duration: 0.4), value: appState.isAuthenticated)
    }
}

#Preview {
    RootView()
        .environmentObject(AppState())
}
