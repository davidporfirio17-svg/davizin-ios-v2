import UIKit

enum AppTheme {
    // Colores — fondo azul eléctrico como ARIFIxIOS
    static let background      = UIColor(red: 0.02, green: 0.04, blue: 0.16, alpha: 1.0)
    static let card            = UIColor(red: 0.06, green: 0.10, blue: 0.28, alpha: 1.0)
    static let control         = UIColor(red: 0.10, green: 0.16, blue: 0.38, alpha: 1.0)
    static let controlHighlighted = UIColor(red: 0.16, green: 0.24, blue: 0.50, alpha: 1.0)
    static let primaryText     = UIColor.white
    static let secondaryText   = UIColor(white: 0.75, alpha: 1.0)
    static let tertiaryText    = UIColor(white: 0.50, alpha: 1.0)
    static let separator       = UIColor(white: 1.0, alpha: 0.10)
    static let success         = UIColor(red: 0.30, green: 0.90, blue: 0.55, alpha: 1.0)
    static let failure         = UIColor(red: 1.00, green: 0.35, blue: 0.35, alpha: 1.0)
    static let accent          = UIColor(red: 0.20, green: 0.55, blue: 1.00, alpha: 1.0)

    static let cardCornerRadius:    CGFloat = 16.0
    static let controlCornerRadius: CGFloat = 12.0
    static let standardSpacing:     CGFloat = 12.0
    static let cardPadding:         CGFloat = 20.0
    static let contentMaximumWidth: CGFloat = 430.0
    static let controlHeight:       CGFloat = 52.0

    static func titleFont()   -> UIFont { UIFont.systemFont(ofSize: 22, weight: .bold) }
    static func bodyFont()    -> UIFont { UIFont.systemFont(ofSize: 15, weight: .regular) }
    static func captionFont() -> UIFont { UIFont.systemFont(ofSize: 12, weight: .semibold) }
    static func controlFont() -> UIFont { UIFont.systemFont(ofSize: 16, weight: .semibold) }
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
