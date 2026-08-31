import UIKit

protocol ARIFIHeaderViewDelegate: AnyObject {
    func headerViewDidTapBack(_ headerView: ARIFIHeaderView)
    func headerViewDidTapClose(_ headerView: ARIFIHeaderView)
}

final class ARIFIHeaderView: UIView {
    weak var delegate: ARIFIHeaderViewDelegate?

    var title: String = "" {
        didSet { titleLabel.text = title.uppercased() }
    }

    var countdownText: String = "" {
        didSet {
            countdownLabel.text = countdownText
            countdownLabel.isHidden = countdownText.isEmpty
        }
    }

    var showsBackButton: Bool = true {
        didSet { backButton.isHidden = !showsBackButton }
    }

    private let titleLabel = UILabel()
    private let countdownLabel = UILabel()
    private let backButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    private let statusDot = UIView()

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
        backgroundColor = AppTheme.card
        layer.cornerRadius = 18.0
        layer.cornerCurve = .continuous
        layer.borderWidth = 1.0
        layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor

        statusDot.translatesAutoresizingMaskIntoConstraints = false
        statusDot.backgroundColor = AppTheme.accent
        statusDot.layer.cornerRadius = 4.0
        statusDot.layer.shadowColor = AppTheme.accent.cgColor
        statusDot.layer.shadowOpacity = 0.8
        statusDot.layer.shadowRadius = 7.0
        addSubview(statusDot)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.textColor = AppTheme.primaryText
        titleLabel.font = UIFont.systemFont(ofSize: 13.0, weight: .heavy)
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.setContentHuggingPriority(.required, for: .vertical)
        addSubview(titleLabel)

        configureIconButton(backButton, imageName: "chevron.left")
        configureIconButton(closeButton, imageName: "xmark")
        addSubview(backButton)
        addSubview(closeButton)

        countdownLabel.translatesAutoresizingMaskIntoConstraints = false
        countdownLabel.textColor = AppTheme.accent
        countdownLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 10.0, weight: .bold)
        countdownLabel.textAlignment = .center
        countdownLabel.isHidden = true
        addSubview(countdownLabel)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 60.0),
            statusDot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18.0),
            statusDot.centerYAnchor.constraint(equalTo: centerYAnchor),
            statusDot.widthAnchor.constraint(equalToConstant: 8.0),
            statusDot.heightAnchor.constraint(equalToConstant: 8.0),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 14.0),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: backButton.trailingAnchor, constant: 12.0),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -12.0),
            countdownLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            countdownLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3.0),
            backButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8.0),
            backButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 38.0),
            backButton.heightAnchor.constraint(equalToConstant: 38.0),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8.0),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 38.0),
            closeButton.heightAnchor.constraint(equalToConstant: 38.0)
        ])

        titleLabel.text = title.uppercased()
        showsBackButton = true
    }

    private func configureIconButton(_ button: UIButton, imageName: String) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: imageName), for: .normal)
        button.tintColor = AppTheme.secondaryText
        button.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        button.layer.cornerRadius = 12.0
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
