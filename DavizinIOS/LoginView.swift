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
    private let videoGradient = CAGradientLayer()
    private let cardView = DavizinCardView()
    private let logoMark = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let keyField = UITextField()
    private let keyVisibilityButton = UIButton(type: .system)
    private let continueButton = DavizinButton(title: "ENTRAR AL PANEL", style: .primary)
    private let statusLabel = UILabel()
    private let compatLabel = UILabel()
    private let stackView = UIStackView()
    private var hasPlayedEntrance = false
    private var keyboardObserverTokens: [NSObjectProtocol] = []
    private var showingValidationError = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    deinit {
        keyboardObserverTokens.forEach { NotificationCenter.default.removeObserver($0) }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        videoGradient.frame = videoOverlay.bounds
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil, !hasPlayedEntrance else { return }
        hasPlayedEntrance = true

        videoBackground.alpha = 0.0
        cardView.alpha = 0.0
        cardView.transform = CGAffineTransform(translationX: 0.0, y: 16.0)

        UIView.animate(withDuration: 0.70, delay: 0.04, options: [.curveEaseOut, .beginFromCurrentState]) {
            self.videoBackground.alpha = 1.0
        }

        UIView.animate(
            withDuration: 1.35,
            delay: 0.72,
            options: [.autoreverse, .repeat, .allowUserInteraction, .beginFromCurrentState]
        ) {
            self.logoMark.alpha = 0.72
            self.logoMark.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
        }

        UIView.animate(
            withDuration: 0.62,
            delay: 0.18,
            usingSpringWithDamping: 0.86,
            initialSpringVelocity: 0.25,
            options: [.curveEaseOut, .beginFromCurrentState]
        ) {
            self.cardView.alpha = 1.0
            self.cardView.transform = .identity
        }
    }

    private func observeKeyboard() {
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            UIResponder.keyboardWillChangeFrameNotification,
            UIResponder.keyboardWillHideNotification
        ]
        keyboardObserverTokens = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                self?.adjustForKeyboard(notification)
            }
        }
    }

    private func adjustForKeyboard(_ notification: Notification) {
        guard window != nil else { return }
        let keyboardFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)
            .map { convert($0.cgRectValue, from: nil) } ?? .zero
        let isHidden = notification.name == UIResponder.keyboardWillHideNotification || keyboardFrame.minY >= bounds.maxY
        let bottomPadding: CGFloat = 18.0
        let overlap = isHidden ? 0.0 : max(0.0, cardView.frame.maxY - (keyboardFrame.minY - bottomPadding))
        let duration = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0.25
        let curveRaw = (notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?.uintValue ?? 7
        let options = UIView.AnimationOptions(rawValue: curveRaw << 16).union([.beginFromCurrentState, .allowUserInteraction])

        UIView.animate(withDuration: duration, delay: 0.0, options: options) {
            self.cardView.transform = CGAffineTransform(translationX: 0.0, y: -overlap)
        }
    }

    func setChecking(_ checking: Bool) {
        keyField.isEnabled = !checking
        keyVisibilityButton.isEnabled = !checking
        continueButton.setLoading(checking, title: "VERIFICANDO...")
        if checking {
            clearValidationFeedback()
        }
        statusLabel.text = checking ? "Validando credenciales..." : nil
        statusLabel.textColor = AppTheme.secondaryText
        statusLabel.isHidden = !checking
    }

    func setStatus(_ text: String?, success: Bool = false) {
        guard let text = text, !text.isEmpty else {
            clearValidationFeedback()
            statusLabel.text = nil
            statusLabel.isHidden = true
            return
        }

        if success {
            clearValidationFeedback()
            statusLabel.text = text
            statusLabel.textColor = AppTheme.success
        } else {
            // Mantener una respuesta uniforme: no revelar si la key existe,
            // expiró, fue revocada o si el servidor rechazó el dispositivo.
            statusLabel.text = "No se pudo validar la sesión."
            statusLabel.textColor = AppTheme.failure
            showValidationError()
        }
        statusLabel.isHidden = false
    }

    func reset() {
        setChecking(false)
        setStatus(nil)
    }

    private func showValidationError() {
        showingValidationError = true
        keyField.layer.removeAnimation(forKey: "nyxel.key.borderPulse")
        keyField.layer.borderColor = AppTheme.failure.cgColor
        keyField.layer.shadowColor = AppTheme.failure.cgColor
        keyField.layer.shadowOpacity = 0.24
        guard !UIAccessibility.isReduceMotionEnabled else { return }

        let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
        shake.values = [0.0, -7.0, 7.0, -4.0, 4.0, 0.0]
        shake.keyTimes = [0.0, 0.18, 0.38, 0.58, 0.78, 1.0]
        shake.duration = 0.34
        shake.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        cardView.layer.add(shake, forKey: "nyxel.validation.shake")
    }

    private func clearValidationFeedback() {
        guard showingValidationError else { return }
        showingValidationError = false
        cardView.layer.removeAnimation(forKey: "nyxel.validation.shake")
        keyField.layer.shadowColor = AppTheme.accent.cgColor
        keyField.layer.shadowOpacity = 0.0
        keyField.layer.borderColor = UIColor.white.withAlphaComponent(0.22).cgColor
    }

    /// Muestra el estado de compatibilidad del dispositivo (verde/rojo/amarillo).
    func setCompatibility(_ text: String, color: UIColor) {
        compatLabel.text = text
        compatLabel.textColor = color
        compatLabel.isHidden = text.isEmpty
    }

    func playExitAnimation(completion: @escaping () -> Void) {
        keyField.resignFirstResponder()
        UIView.animate(
            withDuration: 0.30,
            delay: 0.0,
            options: [.curveEaseIn, .beginFromCurrentState]
        ) {
            self.cardView.alpha = 0.0
            self.cardView.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
            self.videoBackground.alpha = 0.0
            self.videoBackground.transform = CGAffineTransform(scaleX: 1.06, y: 1.06)
        } completion: { _ in
            completion()
        }
    }

    private func configure() {
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false

        videoBackground.translatesAutoresizingMaskIntoConstraints = false
        videoBackground.isUserInteractionEnabled = false
        videoOverlay.translatesAutoresizingMaskIntoConstraints = false
        videoOverlay.isUserInteractionEnabled = false
        videoOverlay.backgroundColor = .clear
        videoGradient.colors = [
            UIColor.black.withAlphaComponent(0.12).cgColor,
            UIColor.black.withAlphaComponent(0.24).cgColor,
            UIColor.black.withAlphaComponent(0.72).cgColor
        ]
        videoGradient.locations = [0.0, 0.48, 1.0]
        videoGradient.startPoint = CGPoint(x: 0.5, y: 0.0)
        videoGradient.endPoint = CGPoint(x: 0.5, y: 1.0)
        videoOverlay.layer.addSublayer(videoGradient)
        addSubview(videoBackground)
        addSubview(videoOverlay)
        sendSubviewToBack(videoBackground)

		logoMark.image = UIImage(systemName: "bolt.shield.fill")
		logoMark.tintColor = AppTheme.accent
		logoMark.contentMode = .scaleAspectFit
		logoMark.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 24.0, weight: .bold)
		logoMark.heightAnchor.constraint(equalToConstant: 30.0).isActive = true

		titleLabel.text = "NYXEL EXTERNAL"
        titleLabel.textColor = AppTheme.primaryText
        titleLabel.font = AppTheme.titleFont()
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontForContentSizeCategory = true

        subtitleLabel.text = "Activa tu sesión para continuar."
        subtitleLabel.textColor = AppTheme.secondaryText
        subtitleLabel.font = AppTheme.bodyFont()
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.adjustsFontForContentSizeCategory = true

        keyField.translatesAutoresizingMaskIntoConstraints = false
        keyField.backgroundColor = UIColor.black.withAlphaComponent(0.28)
        keyField.textColor = AppTheme.primaryText
        keyField.tintColor = AppTheme.primaryText
        keyField.font = AppTheme.bodyFont()
        keyField.layer.cornerRadius = AppTheme.controlCornerRadius
        keyField.layer.cornerCurve = .continuous
        keyField.layer.borderWidth = 1.0
        keyField.layer.borderColor = UIColor.white.withAlphaComponent(0.22).cgColor
        keyField.layer.shadowColor = AppTheme.accent.cgColor
        keyField.layer.shadowOffset = .zero
        keyField.layer.shadowRadius = 12.0
        keyField.layer.shadowOpacity = 0.0
        keyField.attributedPlaceholder = NSAttributedString(
            string: "PEGA TU KEY DE ACCESO",
            attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.42)]
        )
        keyField.isSecureTextEntry = true
        keyField.autocorrectionType = .no
        keyField.autocapitalizationType = .allCharacters
        keyField.returnKeyType = .continue
        keyField.clearButtonMode = .whileEditing
        keyField.delegate = self
        keyField.addTarget(self, action: #selector(keyFieldChanged), for: .editingChanged)
		keyField.text = NyxelKeychain.key
        keyField.setLeftPadding(14.0)
        keyVisibilityButton.setImage(UIImage(systemName: "eye.slash.fill"), for: .normal)
        keyVisibilityButton.tintColor = UIColor.white.withAlphaComponent(0.58)
        keyVisibilityButton.frame = CGRect(x: 0.0, y: 0.0, width: 42.0, height: AppTheme.controlHeight)
        keyVisibilityButton.accessibilityLabel = "Mostrar key"
        keyVisibilityButton.addTarget(self, action: #selector(toggleKeyVisibility), for: .touchUpInside)
        keyField.rightView = keyVisibilityButton
        keyField.rightViewMode = .always
        keyField.heightAnchor.constraint(equalToConstant: AppTheme.controlHeight).isActive = true

        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
        continueButton.useLoginEmphasis()
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
        stackView.addArrangedSubview(logoMark)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)
        stackView.addArrangedSubview(compatLabel)
        stackView.addArrangedSubview(keyField)
        stackView.addArrangedSubview(continueButton)
        stackView.addArrangedSubview(statusLabel)

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.useTransparentAppearance()
        cardView.addContent(stackView)
        addSubview(cardView)

        let dismissKeyboardTap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        dismissKeyboardTap.cancelsTouchesInView = false
        addGestureRecognizer(dismissKeyboardTap)
        observeKeyboard()

        NSLayoutConstraint.activate([
            videoBackground.leadingAnchor.constraint(equalTo: leadingAnchor),
            videoBackground.trailingAnchor.constraint(equalTo: trailingAnchor),
            videoBackground.topAnchor.constraint(equalTo: topAnchor, constant: -90.0),
            videoBackground.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -90.0),
            videoOverlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            videoOverlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            videoOverlay.topAnchor.constraint(equalTo: topAnchor),
            videoOverlay.bottomAnchor.constraint(equalTo: bottomAnchor),
            cardView.leadingAnchor.constraint(greaterThanOrEqualTo: safeAreaLayoutGuide.leadingAnchor, constant: 22.0),
            cardView.trailingAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.trailingAnchor, constant: -22.0),
            cardView.centerXAnchor.constraint(equalTo: safeAreaLayoutGuide.centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: safeAreaLayoutGuide.centerYAnchor),
            cardView.widthAnchor.constraint(lessThanOrEqualToConstant: AppTheme.contentMaximumWidth),
            stackView.widthAnchor.constraint(greaterThanOrEqualToConstant: 220.0),
            continueButton.heightAnchor.constraint(equalToConstant: AppTheme.controlHeight)
        ])

        let topSafeArea = cardView.topAnchor.constraint(greaterThanOrEqualTo: safeAreaLayoutGuide.topAnchor, constant: 16.0)
        let bottomSafeArea = cardView.bottomAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.bottomAnchor, constant: -16.0)
        topSafeArea.priority = .defaultHigh
        bottomSafeArea.priority = .defaultHigh
        NSLayoutConstraint.activate([
            topSafeArea,
            bottomSafeArea
        ])
    }

	@objc private func keyFieldChanged() {
			if showingValidationError { clearValidationFeedback() }
				let value = (keyField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
			keyField.text = value
			if value.isEmpty { NyxelKeychain.remove() } else { NyxelKeychain.save(value) }
	}

    @objc private func toggleKeyVisibility() {
        let wasFirstResponder = keyField.isFirstResponder
        let selectedRange = keyField.selectedTextRange
        keyField.isSecureTextEntry.toggle()
        let visible = !keyField.isSecureTextEntry
        keyVisibilityButton.setImage(UIImage(systemName: visible ? "eye.fill" : "eye.slash.fill"), for: .normal)
        keyVisibilityButton.accessibilityLabel = visible ? "Ocultar key" : "Mostrar key"
        if wasFirstResponder {
            keyField.becomeFirstResponder()
            keyField.selectedTextRange = selectedRange
        }
    }

    @objc private func dismissKeyboard() {
        endEditing(true)
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        guard textField === keyField else { return }
        let borderPulse = CABasicAnimation(keyPath: "borderColor")
        borderPulse.fromValue = UIColor.white.withAlphaComponent(0.22).cgColor
        borderPulse.toValue = AppTheme.accent.cgColor
        borderPulse.duration = 0.85
        borderPulse.autoreverses = true
        borderPulse.repeatCount = .greatestFiniteMagnitude
        keyField.layer.add(borderPulse, forKey: "nyxel.key.borderPulse")
        UIView.animate(withDuration: 0.18) {
            self.keyField.backgroundColor = UIColor.black.withAlphaComponent(0.18)
            self.keyField.layer.borderColor = AppTheme.accent.cgColor
            self.keyField.layer.shadowOpacity = 0.28
        }
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        guard textField === keyField else { return }
        keyField.layer.removeAnimation(forKey: "nyxel.key.borderPulse")
        UIView.animate(withDuration: 0.18) {
            self.keyField.backgroundColor = UIColor.black.withAlphaComponent(0.28)
            self.keyField.layer.borderColor = UIColor.white.withAlphaComponent(0.22).cgColor
            self.keyField.layer.shadowOpacity = 0.0
        }
    }

    @objc private func continueTapped() {
        guard continueButton.isEnabled else { return }
        keyFieldChanged()
        keyField.resignFirstResponder()
        continueButton.isEnabled = false
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
