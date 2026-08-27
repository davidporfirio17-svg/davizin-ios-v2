import UIKit

protocol GameSelectionViewDelegate: AnyObject {
    func gameSelectionView(_ view: GameSelectionView, didSelect game: ARIFIGame)
}

final class GameSelectionView: UIView {
    weak var delegate: GameSelectionViewDelegate?

    private let cardView = ARIFICardView()
    private let categoryLabel = UILabel()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let freeFireButton = ARIFIButton(title: ARIFIGame.freeFire.rawValue)
    private let freeFireMaxButton = ARIFIButton(title: ARIFIGame.freeFireMax.rawValue)
    private let stackView = UIStackView()

    private(set) var selectedGame: ARIFIGame?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    func setSelectedGame(_ game: ARIFIGame?) {
        selectedGame = game
        freeFireButton.selectedVisual = game == .freeFire
        freeFireMaxButton.selectedVisual = game == .freeFireMax
    }

    private func configure() {
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false

        categoryLabel.text = "GAME"
        categoryLabel.textColor = AppTheme.tertiaryText
        categoryLabel.font = AppTheme.captionFont()
        categoryLabel.textAlignment = .center
        categoryLabel.adjustsFontForContentSizeCategory = true

        titleLabel.text = "Choose your version"
        titleLabel.textColor = AppTheme.primaryText
        titleLabel.font = AppTheme.titleFont()
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontForContentSizeCategory = true

        subtitleLabel.text = "Select the version you want to use."
        subtitleLabel.textColor = AppTheme.secondaryText
        subtitleLabel.font = AppTheme.bodyFont()
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.adjustsFontForContentSizeCategory = true

        freeFireButton.accessibilityIdentifier = "game.freeFire"
        freeFireMaxButton.accessibilityIdentifier = "game.freeFireMax"
        freeFireButton.addTarget(self, action: #selector(freeFireTapped), for: .touchUpInside)
        freeFireMaxButton.addTarget(self, action: #selector(freeFireMaxTapped), for: .touchUpInside)

        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.spacing = 12.0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(categoryLabel)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)
        stackView.addArrangedSubview(freeFireButton)
        stackView.addArrangedSubview(freeFireMaxButton)

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
            freeFireButton.heightAnchor.constraint(equalToConstant: AppTheme.controlHeight),
            freeFireMaxButton.heightAnchor.constraint(equalToConstant: AppTheme.controlHeight)
        ])
    }

    @objc private func freeFireTapped() {
        setSelectedGame(.freeFire)
        delegate?.gameSelectionView(self, didSelect: .freeFire)
    }

    @objc private func freeFireMaxTapped() {
        setSelectedGame(.freeFireMax)
        delegate?.gameSelectionView(self, didSelect: .freeFireMax)
    }
}
