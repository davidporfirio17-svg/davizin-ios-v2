import UIKit

final class DavizinBottomNavView: UIView {
    var onModes: (() -> Void)?
    var onPlayer: (() -> Void)?
    var onHelp: (() -> Void)?
    var onExtras: (() -> Void)?

    private let modesButton = UIButton(type: .system)
    private let playerButton = UIButton(type: .system)
    private let helpButton = UIButton(type: .system)
    private let extrasButton = UIButton(type: .system)
    private let modesLabel = UILabel()
    private let playerLabel = UILabel()
    private let helpLabel = UILabel()
    private let extrasLabel = UILabel()
    private let modesIndicator = UIView()
    private let playerIndicator = UIView()
    private let helpIndicator = UIView()
    private let extrasIndicator = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    func setSelected(_ item: Item) {
        let selectedColor = AppTheme.readableAccent
        let normalColor = AppTheme.secondaryText
        modesButton.tintColor = item == .modes ? selectedColor : normalColor
        playerButton.tintColor = item == .player ? selectedColor : normalColor

        helpButton.tintColor = item == .help ? selectedColor : normalColor
        extrasButton.tintColor = item == .extras ? selectedColor : normalColor
        modesLabel.textColor = item == .modes ? selectedColor : normalColor
        playerLabel.textColor = item == .player ? selectedColor : normalColor

        helpLabel.textColor = item == .help ? selectedColor : normalColor
        extrasLabel.textColor = item == .extras ? selectedColor : normalColor
        UIView.animate(withDuration: AppTheme.durationPopover) {
            self.modesIndicator.alpha = item == .modes ? 1.0 : 0.0
            self.playerIndicator.alpha = item == .player ? 1.0 : 0.0

            self.helpIndicator.alpha = item == .help ? 1.0 : 0.0
            self.extrasIndicator.alpha = item == .extras ? 1.0 : 0.0
        }
    }

    enum Item { case modes, player, profile, help, extras }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = AppTheme.backgroundRaise.withAlphaComponent(0.30)
        layer.cornerRadius = 22
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = AppTheme.hairlineStrong.cgColor

        // Desenfoque glass detrás de los iconos
        let navBlur = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
        navBlur.isUserInteractionEnabled = false
        navBlur.layer.cornerRadius = 22
        navBlur.layer.cornerCurve = .continuous
        navBlur.clipsToBounds = true
        navBlur.translatesAutoresizingMaskIntoConstraints = false
        insertSubview(navBlur, at: 0)
        NSLayoutConstraint.activate([
            navBlur.leadingAnchor.constraint(equalTo: leadingAnchor),
            navBlur.trailingAnchor.constraint(equalTo: trailingAnchor),
            navBlur.topAnchor.constraint(equalTo: topAnchor),
            navBlur.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.20
        layer.shadowRadius = 14
        layer.shadowOffset = CGSize(width: 0, height: 6)

        configureButton(modesButton, image: "square.grid.2x2.fill", label: modesLabel, text: "MODOS", accessibility: "Modos", action: #selector(modesTapped))
        configureButton(playerButton, image: "person.crop.square.fill", label: playerLabel, text: "JUGADOR", accessibility: "Jugador", action: #selector(playerTapped))

        configureButton(helpButton, image: "questionmark.circle.fill", label: helpLabel, text: "AYUDA", accessibility: "Centro de ayuda", action: #selector(helpTapped))
        configureButton(extrasButton, image: "star.circle.fill", label: extrasLabel, text: "EXTRAS", accessibility: "Extras", action: #selector(extrasTapped))

        let stack = UIStackView(arrangedSubviews: [
            makeItem(button: modesButton, label: modesLabel, indicator: modesIndicator),
            makeItem(button: playerButton, label: playerLabel, indicator: playerIndicator),
            makeItem(button: helpButton, label: helpLabel, indicator: helpIndicator),
            makeItem(button: extrasButton, label: extrasLabel, indicator: extrasIndicator)
        ])
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let stackTop = stack.topAnchor.constraint(equalTo: topAnchor, constant: isPad ? 8 : 6)
        let stackBottom = stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: isPad ? -8 : -6)
        stackTop.priority = .defaultHigh
        stackBottom.priority = .defaultHigh
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: isPad ? 80 : 8),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: isPad ? -80 : -8),
            stackTop,
            stackBottom
        ])
        setSelected(.modes)
    }

    private func configureButton(_ button: UIButton, image: String, label: UILabel, text: String, accessibility: String, action: Selector) {
        button.setImage(UIImage(systemName: image), for: .normal)
        button.tintColor = AppTheme.secondaryText
        button.accessibilityLabel = accessibility
        button.accessibilityTraits = .button
        button.addTarget(self, action: action, for: .touchUpInside)
        label.text = text
        label.font = .systemFont(ofSize: UIDevice.current.userInterfaceIdiom == .pad ? 11 : 9, weight: .semibold)
        label.textAlignment = .center
        label.textColor = AppTheme.secondaryText
        label.isUserInteractionEnabled = false
        label.adjustsFontForContentSizeCategory = true
        label.minimumScaleFactor = 0.8
    }

    private func makeItem(button: UIButton, label: UILabel, indicator: UIView) -> UIView {
        // indicator = pill de acento relleno detrás del icono+texto cuando está activo
        indicator.backgroundColor = AppTheme.readableAccent.withAlphaComponent(0.15)
        indicator.layer.cornerRadius = 16
        indicator.layer.cornerCurve = .continuous
        indicator.layer.borderWidth = 1
        indicator.layer.borderColor = AppTheme.readableAccent.withAlphaComponent(0.32).cgColor
        indicator.alpha = 0.0
        indicator.isUserInteractionEnabled = false
        indicator.translatesAutoresizingMaskIntoConstraints = false

        let content = UIStackView(arrangedSubviews: [button, label])
        content.axis = .vertical
        content.alignment = .center
        content.spacing = 2
        content.translatesAutoresizingMaskIntoConstraints = false

        let container = UIView()
        container.addSubview(indicator)
        container.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
            content.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -6),
            content.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            content.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 4),
            content.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -4),
            indicator.topAnchor.constraint(equalTo: content.topAnchor, constant: -5),
            indicator.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: 5),
            indicator.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: -16),
            indicator.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: 16)
        ])
        return container
    }

    @objc private func modesTapped() { onModes?() }
    @objc private func playerTapped() { onPlayer?() }
    @objc private func helpTapped() { onHelp?() }
    @objc private func extrasTapped() { onExtras?() }
}
