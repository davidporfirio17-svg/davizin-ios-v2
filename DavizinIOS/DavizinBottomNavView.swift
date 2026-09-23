import UIKit

final class DavizinBottomNavView: UIView {
    var onModes: (() -> Void)?
    var onProfile: (() -> Void)?

    private let modesButton = UIButton(type: .system)
    private let profileButton = UIButton(type: .system)
    private let modesLabel = UILabel()
    private let profileLabel = UILabel()
    private let modesIndicator = UIView()
    private let profileIndicator = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    func setSelected(_ item: Item) {
        let selectedColor = AppTheme.accent
        let normalColor = AppTheme.secondaryText
        modesButton.tintColor = item == .modes ? selectedColor : normalColor
        profileButton.tintColor = item == .profile ? selectedColor : normalColor
        modesLabel.textColor = item == .modes ? selectedColor : normalColor
        profileLabel.textColor = item == .profile ? selectedColor : normalColor
        UIView.animate(withDuration: AppTheme.durationPopover) {
            self.modesIndicator.alpha = item == .modes ? 1.0 : 0.0
            self.profileIndicator.alpha = item == .profile ? 1.0 : 0.0
        }
    }

    enum Item { case modes, profile }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = AppTheme.card.withAlphaComponent(0.88)
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor

        configureButton(modesButton, image: "square.grid.2x2.fill", label: modesLabel, text: "MODOS", action: #selector(modesTapped))
        configureButton(profileButton, image: "person.crop.circle.fill", label: profileLabel, text: "PERFIL", action: #selector(profileTapped))

        let stack = UIStackView(arrangedSubviews: [makeItem(button: modesButton, label: modesLabel, indicator: modesIndicator), makeItem(button: profileButton, label: profileLabel, indicator: profileIndicator)])
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
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: isPad ? 120 : 28),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: isPad ? -120 : -28),
            stackTop,
            stackBottom
        ])
        setSelected(.modes)
    }

    private func configureButton(_ button: UIButton, image: String, label: UILabel, text: String, action: Selector) {
        button.setImage(UIImage(systemName: image), for: .normal)
        button.tintColor = AppTheme.secondaryText
        button.accessibilityLabel = text.capitalized
        button.addTarget(self, action: action, for: .touchUpInside)
        label.text = text
        label.font = .systemFont(ofSize: UIDevice.current.userInterfaceIdiom == .pad ? 11 : 10, weight: .heavy)
        label.textAlignment = .center
        label.textColor = AppTheme.secondaryText
        label.isUserInteractionEnabled = false
    }

    private func makeItem(button: UIButton, label: UILabel, indicator: UIView) -> UIView {
        indicator.backgroundColor = AppTheme.accent
        indicator.layer.cornerRadius = 1.5
        indicator.alpha = 0.0
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.widthAnchor.constraint(equalToConstant: 30).isActive = true
        indicator.heightAnchor.constraint(equalToConstant: 3).isActive = true
        let stack = UIStackView(arrangedSubviews: [button, label, indicator])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 2
        return stack
    }

    @objc private func modesTapped() {
        onModes?()
    }

    @objc private func profileTapped() {
        onProfile?()
    }
}
