import UIKit

// MARK: - DavizinButton v2
// Press feedback: scale(0.97), 150ms — recipe "Button press" de animate/RECIPES.md,
// portado a UIKit con spring en vez de cubic-bezier (nativo UIKit no anima bien
// cubic-bezier + transform combinados en highlighted state, spring da mejor feel físico).

enum DavizinButtonStyle {
    case primary
    case secondary
    case destructive
}

final class DavizinButton: UIButton {
    private let spinner = UIActivityIndicatorView(style: .medium)
    private var titleBeforeLoading: String?
    private var style: DavizinButtonStyle = .secondary

    var selectedVisual: Bool = false {
        didSet { updateAppearance() }
    }

    override var isHighlighted: Bool {
        didSet {
            updateAppearance()
            // Recipe "Button press": scale(0.97), no scale(0) nunca.
            UIView.animate(
                withDuration: AppTheme.durationButtonPress,
                delay: 0.0,
                usingSpringWithDamping: 0.72,
                initialSpringVelocity: 0.4,
                options: [.allowUserInteraction, .beginFromCurrentState]
            ) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
            }
        }
    }

    override var isEnabled: Bool {
        didSet { updateAppearance() }
    }

    convenience init(title: String, style: DavizinButtonStyle = .secondary) {
        self.init(type: .system)
        self.style = style
        setTitle(title, for: .normal)
        configure()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    func setButtonStyle(_ style: DavizinButtonStyle) {
        self.style = style
        updateAppearance()
    }

    func setLoading(_ loading: Bool, title: String? = nil) {
        if loading {
            titleBeforeLoading = currentTitle
            isEnabled = false
            setTitle(title ?? currentTitle, for: .normal)
            spinner.startAnimating()
            spinner.isHidden = false
            accessibilityValue = title ?? "Loading"
        } else {
            spinner.stopAnimating()
            spinner.isHidden = true
            isEnabled = true
            if let titleBeforeLoading = titleBeforeLoading {
                setTitle(titleBeforeLoading, for: .normal)
            }
            titleBeforeLoading = nil
            accessibilityValue = nil
        }
        updateAppearance()
    }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false
        titleLabel?.font = AppTheme.controlFont()
        titleLabel?.adjustsFontForContentSizeCategory = true
        layer.cornerRadius = AppTheme.controlCornerRadius
        layer.cornerCurve = .continuous
        contentEdgeInsets = UIEdgeInsets(top: 14.0, left: 18.0, bottom: 14.0, right: 18.0)

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.hidesWhenStopped = true
        addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerYAnchor.constraint(equalTo: centerYAnchor),
            spinner.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18.0)
        ])
        updateAppearance()
    }

    private func updateAppearance() {
        let baseColor: UIColor
        let titleColor: UIColor
        let borderColor: UIColor

        switch style {
        case .primary:
            baseColor = AppTheme.accent
            titleColor = AppTheme.background
            borderColor = AppTheme.accent
        case .secondary:
            baseColor = selectedVisual ? AppTheme.accent : AppTheme.control
            titleColor = selectedVisual ? AppTheme.background : AppTheme.primaryText
            borderColor = selectedVisual ? AppTheme.accent : UIColor.white.withAlphaComponent(0.10)
        case .destructive:
            baseColor = UIColor(red: 0.20, green: 0.05, blue: 0.06, alpha: 1.0)
            titleColor = UIColor(red: 1.0, green: 0.55, blue: 0.48, alpha: 1.0)
            borderColor = AppTheme.failure.withAlphaComponent(0.45)
        }

        let enabledAlpha: CGFloat = isEnabled ? 1.0 : 0.45
        let highlightAlpha: CGFloat = isHighlighted ? 0.80 : 1.0
        let visualAlpha = enabledAlpha * highlightAlpha
        backgroundColor = baseColor.withAlphaComponent(visualAlpha)
        setTitleColor(titleColor.withAlphaComponent(visualAlpha), for: .normal)
        layer.borderWidth = selectedVisual || style != .secondary ? 1.0 : 0.0
        layer.borderColor = borderColor.withAlphaComponent(visualAlpha).cgColor
        layer.shadowColor = selectedVisual || style == .primary ? AppTheme.accent.cgColor : UIColor.clear.cgColor
        layer.shadowOpacity = selectedVisual || style == .primary ? 0.28 : 0.0
        layer.shadowRadius = 14.0
        layer.shadowOffset = CGSize(width: 0, height: 6)
        spinner.color = titleColor
    }
}
