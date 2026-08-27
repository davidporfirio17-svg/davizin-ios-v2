import SwiftUI

struct RootView: View {
    @StateObject var appState = AppState()
    @State private var navigationStep: NavigationStep = .login
    
    enum NavigationStep {
        case login
        case announcement
        case gameSelection
        case modeSelection
        case operation
    }
    
    var body: some View {
        Group {
            switch navigationStep {
            case .login:
                KeyGateViewContainer(appState: appState, nextStep: {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        navigationStep = .announcement
                    }
                })
                
            case .announcement:
                HomeViewContainer(appState: appState, nextStep: {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        navigationStep = .gameSelection
                    }
                })
                
            case .gameSelection, .modeSelection, .operation:
                // Por ahora mostrar announcement, pendiente integrar UIKit
                HomeViewContainer(appState: appState, nextStep: {
                    appState.logout()
                    withAnimation(.easeInOut(duration: 0.4)) {
                        navigationStep = .login
                    }
                })
            }
        }
        .preferredColorScheme(.dark)
    }
}

// Wrapper para KeyGateView con callback
struct KeyGateViewContainer: View {
    @ObservedObject var appState: AppState
    let nextStep: () -> Void
    
    var body: some View {
        KeyGateView(appState: appState, onSuccess: nextStep)
    }
}

// Wrapper para HomeView con callback
struct HomeViewContainer: View {
    @ObservedObject var appState: AppState
    let nextStep: () -> Void
    
    var body: some View {
        HomeView(appState: appState, onContinue: nextStep)
    }
}

#Preview {
    RootView()
}
