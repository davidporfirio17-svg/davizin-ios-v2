import UIKit

protocol ModeSelectionViewDelegate: AnyObject {
    func modeSelectionView(_ view: ModeSelectionView, didSelect mode: ARIFIMode)
}

final class ModeSelectionView: UIView {
    weak var delegate: ModeSelectionViewDelegate?

    private let cardView = ARIFICardView()
    private let categoryLabel = UILabel()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let dragButton = ARIFIButton(title: ARIFIMode.drag.rawValue)
    private let footerLabel = UILabel()
    private let stackView = UIStackView()

    private(set) var selectedMode: ARIFIMode?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    func setSelectedMode(_ mode: ARIFIMode?) {
        selectedMode = mode
        dragButton.selectedVisual = mode == .drag
    }

    private func configure() {
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false

        categoryLabel.text = "CHEAT"
        categoryLabel.textColor = AppTheme.tertiaryText
        categoryLabel.font = AppTheme.captionFont()
        categoryLabel.textAlignment = .center
        categoryLabel.adjustsFontForContentSizeCategory = true

        titleLabel.text = "Select Cheat"
        titleLabel.textColor = AppTheme.primaryText
        titleLabel.font = AppTheme.titleFont()
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontForContentSizeCategory = true

        subtitleLabel.text = "Choose the Cheat you want to use."
        subtitleLabel.textColor = AppTheme.secondaryText
        subtitleLabel.font = AppTheme.bodyFont()
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.adjustsFontForContentSizeCategory = true

        dragButton.accessibilityIdentifier = "mode.drag"
        dragButton.addTarget(self, action: #selector(dragTapped), for: .touchUpInside)

        footerLabel.text = "Make sure you use correct method to inject ."
        footerLabel.textColor = AppTheme.secondaryText
        footerLabel.font = AppTheme.captionFont()
        footerLabel.textAlignment = .center
        footerLabel.numberOfLines = 0
        footerLabel.adjustsFontForContentSizeCategory = true

        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.spacing = 12.0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(categoryLabel)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)
        stackView.addArrangedSubview(dragButton)
        stackView.addArrangedSubview(footerLabel)

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addContent(stackView)
        addSubview(cardView)

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 22.0),
            cardView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -22.0),
            cardView.centerXAnchor.constraint(equalTo: centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: centerYAnchor),
            cardView.widthAnchor.constraint(lessThanOrEqualToConstant: AppTheme.contentMaximumWidth),
            stackView.widthAnchor.constraint(greaterThanOrEqualToConstant: 240.0),
            dragButton.heightAnchor.constraint(equalToConstant: AppTheme.controlHeight)
        ])
    }

    @objc private func dragTapped() {
        setSelectedMode(.drag)
        delegate?.modeSelectionView(self, didSelect: .drag)
    }
}
