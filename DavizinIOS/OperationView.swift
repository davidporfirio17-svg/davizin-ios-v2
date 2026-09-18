import UIKit

protocol OperationViewDelegate: AnyObject {
    func operationView(_ view: OperationView, didTap operation: ARIFIOperationKind)
}

final class OperationView: UIView {
    weak var delegate: OperationViewDelegate?

    private let cardView = ARIFICardView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let noticeCard = UIView()
    private let noticeTitleLabel = UILabel()
    private let noticeBodyLabel = UILabel()
    private let noticeStack = UIStackView()

    // Estado 1 (antes de inyectar): solo estos dos son visibles.
    private let runButton = ARIFIButton(title: "EJECUTAR PROCESO", style: .secondary)
    private let injectButton = ARIFIButton(title: "MANTÉN PARA INYECTAR", style: .primary)

    // Estado 2 (despues de inyectar con exito): solo estos dos son visibles.
    private let cleanButton = ARIFIButton(title: "LIMPIAR SESIÓN", style: .destructive)
    private let openGameButton = ARIFIButton(title: "ABRIR JUEGO")
    var onOpenGame: (() -> Void)?

    private let statusLabel = UILabel()
    private let stackView = UIStackView()

    // Hold-to-confirm: anillo de progreso sobre injectButton
    private let holdRingLayer = CAShapeLayer()
    private var holdTimer: Timer?
    private var holdProgress: CGFloat = 0
    private let holdDuration: TimeInterval = 0.65

    private(set) var operationState: ARIFIOperationState = .idle

    var selectedGame: ARIFIGame = .freeFireMax {
        didSet { updateSubtitle() }
    }

    var selectedMode: ARIFIMode = .drag {
        didSet {
            updateSubtitle()
            updateNotice()
            showPreInjectButtons(animated: false)
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
        cleanButton.setLoading(false)

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
            if message.lowercased().contains("inyectado") {
                HapticsService.success()
                SoundService.shared.playChime()
                showPostInjectButtons(animated: true)
            } else {
                // Exito de "Ejecutar" o "Limpiar" -> se queda/regresa al estado pre-inyeccion.
                showPreInjectButtons(animated: true)
            }
        case .failed(let message):
            statusLabel.text = message
            statusLabel.textColor = AppTheme.failure
            statusLabel.isHidden = false
            HapticsService.warning()
        }

        let enabled = !state.isBusy
        runButton.isEnabled = enabled
        injectButton.isEnabled = enabled
        cleanButton.isEnabled = enabled
        openGameButton.isEnabled = enabled
    }

    private func configure() {
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false

        titleLabel.text = ""
        titleLabel.textColor = AppTheme.primaryText
        titleLabel.font = AppTheme.titleFont(22)
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontForContentSizeCategory = true

        subtitleLabel.textColor = AppTheme.secondaryText
        subtitleLabel.font = AppTheme.bodyFont()
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.isHidden = true
        updateSubtitle()

        noticeTitleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        noticeTitleLabel.numberOfLines = 0
        noticeBodyLabel.font = AppTheme.captionFont()
        noticeBodyLabel.numberOfLines = 0
        noticeStack.axis = .vertical
        noticeStack.spacing = 4.0
        noticeStack.translatesAutoresizingMaskIntoConstraints = false
        noticeStack.addArrangedSubview(noticeTitleLabel)
        noticeStack.addArrangedSubview(noticeBodyLabel)
        noticeCard.layer.cornerRadius = 10.0
        noticeCard.layer.borderWidth = 1.0
        noticeCard.addSubview(noticeStack)
        NSLayoutConstraint.activate([
            noticeStack.leadingAnchor.constraint(equalTo: noticeCard.leadingAnchor, constant: 12.0),
            noticeStack.trailingAnchor.constraint(equalTo: noticeCard.trailingAnchor, constant: -12.0),
            noticeStack.topAnchor.constraint(equalTo: noticeCard.topAnchor, constant: 10.0),
            noticeStack.bottomAnchor.constraint(equalTo: noticeCard.bottomAnchor, constant: -10.0)
        ])
        updateNotice()

        runButton.accessibilityIdentifier = "operation.runExploit"
        injectButton.accessibilityIdentifier = "operation.inject"
        cleanButton.accessibilityIdentifier = "operation.clean"
        openGameButton.accessibilityIdentifier = "operation.opengame"

        runButton.addTarget(self, action: #selector(runTapped), for: .touchUpInside)
        cleanButton.addTarget(self, action: #selector(cleanTapped), for: .touchUpInside)
        openGameButton.addTarget(self, action: #selector(openGameTapped), for: .touchUpInside)

        // Inyectar usa hold-to-confirm, no touchUpInside simple.
        let holdGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleHoldGesture(_:)))
        holdGesture.minimumPressDuration = 0
        injectButton.addGestureRecognizer(holdGesture)
        setupHoldRing()

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
        stackView.addArrangedSubview(noticeCard)
        stackView.addArrangedSubview(runButton)
        stackView.addArrangedSubview(injectButton)
        stackView.addArrangedSubview(cleanButton)
        stackView.addArrangedSubview(openGameButton)
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
            stackView.widthAnchor.constraint(greaterThanOrEqualToConstant: 240.0),
            runButton.heightAnchor.constraint(equalToConstant: AppTheme.controlHeight),
            injectButton.heightAnchor.constraint(equalToConstant: AppTheme.controlHeight),
            cleanButton.heightAnchor.constraint(equalToConstant: AppTheme.controlHeight),
            openGameButton.heightAnchor.constraint(equalToConstant: AppTheme.controlHeight)
        ])

