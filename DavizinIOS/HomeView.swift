import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    let onContinue: () -> Void
    
    @State private var pulseInjected = false

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.08).ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        headerSection
                        expirationBannerLarge
                        continueButton
                        Spacer().frame(height: 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                }
                
                countdownBarSmall
            }
        }
    }
    
    // MARK: - Anuncio Grande
    var expirationBannerLarge: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.orange)
                Text("Tu Key Expira")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Fecha de vencimiento")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.4))
                    
                    Text(formatExpirationDate(appState.expirationDate()))
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(.orange)
                }
                Spacer()
            }
            
            HStack(spacing: 8) {
                countdownBox(value: appState.remainingDays, label: "días")
                countdownBox(value: appState.remainingHours, label: "horas")
                countdownBox(value: appState.remainingMinutes, label: "min")
                countdownBox(value: appState.remainingSeconds, label: "seg", isBlink: true)
            }
            .frame(height: 80)
            
            if appState.remainingDays <= 3 && appState.remainingDays > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("Tu key expira en poco tiempo.")
                        .font(.system(size: 12))
                        .foregroundColor(.red.opacity(0.8))
                    Spacer()
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.red.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.red.opacity(0.2), lineWidth: 1))
            }
            
            if appState.isExpired {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text("Tu key ha expirado.")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.red.opacity(0.15)))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.red.opacity(0.3), lineWidth: 1))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.03))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.orange.opacity(0.2), lineWidth: 1.5)))
    }
    
    // MARK: - Botón continuar
    var continueButton: some View {
        Button(action: onContinue) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.right.circle.fill")
                Text("CONTINUAR A OPERACIÓN")
                    .font(.system(size: 15, weight: .bold))
                    .tracking(0.5)
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(RoundedRectangle(cornerRadius: 14)
                .fill(LinearGradient(colors: [.cyan, Color(red: 0.0, green: 0.7, blue: 1.0)], startPoint: .leading, endPoint: .trailing))
                .shadow(color: .cyan.opacity(0.35), radius: 10, y: 4))
        }
        .disabled(appState.isExpired)
    }
    
    func countdownBox(value: Int, label: String, isBlink: Bool = false) -> some View {
        VStack(spacing: 3) {
            Text(String(format: "%02d", value))
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(Color(red: 0.0, green: 0.8, blue: 1.0))
                .frame(height: 30)
                .opacity(isBlink && value % 2 == 0 ? 0.6 : 1.0)
                .animation(.linear(duration: 0.5).repeatForever(autoreverses: true), value: value)
            
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.white.opacity(0.35))
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.cyan.opacity(0.15), lineWidth: 1))
    }

    var countdownBarSmall: some View {
        HStack(spacing: 10) {
            Image(systemName: appState.isExpired ? "xmark.circle.fill" : "clock.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(appState.isExpired ? .red : .cyan)
            
            VStack(alignment: .leading, spacing: 1) {
                Text("Expira en")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                
                HStack(spacing: 4) {
                    if appState.isExpired {
                        Text("Expirada")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.red)
                    } else {
                        HStack(spacing: 3) {
                            Text(String(format: "%dd", appState.remainingDays))
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                            Text(String(format: "%02dh", appState.remainingHours))
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                            Text(String(format: "%02dm", appState.remainingMinutes))
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                            Text(String(format: "%02ds", appState.remainingSeconds))
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.cyan)
                        }
                        .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.08), lineWidth: 1)))
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    func formatExpirationDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "es_MX")
        return formatter.string(from: date)
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
}
