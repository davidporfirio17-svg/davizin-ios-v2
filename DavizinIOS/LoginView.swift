import UIKit
import Security

private enum NyxelKeychain {
    private static let service = "com.nyxel.session"
    private static let account = "login-key"

    static var key: String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func save(_ value: String) {
        let data = Data(value.uppercased().utf8)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
        let attributes: [String: Any] = [kSecValueData as String: data, kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        if SecItemUpdate(query as CFDictionary, attributes as CFDictionary) != errSecSuccess {
            var item = query; attributes.forEach { item[$0.key] = $0.value }
            SecItemAdd(item as CFDictionary, nil)
        }
    }

    static func remove() {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
        SecItemDelete(query as CFDictionary)
    }
}

protocol LoginViewDelegate: AnyObject {
    func loginView(_ loginView: LoginView, didTapContinueWithKey key: String)
}

final class LoginView: UIView {
    weak var delegate: LoginViewDelegate?

    private let videoBackground = DavizinLoginVideoView()
    private let videoOverlay = UIView()
    private let cardView = DavizinCardView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let keyField = UITextField()
    private let continueButton = DavizinButton(title: "ENTRAR AL PANEL", style: .primary)
    private let statusLabel = UILabel()
    private let compatLabel = UILabel()
    private let stackView = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    func setChecking(_ checking: Bool) {
        keyField.isEnabled = !checking
        continueButton.setLoading(checking, title: "VERIFICANDO...")
        statusLabel.text = checking ? "Validando credenciales..." : nil
        statusLabel.isHidden = !checking
    }

    func setStatus(_ text: String?, success: Bool = false) {
        statusLabel.text = text
        statusLabel.textColor = success ? AppTheme.success : AppTheme.secondaryText
        statusLabel.isHidden = text == nil
    }

    func reset() {
        setChecking(false)
        setStatus(nil)
    }

    /// Muestra el estado de compatibilidad del dispositivo (verde/rojo/amarillo).
    func setCompatibility(_ text: String, color: UIColor) {
        compatLabel.text = text
        compatLabel.textColor = color
        compatLabel.isHidden = text.isEmpty
    }

    private func configure() {
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false

        videoBackground.translatesAutoresizingMaskIntoConstraints = false
        videoOverlay.translatesAutoresizingMaskIntoConstraints = false
        videoOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.48)
        addSubview(videoBackground)
        addSubview(videoOverlay)
        sendSubviewToBack(videoBackground)

		titleLabel.text = "NYXEL"
        titleLabel.textColor = AppTheme.primaryText
        titleLabel.font = AppTheme.titleFont()
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontForContentSizeCategory = true

        subtitleLabel.text = "Activa tu sesión para desbloquear el panel de operaciones."
        subtitleLabel.textColor = AppTheme.secondaryText
        subtitleLabel.font = AppTheme.bodyFont()
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.adjustsFontForContentSizeCategory = true

        keyField.translatesAutoresizingMaskIntoConstraints = false
        keyField.backgroundColor = AppTheme.background
        keyField.textColor = AppTheme.primaryText
        keyField.tintColor = AppTheme.primaryText
        keyField.font = AppTheme.bodyFont()
        keyField.layer.cornerRadius = AppTheme.controlCornerRadius
        keyField.layer.cornerCurve = .continuous
        keyField.layer.borderWidth = 1.0
        keyField.layer.borderColor = AppTheme.separator.cgColor
        keyField.placeholder = "PEGA TU KEY DE ACCESO"
        keyField.autocorrectionType = .no
        keyField.autocapitalizationType = .allCharacters
        keyField.returnKeyType = .continue
        keyField.clearButtonMode = .whileEditing
        keyField.delegate = self
        keyField.addTarget(self, action: #selector(keyFieldChanged), for: .editingChanged)
		keyField.text = NyxelKeychain.key
        keyField.setLeftPadding(14.0)
        keyField.setRightPadding(14.0)
        keyField.heightAnchor.constraint(equalToConstant: AppTheme.controlHeight).isActive = true

        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
        continueButton.accessibilityIdentifier = "login.continue"

        statusLabel.textColor = AppTheme.secondaryText
        statusLabel.font = AppTheme.captionFont()
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.isHidden = true

        compatLabel.font = UIFont.systemFont(ofSize: 13.0, weight: .bold)
        compatLabel.textAlignment = .center
        compatLabel.numberOfLines = 0
        compatLabel.isHidden = true

        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.spacing = 12.0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)
        stackView.addArrangedSubview(compatLabel)
        stackView.addArrangedSubview(keyField)
        stackView.addArrangedSubview(continueButton)
        stackView.addArrangedSubview(statusLabel)

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addContent(stackView)
        addSubview(cardView)

        NSLayoutConstraint.activate([
            videoBackground.leadingAnchor.constraint(equalTo: leadingAnchor),
            videoBackground.trailingAnchor.constraint(equalTo: trailingAnchor),
            videoBackground.topAnchor.constraint(equalTo: topAnchor),
            videoBackground.bottomAnchor.constraint(equalTo: bottomAnchor),
            videoOverlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            videoOverlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            videoOverlay.topAnchor.constraint(equalTo: topAnchor),
            videoOverlay.bottomAnchor.constraint(equalTo: bottomAnchor),
            cardView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 22.0),
            cardView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -22.0),
            cardView.centerXAnchor.constraint(equalTo: centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: centerYAnchor),
            cardView.widthAnchor.constraint(lessThanOrEqualToConstant: AppTheme.contentMaximumWidth),
            stackView.widthAnchor.constraint(greaterThanOrEqualToConstant: 220.0),
            continueButton.heightAnchor.constraint(equalToConstant: AppTheme.controlHeight)
        ])
    }

	@objc private func keyFieldChanged() {
		let value = (keyField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
		keyField.text = value
		if value.isEmpty { NyxelKeychain.remove() } else { NyxelKeychain.save(value) }
    }

    @objc private func continueTapped() {
        keyFieldChanged()
        delegate?.loginView(self, didTapContinueWithKey: keyField.text ?? "")
    }
}

extension LoginView: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        continueTapped()
        return true
    }
}

private extension UITextField {
    func setLeftPadding(_ padding: CGFloat) {
        let container = UIView(frame: CGRect(x: 0.0, y: 0.0, width: padding, height: 1.0))
        leftView = container
        leftViewMode = .always
    }

    func setRightPadding(_ padding: CGFloat) {
        let container = UIView(frame: CGRect(x: 0.0, y: 0.0, width: padding, height: 1.0))
        rightView = container
        rightViewMode = .always
    }
}
