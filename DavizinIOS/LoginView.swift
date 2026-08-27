import UIKit

protocol LoginViewDelegate: AnyObject {
    func loginView(_ loginView: LoginView, didTapContinueWithKey key: String)
}

final class LoginView: UIView {
    weak var delegate: LoginViewDelegate?

    private let cardView = ARIFICardView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let keyField = UITextField()
    private let continueButton = ARIFIButton(title: "Continue", style: .primary)
    private let statusLabel = UILabel()
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
        continueButton.setLoading(checking, title: "Checking...")
        statusLabel.text = checking ? "Checking your key..." : nil
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

    private func configure() {
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false

        titleLabel.text = "Davizin iOS"
        titleLabel.textColor = AppTheme.primaryText
        titleLabel.font = AppTheme.titleFont()
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontForContentSizeCategory = true

        subtitleLabel.text = "Enter your access key to continue."
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
        keyField.placeholder = "Access key"
        keyField.autocorrectionType = .no
        keyField.autocapitalizationType = .allCharacters
        keyField.returnKeyType = .continue
        keyField.clearButtonMode = .whileEditing
        keyField.delegate = self
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

        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.spacing = 12.0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)
        stackView.addArrangedSubview(keyField)
        stackView.addArrangedSubview(continueButton)
        stackView.addArrangedSubview(statusLabel)

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addContent(stackView)
        addSubview(cardView)

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 22.0),
            cardView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -22.0),
            cardView.centerXAnchor.constraint(equalTo: centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: centerYAnchor),
            cardView.widthAnchor.constraint(lessThanOrEqualToConstant: AppTheme.contentMaximumWidth),
            stackView.widthAnchor.constraint(greaterThanOrEqualToConstant: 220.0),
            continueButton.heightAnchor.constraint(equalToConstant: AppTheme.controlHeight)
        ])
    }

    @objc private func continueTapped() {
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
