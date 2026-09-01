import UIKit

protocol OperationViewDelegate: AnyObject {
    func operationView(_ view: OperationView, didTap operation: ARIFIOperationKind)
}

final class OperationView: UIView {
    weak var delegate: OperationViewDelegate?

    private let cardView = ARIFICardView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let runButton = ARIFIButton(title: "EJECUTAR PROCESO", style: .primary)
    private let injectButton = ARIFIButton(title: "INYECTAR CONFIGURACIÓN", style: .secondary)
    private let cleanButton = ARIFIButton(title: "LIMPIAR SESIÓN", style: .destructive)
    private let statusLabel = UILabel()
    private let openGameButton = ARIFIButton(title: "🎮 ABRIR JUEGO")
    var onOpenGame: (() -> Void)?
    private let stackView = UIStackView()

    private(set) var operationState: ARIFIOperationState = .idle

    var selectedGame: ARIFIGame = .freeFireMax {
        didSet {
            updateSubtitle()
        }
    }

    var selectedMode: ARIFIMode = .drag {
        didSet {
            updateSubtitle()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    func setState(_ state: ARIFIOperationState) {
        operationState = state
        statusLabel.textColor = AppTheme.secondaryText
        runButton.setLoading(false)
        injectButton.setLoading(false)
        cleanButton.setLoading(false)
        openGameButton.isHidden = true

        switch state {
        case .idle:
            statusLabel.text = nil
            statusLabel.isHidden = true
        case .checking:
            statusLabel.text = "Comprobando entorno..."
            statusLabel.isHidden = false
        case .running:
            runButton.setLoading(true, title: "EJECUTANDO...")
            statusLabel.text = "Ejecutando proceso..."
            statusLabel.isHidden = false
        case .injecting:
            injectButton.setLoading(true, title: "INYECTANDO...")
            statusLabel.text = "Aplicando configuración..."
            statusLabel.isHidden = false
        case .cleaning:
            cleanButton.setLoading(true, title: "LIMPIANDO...")
            statusLabel.text = "Limpiando sesión..."
            statusLabel.isHidden = false
        case .succeeded(let message):
            statusLabel.text = message
            statusLabel.textColor = AppTheme.success
            statusLabel.isHidden = false
            // Si fue una inyeccion exitosa, mostrar el boton de abrir el juego
            if message.lowercased().contains("inyectado") {
                openGameButton.isHidden = false
            }
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

        titleLabel.text = ""
        titleLabel.textColor = AppTheme.primaryText
        titleLabel.font = AppTheme.titleFont()
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontForContentSizeCategory = true

        subtitleLabel.textColor = AppTheme.secondaryText
        subtitleLabel.font = AppTheme.bodyFont()
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.isHidden = true
        updateSubtitle()

        runButton.accessibilityIdentifier = "operation.runExploit"
        injectButton.accessibilityIdentifier = "operation.inject"
        cleanButton.accessibilityIdentifier = "operation.clean"
        runButton.addTarget(self, action: #selector(runTapped), for: .touchUpInside)
        injectButton.addTarget(self, action: #selector(injectTapped), for: .touchUpInside)
        cleanButton.addTarget(self, action: #selector(cleanTapped), for: .touchUpInside)
        openGameButton.accessibilityIdentifier = "operation.opengame"
        openGameButton.addTarget(self, action: #selector(openGameTapped), for: .touchUpInside)
        openGameButton.isHidden = true

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
        stackView.addArrangedSubview(runButton)
        stackView.addArrangedSubview(injectButton)
        stackView.addArrangedSubview(cleanButton)
        stackView.addArrangedSubview(statusLabel)
        stackView.addArrangedSubview(openGameButton)

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addContent(stackView)
        addSubview(cardView)

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 22.0),
            cardView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -22.0),
            cardView.centerXAnchor.constraint(equalTo: centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: centerYAnchor),
            cardView.widthAnchor.constraint(lessThanOrEqualToConstant: AppTheme.contentMaximumWidth),
            stackView.widthAnchor.constraint(greaterThanOrEqualToConstant: 240.0),
            runButton.heightAnchor.constraint(equalToConstant: AppTheme.controlHeight),
            injectButton.heightAnchor.constraint(equalToConstant: AppTheme.controlHeight),
            cleanButton.heightAnchor.constraint(equalToConstant: AppTheme.controlHeight),
            openGameButton.heightAnchor.constraint(equalToConstant: AppTheme.controlHeight)
        ])
    }

    private func updateSubtitle() {
        titleLabel.text = "\(selectedGame.rawValue) / \(selectedMode.displayName)"
        subtitleLabel.text = nil
    }

    @objc private func runTapped() {
        delegate?.operationView(self, didTap: .runExploit)
    }

    @objc private func injectTapped() {
        delegate?.operationView(self, didTap: .inject)
    }

    @objc private func cleanTapped() {
        delegate?.operationView(self, didTap: .clean)
    }

    @objc private func openGameTapped() {
        onOpenGame?()
    }
}
