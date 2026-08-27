import UIKit

final class ARIFICardView: UIView {
    private let contentView = UIView()
    private var contentConstraints: [NSLayoutConstraint] = []

    var contentInsets: UIEdgeInsets = UIEdgeInsets(
        top: AppTheme.cardPadding,
        left: AppTheme.cardPadding,
        bottom: AppTheme.cardPadding,
        right: AppTheme.cardPadding
    ) {
        didSet {
            updateContentConstraints()
        }
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
        layer.shadowPath = UIBezierPath(
            roundedRect: bounds,
            cornerRadius: AppTheme.cardCornerRadius
        ).cgPath
    }

    func addContent(_ view: UIView) {
        contentView.addSubview(view)
        view.arifiPinEdges(to: contentView)
        updateContentConstraints()
    }

    private func configure() {
        backgroundColor = AppTheme.card
        layer.cornerRadius = AppTheme.cardCornerRadius
        layer.masksToBounds = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.34
        layer.shadowRadius = 22.0
        layer.shadowOffset = CGSize(width: 0.0, height: 10.0)

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
