import UIKit

enum ARIFIButtonStyle {
    case primary
    case secondary
    case destructive
}

final class ARIFIButton: UIButton {
    private let spinner = UIActivityIndicatorView(style: .medium)
    private var titleBeforeLoading: String?
    private var style: ARIFIButtonStyle = .secondary

    var selectedVisual: Bool = false {
        didSet {
            updateAppearance()
        }
    }

    override var isHighlighted: Bool {
        didSet {
            updateAppearance()
        }
    }

    override var isEnabled: Bool {
        didSet {
            updateAppearance()
        }
    }

    convenience init(title: String, style: ARIFIButtonStyle = .secondary) {
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

    func setButtonStyle(_ style: ARIFIButtonStyle) {
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
        contentEdgeInsets = UIEdgeInsets(top: 14.0, left: 16.0, bottom: 14.0, right: 16.0)

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.hidesWhenStopped = true
        addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerYAnchor.constraint(equalTo: centerYAnchor),
            spinner.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16.0)
        ])
        updateAppearance()
    }

    private func updateAppearance() {
        let baseColor: UIColor
        let titleColor: UIColor
        switch style {
        case .primary:
            baseColor = AppTheme.primaryText
            titleColor = .black
        case .secondary:
            baseColor = selectedVisual ? AppTheme.controlHighlighted : AppTheme.control
            titleColor = AppTheme.primaryText
        case .destructive:
            baseColor = UIColor(red: 0.27, green: 0.10, blue: 0.11, alpha: 1.0)
            titleColor = UIColor(red: 1.0, green: 0.55, blue: 0.55, alpha: 1.0)
        }

        let enabledAlpha: CGFloat = isEnabled ? 1.0 : 0.55
        let highlightAlpha: CGFloat = isHighlighted ? 0.72 : 1.0
        let visualAlpha = enabledAlpha * highlightAlpha
        backgroundColor = baseColor.withAlphaComponent(visualAlpha)
        setTitleColor(titleColor.withAlphaComponent(visualAlpha), for: .normal)
        layer.borderWidth = selectedVisual ? 1.0 : 0.0
        layer.borderColor = AppTheme.primaryText.withAlphaComponent(0.45).cgColor
    }
}
