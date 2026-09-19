import UIKit

final class ARIFIBottomNavView: UIView {
    var onModes: (() -> Void)?
    var onProfile: (() -> Void)?

    private let modesButton = UIButton(type: .system)
    private let profileButton = UIButton(type: .system)
    private let modesLabel = UILabel()
    private let profileLabel = UILabel()

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
    }

    enum Item { case modes, profile }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = AppTheme.card
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor

        configureButton(modesButton, image: "square.grid.2x2.fill", label: modesLabel, text: "MODOS", action: #selector(modesTapped))
        configureButton(profileButton, image: "person.crop.circle.fill", label: profileLabel, text: "PERFIL", action: #selector(profileTapped))

        let stack = UIStackView(arrangedSubviews: [makeItem(button: modesButton, label: modesLabel), makeItem(button: profileButton, label: profileLabel)])
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 68),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6)
        ])
        setSelected(.modes)
    }

    private func configureButton(_ button: UIButton, image: String, label: UILabel, text: String, action: Selector) {
        button.setImage(UIImage(systemName: image), for: .normal)
        button.tintColor = AppTheme.secondaryText
        button.accessibilityLabel = text.capitalized
        button.addTarget(self, action: action, for: .touchUpInside)
        label.text = text
        label.font = .systemFont(ofSize: 10, weight: .heavy)
        label.textAlignment = .center
        label.textColor = AppTheme.secondaryText
        label.isUserInteractionEnabled = false
    }

    private func makeItem(button: UIButton, label: UILabel) -> UIView {
        let stack = UIStackView(arrangedSubviews: [button, label])
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
