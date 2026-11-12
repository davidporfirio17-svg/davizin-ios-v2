import UIKit

protocol GameSelectionViewDelegate: AnyObject {
    func gameSelectionView(_ view: GameSelectionView, didSelect game: DavizinGame)
}

final class GameSelectionView: UIView {
    weak var delegate: GameSelectionViewDelegate?
    var onOpenPlayer: (() -> Void)?
    var onOpenProfile: (() -> Void)?
    var onOpenHelp: (() -> Void)?

    private let cardView = DavizinCardView()
    private let categoryLabel = UILabel()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let freeFireButton = DavizinButton(title: "FREE FIRE", style: .secondary)
    private let freeFireMaxButton = DavizinButton(title: "FREE FIRE MAX", style: .secondary)
    private let freeFireSubtitle = UILabel()
    private let freeFireMaxSubtitle = UILabel()
    private let freeFireCompatibility = UILabel()
    private let freeFireMaxCompatibility = UILabel()
    private let stackView = UIStackView()
    private let sessionIcon = UIImageView()
    private let sessionStatusLabel = UILabel()
    private let connectivityIcon = UIImageView()
    private let connectivityStatusLabel = UILabel()
    private var connectivityObserver: NSObjectProtocol?

    private(set) var selectedGame: DavizinGame?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    deinit {
        if let connectivityObserver { NotificationCenter.default.removeObserver(connectivityObserver) }
    }

