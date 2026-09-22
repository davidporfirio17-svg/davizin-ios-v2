import UIKit

protocol GameSelectionViewDelegate: AnyObject {
    func gameSelectionView(_ view: GameSelectionView, didSelect game: DavizinGame)
}

final class GameSelectionView: UIView {
    weak var delegate: GameSelectionViewDelegate?

    private let cardView = DavizinCardView()
    private let categoryLabel = UILabel()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let freeFireButton = DavizinButton(title: "FREE FIRE", style: .secondary)
    private let freeFireMaxButton = DavizinButton(title: "FREE FIRE MAX", style: .secondary)
    private let stackView = UIStackView()

    private(set) var selectedGame: DavizinGame?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    func setSelectedGame(_ game: DavizinGame?) {
        selectedGame = game
        freeFireButton.selectedVisual = game == .freeFire
        freeFireMaxButton.selectedVisual = game == .freeFireMax
    }

    private func configure() {
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false

        categoryLabel.text = "01 / ENTORNO"
        categoryLabel.textColor = AppTheme.tertiaryText
        categoryLabel.font = AppTheme.captionFont()
        categoryLabel.textAlignment = .center
        categoryLabel.adjustsFontForContentSizeCategory = true

        titleLabel.text = "Elige tu entorno"
        titleLabel.textColor = AppTheme.primaryText
        titleLabel.font = AppTheme.titleFont()
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontForContentSizeCategory = true

        subtitleLabel.text = "Selecciona la versión que quieres preparar."
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
        cardView.setBackgroundVideo(resourceName: "game_selection_preview")
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
