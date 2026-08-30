import UIKit

protocol ARIFIHeaderViewDelegate: AnyObject {
    func headerViewDidTapBack(_ headerView: ARIFIHeaderView)
    func headerViewDidTapClose(_ headerView: ARIFIHeaderView)
}

final class ARIFIHeaderView: UIView {
    weak var delegate: ARIFIHeaderViewDelegate?

    var title: String = "" {
        didSet {
            titleLabel.text = title
        }
    }

    /// Texto del contador. Vacio = oculto.
    var countdownText: String = "" {
        didSet {
            countdownLabel.text = countdownText
            countdownLabel.isHidden = countdownText.isEmpty
        }
    }

    var showsBackButton: Bool = true {
        didSet {
            backButton.isHidden = !showsBackButton
        }
    }

    private let titleLabel = UILabel()
    private let countdownLabel = UILabel()
    private let backButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.textColor = AppTheme.primaryText
        titleLabel.font = UIFont.systemFont(ofSize: 17.0, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontForContentSizeCategory = true
        addSubview(titleLabel)

        configureIconButton(backButton, imageName: "arrow.clockwise")
        configureIconButton(closeButton, imageName: "xmark")
        addSubview(backButton)
        addSubview(closeButton)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 44.0),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: backButton.trailingAnchor, constant: 12.0),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -12.0),
            backButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8.0),
            backButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 36.0),
            backButton.heightAnchor.constraint(equalToConstant: 36.0),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8.0),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 36.0),
            closeButton.heightAnchor.constraint(equalToConstant: 36.0)
        ])

        countdownLabel.translatesAutoresizingMaskIntoConstraints = false
        countdownLabel.textColor = AppTheme.secondaryText
        countdownLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 11.0, weight: .semibold)
        countdownLabel.textAlignment = .center
        countdownLabel.isHidden = true
        addSubview(countdownLabel)
        NSLayoutConstraint.activate([
            countdownLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            countdownLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 1.0)
        ])

        titleLabel.text = title
        showsBackButton = true
    }

    private func configureIconButton(_ button: UIButton, imageName: String) {
        button.translatesAutoresizingMaskIntoConstraints = false
        let image = UIImage(systemName: imageName)
        button.setImage(image, for: .normal)
        button.tintColor = AppTheme.secondaryText
        button.accessibilityTraits = .button
        button.addTarget(self, action: #selector(iconButtonTapped(_:)), for: .touchUpInside)
    }

    @objc private func iconButtonTapped(_ sender: UIButton) {
        if sender === backButton {
            delegate?.headerViewDidTapBack(self)
        } else if sender === closeButton {
            delegate?.headerViewDidTapClose(self)
        }
    }
}
