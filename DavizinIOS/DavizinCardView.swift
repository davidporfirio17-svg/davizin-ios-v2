import UIKit

final class DavizinCardView: UIView {
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private let contentView = UIView()
    private let glassHighlight = CAGradientLayer()
    private var contentConstraints: [NSLayoutConstraint] = []

    var contentInsets: UIEdgeInsets = UIEdgeInsets(
        top: AppTheme.cardPadding,
        left: AppTheme.cardPadding,
        bottom: AppTheme.cardPadding,
        right: AppTheme.cardPadding
    ) {
        didSet { updateContentConstraints() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: AppTheme.cardCornerRadius).cgPath
        glassHighlight.frame = bounds
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle else { return }
        layer.borderColor = AppTheme.hairlineStrong.resolvedColor(with: traitCollection).cgColor
    }

    func addContent(_ view: UIView) {
        contentView.addSubview(view)
        view.davizinPinEdges(to: contentView)
        updateContentConstraints()
    }

    func useTransparentAppearance() {
        // Un velo oscuro tenue + un poco mas de blur: mantiene el look glass pero
        // evita que el fondo de marca se transparente sobre el texto.
        backgroundColor = AppTheme.background.withAlphaComponent(0.38)
        blurView.alpha = 0.24
        layer.borderColor = UIColor.white.withAlphaComponent(0.13).cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.26
        layer.shadowRadius = 30.0
        layer.shadowOffset = CGSize(width: 0.0, height: 14.0)
        glassHighlight.colors = [
            UIColor.white.withAlphaComponent(0.085).cgColor,
            UIColor.white.withAlphaComponent(0.018).cgColor,
            UIColor.clear.cgColor
        ]
        glassHighlight.locations = [0.0, 0.14, 0.46]
        glassHighlight.startPoint = CGPoint(x: 0.5, y: 0.0)
        glassHighlight.endPoint = CGPoint(x: 0.5, y: 1.0)
        glassHighlight.cornerRadius = AppTheme.cardCornerRadius
        glassHighlight.masksToBounds = true
        layer.insertSublayer(glassHighlight, at: 0)
    }

    private func configure() {
        backgroundColor = AppTheme.card
        layer.cornerRadius = AppTheme.cardCornerRadius
        layer.cornerCurve = .continuous
        layer.masksToBounds = false
        layer.borderWidth = 1.0
        layer.borderColor = AppTheme.hairlineStrong.resolvedColor(with: traitCollection).cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.22
        layer.shadowRadius = 18.0
        layer.shadowOffset = CGSize(width: 0.0, height: 10.0)

        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.layer.cornerRadius = AppTheme.cardCornerRadius
        blurView.layer.cornerCurve = .continuous
        blurView.clipsToBounds = true
        blurView.alpha = 0.62
        addSubview(blurView)
        blurView.davizinPinEdges(to: self)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentView)
        updateContentConstraints()
    }

    private func updateContentConstraints() {
        guard contentView.superview != nil else { return }
        NSLayoutConstraint.deactivate(contentConstraints)
        contentConstraints = [
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: contentInsets.left),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -contentInsets.right),
            contentView.topAnchor.constraint(equalTo: topAnchor, constant: contentInsets.top),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -contentInsets.bottom)
        ]
        NSLayoutConstraint.activate(contentConstraints)
    }
}
