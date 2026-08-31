import UIKit

enum AppTheme {
    // UI Option 5: sunset glassmorphism.
    static let background      = UIColor(red: 0.16, green: 0.055, blue: 0.13, alpha: 1.0)
    static let card            = UIColor(red: 0.30, green: 0.105, blue: 0.23, alpha: 0.82)
    static let control         = UIColor(red: 0.44, green: 0.16, blue: 0.30, alpha: 0.74)
    static let controlHighlighted = UIColor(red: 1.00, green: 0.43, blue: 0.42, alpha: 1.0)
    static let primaryText     = UIColor(red: 1.00, green: 0.96, blue: 0.95, alpha: 1.0)
    static let secondaryText   = UIColor(red: 0.95, green: 0.78, blue: 0.82, alpha: 1.0)
    static let tertiaryText    = UIColor(red: 1.00, green: 0.62, blue: 0.66, alpha: 0.80)
    static let separator       = UIColor(red: 1.00, green: 0.72, blue: 0.70, alpha: 0.24)
    static let success         = UIColor(red: 0.61, green: 1.00, blue: 0.80, alpha: 1.0)
    static let failure         = UIColor(red: 1.00, green: 0.45, blue: 0.46, alpha: 1.0)
    static let accent          = UIColor(red: 1.00, green: 0.47, blue: 0.42, alpha: 1.0)
    static let accentWarm      = UIColor(red: 1.00, green: 0.72, blue: 0.40, alpha: 1.0)

    static let cardCornerRadius:    CGFloat = 26.0
    static let controlCornerRadius: CGFloat = 18.0
    static let standardSpacing:     CGFloat = 14.0
    static let cardPadding:         CGFloat = 24.0
    static let contentMaximumWidth: CGFloat = 460.0
    static let controlHeight:       CGFloat = 58.0

    static func titleFont()   -> UIFont { UIFont.systemFont(ofSize: 28, weight: .heavy) }
    static func bodyFont()    -> UIFont { UIFont.systemFont(ofSize: 15, weight: .regular) }
    static func captionFont() -> UIFont { UIFont.systemFont(ofSize: 11, weight: .bold) }
    static func controlFont() -> UIFont { UIFont.systemFont(ofSize: 15, weight: .bold) }
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
}
