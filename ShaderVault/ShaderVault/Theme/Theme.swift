import SwiftUI

enum SV {
    // MARK: - Primary Palette
    static let emerald = Color(red: 0, green: 0.878, blue: 0.627)
    static let emeraldDark = Color(red: 0, green: 0.706, blue: 0.502)
    static let violet = Color(red: 0.659, green: 0.510, blue: 1.0)
    static let gold = Color(red: 1.0, green: 0.753, blue: 0.251)
    static let cyan = Color(red: 0.235, green: 0.839, blue: 0.882)
    static let rose = Color(red: 1.0, green: 0.420, blue: 0.420)
    static let sky = Color(red: 0.392, green: 0.706, blue: 0.902)

    // MARK: - Surfaces
    static let bg = Color("bg", bundle: nil)
    static let surface = Color("surface", bundle: nil)

    // MARK: - Adaptive Colors
    static func background(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.012, green: 0.012, blue: 0.024)
            : Color(red: 0.949, green: 0.973, blue: 0.965)
    }

    static func surface(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.027, green: 0.027, blue: 0.051)
            : Color(red: 0.980, green: 1.0, blue: 0.996)
    }

    static func card(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.043, green: 0.043, blue: 0.078)
            : Color(red: 1.0, green: 1.0, blue: 1.0)
    }

    static func border(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? emerald.opacity(0.08)
            : Color(red: 0, green: 0.47, blue: 0.31).opacity(0.08)
    }

    static func textPrimary(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.91, green: 0.92, blue: 0.92)
            : Color(red: 0.06, green: 0.07, blue: 0.07)
    }

    static func textSecondary(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.50, green: 0.52, blue: 0.52)
            : Color(red: 0.38, green: 0.40, blue: 0.40)
    }

    static func textTertiary(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.26, green: 0.28, blue: 0.28)
            : Color(red: 0.60, green: 0.62, blue: 0.62)
    }

    // MARK: - Gradient
    static let brandGradient = LinearGradient(
        colors: [emerald, violet, gold],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let emeraldGradient = LinearGradient(
        colors: [emerald, emeraldDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Typography
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .rounded)
    }

    static func heading(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static func body(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }

    static func mono(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }

    static func label(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
}

// MARK: - Badge Style

struct SVBadge: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
                .shadow(color: color.opacity(0.5), radius: 3)
            Text(text)
                .font(SV.label(9))
                .tracking(0.8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 999)
                .stroke(color.opacity(0.12), lineWidth: 1)
        )
        .clipShape(Capsule())
        .foregroundStyle(color)
    }
}

// MARK: - Card Modifier

struct SVCard: ViewModifier {
    @Environment(\.colorScheme) var scheme

    func body(content: Content) -> some View {
        content
            .background(SV.card(scheme))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(SV.border(scheme), lineWidth: 1)
            )
    }
}

extension View {
    func svCard() -> some View {
        modifier(SVCard())
    }
}