    func setSessionStatus(keyAuthorized: Bool, remainingSeconds: Int) {
        let active = keyAuthorized && remainingSeconds > 0
        sessionIcon.image = UIImage(systemName: active ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
        sessionIcon.tintColor = active ? AppTheme.success : AppTheme.accentWarm
        if active {
            let days = remainingSeconds / 86400
            let hours = (remainingSeconds % 86400) / 3600
            let minutes = (remainingSeconds % 3600) / 60
            let remaining: String
            if days > 0 {
                remaining = days == 1 ? "1 día \(hours) h" : "\(days) días \(hours) h"
            } else {
                remaining = "\(hours) h \(minutes) min"
            }
            sessionStatusLabel.text = "Acceso Nyxel activo · \(remaining) restantes"
            sessionStatusLabel.textColor = AppTheme.primaryText
        } else {
            sessionStatusLabel.text = keyAuthorized ? "Tu acceso Nyxel expiró" : "Sesión Nyxel no disponible"
            sessionStatusLabel.textColor = AppTheme.accentWarm
        }
    }

    private func setConnectivityStatus(_ connected: Bool?) {
        switch connected {
        case .some(true):
            connectivityIcon.image = UIImage(systemName: "wifi")
            connectivityIcon.tintColor = AppTheme.success
            connectivityStatusLabel.text = "Internet disponible"
            connectivityStatusLabel.textColor = AppTheme.primaryText
        case .some(false):
            connectivityIcon.image = UIImage(systemName: "wifi.slash")
            connectivityIcon.tintColor = AppTheme.failure
            connectivityStatusLabel.text = "Sin internet · revisa Wi-Fi o datos móviles"
            connectivityStatusLabel.textColor = AppTheme.accentWarm
        case .none:
            connectivityIcon.image = UIImage(systemName: "network")
            connectivityIcon.tintColor = AppTheme.secondaryText
            connectivityStatusLabel.text = "Comprobando conexión…"
            connectivityStatusLabel.textColor = AppTheme.secondaryText
        }
    }

    func setSelectedGame(_ game: DavizinGame?) {
        selectedGame = game
        freeFireButton.selectedVisual = game == .freeFire
        freeFireMaxButton.selectedVisual = game == .freeFireMax
        freeFireSubtitle.text = game == .freeFire ? "✓ SELECCIONADO · ESTÁNDAR" : "Entorno estándar"
        freeFireMaxSubtitle.text = game == .freeFireMax ? "✓ SELECCIONADO · OPTIMIZADO" : "Entorno optimizado"
        freeFireSubtitle.textColor = game == .freeFire ? AppTheme.accent : AppTheme.tertiaryText
        freeFireMaxSubtitle.textColor = game == .freeFireMax ? AppTheme.accent : AppTheme.tertiaryText
        refreshCompatibilityIndicators()
    }

    private func refreshCompatibilityIndicators() {
        let systemOK = NyxelSupportPolicy.isCurrentSystemSupported
        let freeFireOK = systemOK && InjectorService.isBundleAvailable(for: .freeFire)
        let freeFireMaxOK = systemOK && InjectorService.isBundleAvailable(for: .freeFireMax)
        freeFireCompatibility.text = freeFireOK ? "● Bundle compatible" : "● Bundle no compatible"
        freeFireMaxCompatibility.text = freeFireMaxOK ? "● Bundle compatible" : "● Bundle no compatible"
        freeFireCompatibility.textColor = freeFireOK ? AppTheme.success : AppTheme.failure
        freeFireMaxCompatibility.textColor = freeFireMaxOK ? AppTheme.success : AppTheme.failure
    }

    private func configure() {
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false

        categoryLabel.text = "INICIO · ESTADO GENERAL"
        categoryLabel.textColor = AppTheme.tertiaryText
        categoryLabel.font = AppTheme.captionFont()
        categoryLabel.textAlignment = .center
        categoryLabel.adjustsFontForContentSizeCategory = true
        applyTitleTracking(categoryLabel, value: 1.2)

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
        subtitleLabel.textColor = AppTheme.secondaryText.withAlphaComponent(0.78)

        freeFireButton.accessibilityIdentifier = "game.freeFire"
        freeFireMaxButton.accessibilityIdentifier = "game.freeFireMax"
        freeFireButton.accessibilityValue = "Entorno estándar"
        freeFireButton.accessibilityHint = "Selecciona Free Fire como entorno."
        freeFireMaxButton.accessibilityValue = "Entorno optimizado"
        freeFireMaxButton.accessibilityHint = "Selecciona Free Fire MAX como entorno."
        freeFireButton.setImage(UIImage(systemName: "flame.fill"), for: .normal)
        freeFireMaxButton.setImage(UIImage(systemName: "flame.circle.fill"), for: .normal)
        freeFireButton.tintColor = AppTheme.accent
        freeFireMaxButton.tintColor = AppTheme.accent
        freeFireButton.contentHorizontalAlignment = .left
        freeFireMaxButton.contentHorizontalAlignment = .left
        freeFireSubtitle.text = "Entorno estándar"
        freeFireMaxSubtitle.text = "Entorno optimizado"
        [freeFireSubtitle, freeFireMaxSubtitle].forEach {
            $0.font = AppTheme.captionFont()
            $0.textAlignment = .left
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        [freeFireCompatibility, freeFireMaxCompatibility].forEach {
            $0.font = AppTheme.captionFont()
            $0.textAlignment = .left
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        refreshCompatibilityIndicators()
        freeFireButton.addTarget(self, action: #selector(freeFireTapped), for: .touchUpInside)
        freeFireMaxButton.addTarget(self, action: #selector(freeFireMaxTapped), for: .touchUpInside)

        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.spacing = 12.0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(categoryLabel)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)

        sessionIcon.image = UIImage(systemName: "checkmark.shield.fill")
        sessionIcon.contentMode = .scaleAspectFit
        sessionIcon.widthAnchor.constraint(equalToConstant: 18).isActive = true
        sessionIcon.heightAnchor.constraint(equalToConstant: 18).isActive = true
        connectivityIcon.image = UIImage(systemName: "network")
        connectivityIcon.contentMode = .scaleAspectFit
        connectivityIcon.widthAnchor.constraint(equalToConstant: 18).isActive = true
        connectivityIcon.heightAnchor.constraint(equalToConstant: 18).isActive = true
        [sessionStatusLabel, connectivityStatusLabel].forEach {
            $0.font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: .systemFont(ofSize: 13, weight: .semibold))
            $0.adjustsFontForContentSizeCategory = true
            $0.numberOfLines = 0
        }
        let sessionRow = UIStackView(arrangedSubviews: [sessionIcon, sessionStatusLabel])
        let connectivityRow = UIStackView(arrangedSubviews: [connectivityIcon, connectivityStatusLabel])
        [sessionRow, connectivityRow].forEach { $0.axis = .horizontal; $0.alignment = .center; $0.spacing = 9 }
        let statusStack = UIStackView(arrangedSubviews: [sessionRow, connectivityRow])
        statusStack.axis = .vertical
        statusStack.spacing = 10
        statusStack.translatesAutoresizingMaskIntoConstraints = false
        let statusPanel = UIView()
        statusPanel.backgroundColor = AppTheme.background.withAlphaComponent(0.55)
        statusPanel.layer.cornerRadius = 13
        statusPanel.layer.borderWidth = 1
        statusPanel.layer.borderColor = AppTheme.hairlineStrong.cgColor
        statusPanel.addSubview(statusStack)
        NSLayoutConstraint.activate([
            statusStack.leadingAnchor.constraint(equalTo: statusPanel.leadingAnchor, constant: 12),
            statusStack.trailingAnchor.constraint(equalTo: statusPanel.trailingAnchor, constant: -12),
            statusStack.topAnchor.constraint(equalTo: statusPanel.topAnchor, constant: 12),
            statusStack.bottomAnchor.constraint(equalTo: statusPanel.bottomAnchor, constant: -12)
        ])
        stackView.addArrangedSubview(statusPanel)
        setSessionStatus(keyAuthorized: false, remainingSeconds: 0)
        setConnectivityStatus(NyxelConnectivity.isConnected)
        connectivityObserver = NotificationCenter.default.addObserver(
            forName: .nyxelConnectivityDidChange,
            object: nil,
            queue: .main
        ) { [weak self] note in
            self?.setConnectivityStatus(note.object as? Bool)
        }

        let freeFireChoice = UIStackView(arrangedSubviews: [freeFireButton, freeFireSubtitle, freeFireCompatibility])
        let freeFireMaxChoice = UIStackView(arrangedSubviews: [freeFireMaxButton, freeFireMaxSubtitle, freeFireMaxCompatibility])
        [freeFireChoice, freeFireMaxChoice].forEach {
            $0.axis = .vertical
            $0.alignment = .fill
            $0.spacing = 3.0
        }
        stackView.addArrangedSubview(freeFireChoice)
        stackView.addArrangedSubview(freeFireMaxChoice)

        let shortcuts = UIStackView(arrangedSubviews: [
            makeShortcut(title: "JUGADOR", symbol: "person.crop.square.fill", action: #selector(playerShortcutTapped)),
            makeShortcut(title: "CUENTA", symbol: "person.crop.circle.fill", action: #selector(profileShortcutTapped)),
            makeShortcut(title: "AYUDA", symbol: "questionmark.circle.fill", action: #selector(helpShortcutTapped))
        ])
        shortcuts.axis = .horizontal
        shortcuts.distribution = .fillEqually
        shortcuts.spacing = 8
        stackView.addArrangedSubview(shortcuts)
        setConnectivityStatus(NyxelConnectivity.isConnected)

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.useTransparentAppearance()
        cardView.addContent(stackView)
        addSubview(cardView)

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 22.0),
            cardView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -22.0),
            cardView.centerXAnchor.constraint(equalTo: centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: centerYAnchor),
            cardView.widthAnchor.constraint(lessThanOrEqualToConstant: UIDevice.current.userInterfaceIdiom == .pad ? 560.0 : AppTheme.contentMaximumWidth),
            stackView.widthAnchor.constraint(greaterThanOrEqualToConstant: UIDevice.current.userInterfaceIdiom == .pad ? 360.0 : 240.0),
            freeFireButton.heightAnchor.constraint(equalToConstant: AppTheme.controlHeight),
            freeFireMaxButton.heightAnchor.constraint(equalToConstant: AppTheme.controlHeight),
            freeFireSubtitle.heightAnchor.constraint(equalToConstant: 14.0),
            freeFireMaxSubtitle.heightAnchor.constraint(equalToConstant: 14.0),
            freeFireCompatibility.heightAnchor.constraint(equalToConstant: 14.0),
            freeFireMaxCompatibility.heightAnchor.constraint(equalToConstant: 14.0)
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

    private func makeShortcut(title: String, symbol: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setImage(UIImage(systemName: symbol), for: .normal)
        button.tintColor = AppTheme.readableAccent
        button.setTitleColor(AppTheme.primaryText, for: .normal)
        button.titleLabel?.font = UIFontMetrics(forTextStyle: .caption1).scaledFont(for: .systemFont(ofSize: 10, weight: .bold))
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.backgroundColor = AppTheme.background.withAlphaComponent(0.48)
        button.layer.cornerRadius = 10
        button.layer.borderWidth = 1
        button.layer.borderColor = AppTheme.hairline.cgColor
        button.heightAnchor.constraint(equalToConstant: 42).isActive = true
        button.accessibilityLabel = title.capitalized
        button.accessibilityHint = "Abre la sección \(title.lowercased())."
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    @objc private func playerShortcutTapped() { onOpenPlayer?() }
    @objc private func profileShortcutTapped() { onOpenProfile?() }
    @objc private func helpShortcutTapped() { onOpenHelp?() }
}
