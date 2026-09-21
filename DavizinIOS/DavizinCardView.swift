import UIKit

final class DavizinCardView: UIView {
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let contentView = UIView()
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
    }

    func addContent(_ view: UIView) {
        contentView.addSubview(view)
        view.davizinPinEdges(to: contentView)
        updateContentConstraints()
    }

    private func configure() {
        backgroundColor = AppTheme.card
        layer.cornerRadius = AppTheme.cardCornerRadius
        layer.cornerCurve = .continuous
        layer.masksToBounds = false
        layer.borderWidth = 1.0
        layer.borderColor = UIColor.white.withAlphaComponent(0.18).cgColor
        layer.shadowColor = AppTheme.accentWarm.cgColor
        layer.shadowOpacity = 0.28
        layer.shadowRadius = 28.0
        layer.shadowOffset = CGSize(width: 0.0, height: 16.0)

        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.layer.cornerRadius = AppTheme.cardCornerRadius
        blurView.layer.cornerCurve = .continuous
        blurView.clipsToBounds = true
        blurView.alpha = 0.72
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
