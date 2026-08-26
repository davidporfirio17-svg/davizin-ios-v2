import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var showConfirmInject = false
    @State private var showConfirmUninject = false
    @State private var resultMessage = ""
    @State private var showResult = false
    @State private var resultSuccess = false
    @State private var pulseInjected = false

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.08).ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    headerSection
                    statusCard
                    gameCard
                    patchesSection
                    actionButtons
                    if showResult { resultCard.transition(.opacity) }
                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.isInjected)
        .animation(.easeInOut(duration: 0.3), value: showResult)
        .confirmationDialog("¿Inyectar ahora?", isPresented: $showConfirmInject, titleVisibility: .visible) {
            Button("Inyectar") { performInject() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se reemplazará el cache_res de \(appState.freeFireName). El original quedará guardado.")
        }
        .confirmationDialog("¿Restaurar original?", isPresented: $showConfirmUninject, titleVisibility: .visible) {
            Button("Restaurar", role: .destructive) { performUninject() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se restaurará el cache_res original de \(appState.freeFireName).")
        }
    }

    var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("DAVIZIN")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.cyan, Color(red: 0.0, green: 0.7, blue: 1.0)], startPoint: .leading, endPoint: .trailing))
                    .shadow(color: .cyan.opacity(0.4), radius: 8)
                Text("iOS Injector v\(appState.appVersion)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
                    .tracking(1.5)
            }
            Spacer()
            Button { appState.logout() } label: {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(10)
                    .background(Circle().fill(Color.white.opacity(0.06)))
            }
        }
        .padding(.top, 10)
    }

    var statusCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(appState.isInjected ? Color.green.opacity(0.2) : Color.orange.opacity(0.15))
                    .frame(width: 50, height: 50)
                if appState.isInjected {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 50, height: 50)
                        .scaleEffect(pulseInjected ? 1.3 : 1.0)
                        .opacity(pulseInjected ? 0 : 0.5)
                        .animation(.easeOut(duration: 1.5).repeatForever(autoreverses: false), value: pulseInjected)
                        .onAppear { pulseInjected = true }
                }
                Image(systemName: appState.isInjected ? "checkmark.circle.fill" : "circle.dashed")
                    .font(.system(size: 24))
                    .foregroundColor(appState.isInjected ? .green : .orange)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(appState.isInjected ? "INYECTADO" : "NO INYECTADO")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(appState.isInjected ? .green : .orange)
                Text(appState.isInjected ? "Mod activo en Free Fire" : "Original activo en Free Fire")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.45))
            }
            Spacer()
            Text(appState.isInjected ? "ACTIVO" : "INACTIVO")
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundColor(appState.isInjected ? .green : .orange)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(appState.isInjected ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                    .overlay(Capsule().strokeBorder(appState.isInjected ? Color.green.opacity(0.4) : Color.orange.opacity(0.4), lineWidth: 1)))
        }
        .padding(18)
        .background(cardBG)
    }

    var gameCard: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(colors: [Color(red: 1.0, green: 0.3, blue: 0.1), Color(red: 0.8, green: 0.1, blue: 0.0)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 56, height: 56)
                Image(systemName: "flame.fill").font(.system(size: 26)).foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(appState.freeFireName).font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                Text(appState.freeFireBundleID).font(.system(size: 11, weight: .regular, design: .monospaced)).foregroundColor(.white.opacity(0.3)).lineLimit(1)
            }
            Spacer()
            HStack(spacing: 5) {
                Circle().fill(Color.green).frame(width: 6, height: 6)
                Text("Instalado").font(.system(size: 12)).foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(16).background(cardBG)
    }

    var patchesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bandage.fill").foregroundColor(.cyan).font(.system(size: 14))
                Text("PATCHES").font(.system(size: 13, weight: .bold)).foregroundColor(.white.opacity(0.6)).tracking(2)
                Spacer()
                Text("1 disponible").font(.system(size: 12)).foregroundColor(.white.opacity(0.3))
            }
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(Color.cyan.opacity(0.12)).frame(width: 44, height: 44)
                    Image(systemName: "puzzlepiece.extension.fill").font(.system(size: 20)).foregroundColor(.cyan)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Davizin Shaders").font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                    Text("cache_res • Efectos visuales personalizados").font(.system(size: 12)).foregroundColor(.white.opacity(0.4))
                }
                Spacer()
                ZStack {
                    Capsule()
                        .fill(appState.isInjected ? Color.cyan.opacity(0.2) : Color.white.opacity(0.08))
                        .frame(width: 44, height: 26)
                        .overlay(Capsule().strokeBorder(appState.isInjected ? Color.cyan.opacity(0.5) : Color.white.opacity(0.15), lineWidth: 1))
                    Circle()
                        .fill(appState.isInjected ? Color.cyan : Color.white.opacity(0.4))
                        .frame(width: 20, height: 20)
                        .offset(x: appState.isInjected ? 9 : -9)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(appState.isInjected ? Color.cyan.opacity(0.3) : Color.white.opacity(0.07), lineWidth: 1)))
        }
        .padding(16).background(cardBG)
    }

    var actionButtons: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // INJECT
                Button { showConfirmInject = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "syringe.fill").font(.system(size: 16))
                        Text("INYECTAR").font(.system(size: 15, weight: .bold)).tracking(0.5)
                    }
                    .foregroundColor(appState.isInjected ? .white.opacity(0.3) : .black)
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .background(injectBtnBG)
                }
                .disabled(appState.isInjected || appState.isWorking)

                // UNINJECT
                Button { showConfirmUninject = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.uturn.backward.circle.fill").font(.system(size: 16))
                        Text("RESTAURAR").font(.system(size: 15, weight: .bold)).tracking(0.5)
                    }
                    .foregroundColor(appState.isInjected ? .red : .white.opacity(0.3))
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(appState.isInjected ? Color.red.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1)))
                }
                .disabled(!appState.isInjected || appState.isWorking)
            }

            if appState.isWorking {
                HStack(spacing: 10) {
                    ProgressView().tint(.cyan)
                    Text(appState.statusMessage).font(.system(size: 13)).foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    var injectBtnBG: some View {
        if appState.isInjected {
            RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.08))
        } else {
            RoundedRectangle(cornerRadius: 14)
                .fill(LinearGradient(colors: [.cyan, Color(red: 0.0, green: 0.7, blue: 1.0)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: .cyan.opacity(0.35), radius: 10, y: 4)
        }
    }

    var resultCard: some View {
        HStack(spacing: 12) {
            Image(systemName: resultSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(resultSuccess ? .green : .red)
            Text(resultMessage).font(.system(size: 14)).foregroundColor(.white.opacity(0.8)).multilineTextAlignment(.leading)
            Spacer()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14)
            .fill(resultSuccess ? Color.green.opacity(0.08) : Color.red.opacity(0.08))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(resultSuccess ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)))
    }

    var cardBG: some View {
        RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.04))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }

    private func performInject() {
        appState.isWorking = true
        appState.statusMessage = "Inyectando..."
        showResult = false
        DispatchQueue.global(qos: .userInitiated).async {
            let result = InjectorService.inject(bundleID: appState.freeFireBundleID)
            DispatchQueue.main.async {
                appState.isWorking = false
                resultSuccess = result.success
                resultMessage = result.message
                withAnimation { showResult = true; if result.success { appState.isInjected = true } }
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) { withAnimation { showResult = false } }
            }
        }
    }

    private func performUninject() {
        appState.isWorking = true
        appState.statusMessage = "Restaurando original..."
        showResult = false
        DispatchQueue.global(qos: .userInitiated).async {
            let result = InjectorService.uninject(bundleID: appState.freeFireBundleID)
            DispatchQueue.main.async {
                appState.isWorking = false
                resultSuccess = result.success
                resultMessage = result.message
                withAnimation { showResult = true; if result.success { appState.isInjected = false } }
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) { withAnimation { showResult = false } }
            }
        }
    }
}
