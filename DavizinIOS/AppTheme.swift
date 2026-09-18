import UIKit

// MARK: - AppTheme v3 — Nyxel Final (ember/fuego)
// Paleta exacta del prototipo HTML aprobado (nyxel-final.html):
// fondo con tinte cafe-rojizo (NO negro puro), acento "ember" cian-fuego,
// tipografia condensada pesada para titulos, mono para datos.

enum AppTheme {
    static let background      = UIColor(red: 0.051, green: 0.043, blue: 0.031, alpha: 1.0)  // #0D0906
    static let backgroundRaise = UIColor(red: 0.086, green: 0.075, blue: 0.059, alpha: 1.0)   // #16130F
    static let card            = backgroundRaise
    static let hairline        = UIColor(white: 1.0, alpha: 0.10)
    static let hairlineStrong  = UIColor(white: 1.0, alpha: 0.20)

    static let primaryText     = UIColor(red: 0.984, green: 0.953, blue: 0.925, alpha: 1.0)   // #FBF3EC
    static let secondaryText   = UIColor(red: 0.984, green: 0.953, blue: 0.925, alpha: 0.60)
    static let tertiaryText    = UIColor(red: 0.984, green: 0.953, blue: 0.925, alpha: 0.32)

    static let success         = UIColor(red: 0.498, green: 0.839, blue: 0.541, alpha: 1.0)   // #7FD68A
    static let failure         = UIColor(red: 1.000, green: 0.361, blue: 0.361, alpha: 1.0)   // #FF5C5C
    static let warm            = UIColor(red: 1.000, green: 0.690, blue: 0.125, alpha: 1.0)   // #FFB020
    static let accentWarm      = warm  // alias: nombre usado en LoginView/DavizinBridge/ARIFICardView existentes

    static let accent          = UIColor(red: 0.0, green: 1.0, blue: 0.761, alpha: 1.0)       // #00FFC2
    static let accentHot       = UIColor(red: 0.498, green: 1.0, blue: 0.878, alpha: 1.0)     // #7FFFE0
    static let accentDim       = UIColor(red: 0.0, green: 1.0, blue: 0.761, alpha: 0.14)

    // Alias de compatibilidad con codigo existente (ARIFIButton, LoginView) que
    // referencia nombres de la paleta anterior. Apuntan a los tokens nuevos.
    static let control         = card
    static let separator       = hairline

    static let cardCornerRadius:    CGFloat = 18.0
    static let controlCornerRadius: CGFloat = 14.0
    static let standardSpacing:     CGFloat = 14.0
    static let cardPadding:         CGFloat = 22.0
    static let contentMaximumWidth: CGFloat = 320.0
    static let controlHeight:       CGFloat = 52.0

    static func titleFont(_ size: CGFloat = 26) -> UIFont { UIFont.systemFont(ofSize: size, weight: .black) }
    static func bodyFont()    -> UIFont { UIFont.systemFont(ofSize: 13, weight: .regular) }
    static func captionFont() -> UIFont { UIFont.systemFont(ofSize: 10, weight: .heavy) }
    static func controlFont() -> UIFont { UIFont.systemFont(ofSize: 13, weight: .heavy) }
    static func monoFont(_ size: CGFloat = 12) -> UIFont { UIFont.monospacedSystemFont(ofSize: size, weight: .semibold) }

    static let titleTracking: CGFloat = -0.6

    static func easeOutTiming() -> UICubicTimingParameters {
        UICubicTimingParameters(controlPoint1: CGPoint(x: 0.22, y: 1.0), controlPoint2: CGPoint(x: 0.36, y: 1.0))
    }
    static func drawerTiming() -> UICubicTimingParameters {
        UICubicTimingParameters(controlPoint1: CGPoint(x: 0.32, y: 0.72), controlPoint2: CGPoint(x: 0.0, y: 1.0))
    }

    static let durationButtonPress: TimeInterval = 0.15
    static let durationPopover: TimeInterval = 0.20
    static let durationModal: TimeInterval = 0.30
    static let durationDrawer: TimeInterval = 0.45

    static func countdownColor(remainingSeconds: Int) -> UIColor {
        if remainingSeconds <= 3600 { return failure }
        if remainingSeconds <= 86400 { return warm }
        return success
    }
}

extension UIView {
    func arifiPinEdges(to view: UIView, insets: UIEdgeInsets = .zero) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: insets.left),
            trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -insets.right),
            topAnchor.constraint(equalTo: view.topAnchor, constant: insets.top),
            bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -insets.bottom)
        ])
    }

    func applyTitleTracking(_ label: UILabel, value: CGFloat = AppTheme.titleTracking) {
        guard let text = label.text else { return }
        let attr = NSMutableAttributedString(string: text)
        attr.addAttribute(.kern, value: value, range: NSRange(location: 0, length: text.count))
        label.attributedText = attr
    }
}