        showPreInjectButtons(animated: false)
    }

    // MARK: - Maquina de estados de botones

    func showPreInjectButtons(animated: Bool) {
        setButtonsVisible(run: true, inject: true, clean: false, openGame: false, animated: animated)
    }

    private func showPostInjectButtons(animated: Bool) {
        setButtonsVisible(run: false, inject: false, clean: true, openGame: true, animated: animated)
    }

    private func setButtonsVisible(run: Bool, inject: Bool, clean: Bool, openGame: Bool, animated: Bool) {
        let apply = {
            self.runButton.isHidden = !run
            self.injectButton.isHidden = !inject
            self.cleanButton.isHidden = !clean
            self.openGameButton.isHidden = !openGame
            self.runButton.alpha = run ? 1 : 0
            self.injectButton.alpha = inject ? 1 : 0
            self.cleanButton.alpha = clean ? 1 : 0
            self.openGameButton.alpha = openGame ? 1 : 0
        }
        if animated {
            UIView.animate(withDuration: AppTheme.durationModal, delay: 0, options: [.curveEaseOut], animations: apply)
        } else {
            apply()
        }
    }

    private func updateSubtitle() {
        titleLabel.text = "\(selectedGame.rawValue) / \(selectedMode.displayName)"
        subtitleLabel.text = nil
    }

    private func updateNotice() {
        let visible = selectedMode.noticeEnabled && !selectedMode.noticeTitle.isEmpty && !selectedMode.noticeBody.isEmpty
        noticeCard.isHidden = !visible
        guard visible else { return }
        let tint: UIColor
        switch selectedMode.noticeLevel.lowercased() {
        case "green": tint = AppTheme.success
        case "red": tint = AppTheme.failure
        default: tint = AppTheme.warm
        }
        noticeCard.backgroundColor = tint.withAlphaComponent(0.12)
        noticeCard.layer.borderColor = tint.withAlphaComponent(0.55).cgColor
        noticeTitleLabel.textColor = tint
        noticeBodyLabel.textColor = AppTheme.secondaryText
        noticeTitleLabel.text = selectedMode.noticeTitle
        noticeBodyLabel.text = selectedMode.noticeBody
    }

    // MARK: - Hold-to-confirm

    private func setupHoldRing() {
        holdRingLayer.strokeColor = AppTheme.accentHot.cgColor
        holdRingLayer.fillColor = UIColor.clear.cgColor
        holdRingLayer.lineWidth = 3
        holdRingLayer.strokeEnd = 0
        holdRingLayer.opacity = 0
        injectButton.layer.addSublayer(holdRingLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let bounds = injectButton.bounds
        guard bounds.width > 0 else { return }
        let path = UIBezierPath(roundedRect: bounds.insetBy(dx: 1.5, dy: 1.5), cornerRadius: AppTheme.controlCornerRadius)
        holdRingLayer.path = path.cgPath
        holdRingLayer.frame = bounds
    }

    @objc private func handleHoldGesture(_ gesture: UILongPressGestureRecognizer) {
        guard injectButton.isEnabled else { return }
        switch gesture.state {
        case .began:
            startHold()
        case .ended, .cancelled, .failed:
            cancelHold()
        default:
            break
        }
    }

    private func startHold() {
        holdProgress = 0
        holdRingLayer.opacity = 1
        SoundService.shared.startHoldTone()
        HapticsService.light()
        holdTimer?.invalidate()
        holdTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            self.holdProgress += CGFloat(1.0 / 60.0 / self.holdDuration)
            self.holdRingLayer.strokeEnd = min(self.holdProgress, 1.0)
            SoundService.shared.updateHoldTone(pct: Double(min(self.holdProgress, 1.0)) * 100)
            if self.holdProgress >= 1.0 {
                timer.invalidate()
                self.holdTimer = nil
                self.completeHold()
            }
        }
    }

    private func cancelHold() {
        holdTimer?.invalidate()
        holdTimer = nil
        SoundService.shared.stopHoldTone()
        UIView.animate(withDuration: 0.2) {
            self.holdRingLayer.strokeEnd = 0
            self.holdRingLayer.opacity = 0
        }
    }

    private func completeHold() {
        SoundService.shared.stopHoldTone()
        UIView.animate(withDuration: 0.15) {
            self.holdRingLayer.opacity = 0
        } completion: { _ in
            self.holdRingLayer.strokeEnd = 0
        }
        delegate?.operationView(self, didTap: .inject)
    }

    @objc private func runTapped() {
        delegate?.operationView(self, didTap: .runExploit)
    }

    @objc private func cleanTapped() {
        delegate?.operationView(self, didTap: .clean)
    }

    @objc private func openGameTapped() {
        SoundService.shared.playClick()
        onOpenGame?()
    }
}
