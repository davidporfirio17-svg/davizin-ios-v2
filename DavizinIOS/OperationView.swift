import UIKit

protocol OperationViewDelegate: AnyObject {
    func operationView(_ view: OperationView, didTap operation: ARIFIOperationKind)
}

final class OperationView: UIView {
    weak var delegate: OperationViewDelegate?

    private let cardView = ARIFICardView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let runButton = ARIFIButton(title: ARIFIOperationKind.runExploit.rawValue, style: .secondary)
    private let injectButton = ARIFIButton(title: ARIFIOperationKind.inject.rawValue, style: .secondary)
    private let cleanButton = ARIFIButton(title: ARIFIOperationKind.clean.rawValue, style: .secondary)
    private let statusLabel = UILabel()
    private let stackView = UIStackView()

    private(set) var operationState: ARIFIOperationState = .idle

    var selectedGame: ARIFIGame = .freeFireMax { didSet { updateContent() } }
    var selectedMode: ARIFIMode = .drag { didSet { updateContent() } }

    override init(frame: CGRect) { super.init(frame: frame); configure() }
    required init?(coder: NSCoder) { super.init(coder: coder); configure() }

    func setState(_ state: ARIFIOperationState) {
        operationState = state
        statusLabel.textColor = AppTheme.secondaryText
        runButton.setLoading(false)
        injectButton.setLoading(false)
        cleanButton.setLoading(false)

        switch state {
        case .idle:
            statusLabel.text = nil
            statusLabel.isHidden = true
        case .checking:
            statusLabel.text = "Checking..."
            statusLabel.isHidden = false
        case .running:
            runButton.setLoading(true, title: "Running...")
            statusLabel.text = "Running..."
            statusLabel.isHidden = false
        case .injecting:
            injectButton.setLoading(true, title: "Injecting...")
            statusLabel.text = "Injecting..."
            statusLabel.isHidden = false
        case .cleaning:
            cleanButton.setLoading(true, title: "Cleaning...")
            statusLabel.text = "Cleaning..."
            statusLabel.isHidden = false
        case .succeeded(let message):
            statusLabel.text = message
            statusLabel.textColor = AppTheme.success
            statusLabel.isHidden = false
        case .failed(let message):
            statusLabel.text = message
            statusLabel.textColor = AppTheme.failure
            statusLabel.isHidden = false
        }

        let enabled = !state.isBusy
        runButton.isEnabled = enabled
        injectButton.isEnabled = enabled
        cleanButton.isEnabled = enabled
    }

    private func configure() {
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false

        titleLabel.textColor = AppTheme.primaryText
        titleLabel.font = AppTheme.titleFont()
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontForContentSizeCategory = true

        subtitleLabel.textColor = AppTheme.secondaryText
        subtitleLabel.font = AppTheme.bodyFont()
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.isHidden = true

        updateContent()

        runButton.addTarget(self, action: #selector(runTapped), for: .touchUpInside)
        injectButton.addTarget(self, action: #selector(injectTapped), for: .touchUpInside)
        cleanButton.addTarget(self, action: #selector(cleanTapped), for: .touchUpInside)

        statusLabel.textColor = AppTheme.secondaryText
        statusLabel.font = AppTheme.captionFont()
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.isHidden = true

        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.spacing = AppTheme.standardSpacing
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)

        // Spacer
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: 8).isActive = true
        stackView.addArrangedSubview(spacer)

        stackView.addArrangedSubview(runButton)
        stackView.addArrangedSubview(injectButton)
        stackView.addArrangedSubview(cleanButton)
        stackView.addArrangedSubview(statusLabel)

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addContent(stackView)
        addSubview(cardView)

        NSLayoutConstraint.activate([
            // Card llena todo el ancho con margen
            cardView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            cardView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            // Centrado verticalmente pero con límite de ancho máximo
            cardView.centerYAnchor.constraint(equalTo: centerYAnchor),

            runButton.heightAnchor.constraint(equalToConstant: AppTheme.controlHeight),
            injectButton.heightAnchor.constraint(equalToConstant: AppTheme.controlHeight),
            cleanButton.heightAnchor.constraint(equalToConstant: AppTheme.controlHeight),
        ])
    }

    private func updateContent() {
        titleLabel.text = "\(selectedGame.rawValue)"
        subtitleLabel.text = "Mode: \(selectedMode.rawValue)"
    }

    @objc private func runTapped()    { delegate?.operationView(self, didTap: .runExploit) }
    @objc private func injectTapped() { delegate?.operationView(self, didTap: .inject) }
    @objc private func cleanTapped()  { delegate?.operationView(self, didTap: .clean) }
}
