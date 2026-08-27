import UIKit

/// Valores visuales centralizados para que el UI pueda ajustarse sin tocar las pantallas.
enum AppTheme {
    static let background = UIColor.black
    static let card = UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)
    static let control = UIColor(red: 0.16, green: 0.16, blue: 0.17, alpha: 1.0)
    static let controlHighlighted = UIColor(red: 0.23, green: 0.23, blue: 0.24, alpha: 1.0)
    static let primaryText = UIColor.white
    static let secondaryText = UIColor(white: 0.68, alpha: 1.0)
    static let tertiaryText = UIColor(white: 0.48, alpha: 1.0)
    static let separator = UIColor(white: 1.0, alpha: 0.08)
    static let success = UIColor(red: 0.42, green: 0.88, blue: 0.57, alpha: 1.0)
    static let failure = UIColor(red: 1.0, green: 0.36, blue: 0.36, alpha: 1.0)

    static let cardCornerRadius: CGFloat = 18.0
    static let controlCornerRadius: CGFloat = 12.0
    static let standardSpacing: CGFloat = 12.0
    static let cardPadding: CGFloat = 22.0
    static let contentMaximumWidth: CGFloat = 430.0
    static let controlHeight: CGFloat = 50.0

    static func titleFont() -> UIFont {
        UIFont.systemFont(ofSize: 22.0, weight: .bold)
    }

    static func bodyFont() -> UIFont {
        UIFont.systemFont(ofSize: 15.0, weight: .regular)
    }

    static func captionFont() -> UIFont {
        UIFont.systemFont(ofSize: 11.0, weight: .semibold)
    }

    static func controlFont() -> UIFont {
        UIFont.systemFont(ofSize: 16.0, weight: .semibold)
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
}
