import UIKit

final class ViewController: UIViewController {
    /// Actívalo en false cuando conectes tus propios callbacks de aplicación.
    var simulateUIStates = true

    /// Callbacks vacíos por defecto para conectar la lógica real desde fuera del UI.
    var onLoginContinue: ((String) -> Void)?
    var onGameSelected: ((ARIFIGame) -> Void)?
    var onModeSelected: ((ARIFIMode) -> Void)?
    var onOperation: ((ARIFIOperationKind) -> Void)?
    var onClose: (() -> Void)?

    private let animatedBackgroundView = ARIFIAnimatedBackgroundView()
    private let headerView = ARIFIHeaderView()
    private let contentContainerView = UIView()

    private var currentStage: ARIFIScreenStage = .login
    private var selectedGame: ARIFIGame = .freeFireMax
    private var selectedMode: ARIFIMode = .drag

    private var loginView: LoginView?
    private var gameSelectionView: GameSelectionView?
    private var modeSelectionView: ModeSelectionView?
    private var operationView: OperationView?

    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }

    /// Usa este factory cuando presentes el UI desde otro controlador.
    /// El estilo se fija antes de `present(...)`, que es el momento correcto para evitar `.pageSheet`.
    static func makeFullScreen() -> ViewController {
        let controller = ViewController()
        controller.modalPresentationStyle = .fullScreen
        controller.modalPresentationCapturesStatusBarAppearance = true
        return controller
    }

    // MARK: - Public UI controls

    func showGameSelectionScreen() {
        showGameSelection(animated: true)
    }

    func showModeSelectionScreen() {
        showModeSelection(animated: true)
    }

    func showOperationScreen() {
        showOperation(animated: true)
    }

    func setLoginChecking(_ checking: Bool) {
        loginView?.setChecking(checking)
    }

    func setLoginStatus(_ text: String?, success: Bool = false) {
        loginView?.setStatus(text, success: success)
    }

    func setOperationState(_ state: ARIFIOperationState) {
        operationView?.setState(state)
    }

    /// Actualiza el contador de tiempo restante en el header.
    func setCountdownText(_ text: String) {
        headerView.countdownText = text
    }

    func setCountdownColor(_ color: UIColor) {
        headerView.setCountdownColor(color)
    }

    /// Muestra un mensaje personalizado del panel al cliente (popup con estilo Davizin).
    func showNotice(_ message: String, completion: @escaping () -> Void) {
        let overlay = UIView()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        overlay.alpha = 0.0

        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = AppTheme.card
        card.layer.cornerRadius = AppTheme.cardCornerRadius
        card.layer.borderWidth = 1.0
        card.layer.borderColor = AppTheme.accent.withAlphaComponent(0.4).cgColor
        card.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)

        // Circulo con icono de campana
        let iconCircle = UIView()
        iconCircle.translatesAutoresizingMaskIntoConstraints = false
        iconCircle.backgroundColor = AppTheme.accent.withAlphaComponent(0.15)
        iconCircle.layer.cornerRadius = 32.0
        iconCircle.layer.borderWidth = 2.0
        iconCircle.layer.borderColor = AppTheme.accent.cgColor

        let iconView = UIImageView(image: UIImage(systemName: "bell.fill"))
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.tintColor = AppTheme.accent
        iconView.contentMode = .scaleAspectFit

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Aviso"
        titleLabel.textColor = AppTheme.primaryText
        titleLabel.font = UIFont.systemFont(ofSize: 20.0, weight: .bold)
        titleLabel.textAlignment = .center

        let messageLabel = UILabel()
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.text = message
        messageLabel.textColor = AppTheme.secondaryText
        messageLabel.font = UIFont.systemFont(ofSize: 15.0, weight: .regular)
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        let okButton = UIButton(type: .system)
        okButton.translatesAutoresizingMaskIntoConstraints = false
        okButton.setTitle("Entendido", for: .normal)
        okButton.setTitleColor(.white, for: .normal)
        okButton.titleLabel?.font = UIFont.systemFont(ofSize: 16.0, weight: .semibold)
        okButton.backgroundColor = AppTheme.accent
        okButton.layer.cornerRadius = AppTheme.controlCornerRadius

        iconCircle.addSubview(iconView)
        card.addSubview(iconCircle)
        card.addSubview(titleLabel)
        card.addSubview(messageLabel)
        card.addSubview(okButton)
        overlay.addSubview(card)
        view.addSubview(overlay)

        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            card.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            card.leadingAnchor.constraint(greaterThanOrEqualTo: overlay.leadingAnchor, constant: 32.0),
            card.trailingAnchor.constraint(lessThanOrEqualTo: overlay.trailingAnchor, constant: -32.0),
            card.widthAnchor.constraint(lessThanOrEqualToConstant: 340.0),

            iconCircle.topAnchor.constraint(equalTo: card.topAnchor, constant: 28.0),
            iconCircle.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            iconCircle.widthAnchor.constraint(equalToConstant: 64.0),
            iconCircle.heightAnchor.constraint(equalToConstant: 64.0),

            iconView.centerXAnchor.constraint(equalTo: iconCircle.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconCircle.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 28.0),
            iconView.heightAnchor.constraint(equalToConstant: 28.0),

            titleLabel.topAnchor.constraint(equalTo: iconCircle.bottomAnchor, constant: 16.0),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 24.0),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -24.0),

            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10.0),
            messageLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 24.0),
            messageLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -24.0),

            okButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 24.0),
            okButton.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 24.0),
            okButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -24.0),
            okButton.heightAnchor.constraint(equalToConstant: 50.0),
            okButton.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24.0)
        ])

        // Accion del boton: cerrar con animacion y continuar
        let dismissAction = UIAction { _ in
            UIView.animate(withDuration: 0.2, animations: {
                overlay.alpha = 0.0
                card.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
            }) { _ in
                overlay.removeFromSuperview()
                completion()
            }
        }
        okButton.addAction(dismissAction, for: .touchUpInside)

        // Animacion de entrada
        UIView.animate(withDuration: 0.28, delay: 0.0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: [.curveEaseOut]) {
            overlay.alpha = 1.0
            card.transform = .identity
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        modalPresentationStyle = .fullScreen
        modalPresentationCapturesStatusBarAppearance = true
        configureBaseUI()
        showLogin(animated: false)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animatedBackgroundView.startAnimating()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        animatedBackgroundView.stopAnimating()
    }

    private func configureBaseUI() {
        view.backgroundColor = AppTheme.background

        animatedBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(animatedBackgroundView)

        headerView.delegate = self
        view.addSubview(headerView)

        contentContainerView.translatesAutoresizingMaskIntoConstraints = false
        contentContainerView.backgroundColor = .clear
        view.addSubview(contentContainerView)

        NSLayoutConstraint.activate([
            animatedBackgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            animatedBackgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            animatedBackgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            animatedBackgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16.0),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16.0),
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 6.0),

            contentContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentContainerView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 4.0),
            contentContainerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    private func showLogin(animated: Bool) {
        currentStage = .login
        headerView.title = "Nyxel External"
        headerView.showsBackButton = false

        let screen = LoginView()
        screen.delegate = self
        loginView = screen
        display(screen, animated: animated)

        // Chequeo inteligente de compatibilidad del dispositivo
        runCompatibilityCheck()
    }

    /// Prueba si el dispositivo puede inyectar y pinta el estado en el login.
    private func runCompatibilityCheck() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = InjectorService.checkCompatibility()
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .compatible:
                    self.loginView?.setCompatibility("✅ Compatible con tu dispositivo", color: AppTheme.success)
                case .notCompatible:
                    self.loginView?.setCompatibility("❌ No compatible con esta versión de iOS", color: AppTheme.failure)
                case .noGameInstalled:
                    self.loginView?.setCompatibility("⚠️ Instala Free Fire para verificar", color: AppTheme.accentWarm)
                }
            }
        }
    }

    private func showGameSelection(animated: Bool) {
        currentStage = .gameSelection
        headerView.title = "Seleccionar entorno"
        headerView.showsBackButton = true

        let screen = GameSelectionView()
        screen.delegate = self
        screen.setSelectedGame(selectedGame)
        gameSelectionView = screen
        display(screen, animated: animated)
    }

    private func showModeSelection(animated: Bool) {
        currentStage = .modeSelection
        headerView.title = "Configurar / \(selectedGame.rawValue)"
        headerView.showsBackButton = true

        let screen = ModeSelectionView()
        screen.delegate = self
        screen.setSelectedMode(selectedMode)
        modeSelectionView = screen
        display(screen, animated: animated)
    }

    private func showOperation(animated: Bool) {
        currentStage = .operation
        headerView.title = "Control / \(selectedMode.rawValue)"
        headerView.showsBackButton = true

        let screen = OperationView()
        screen.delegate = self
        screen.selectedGame = selectedGame
        screen.selectedMode = selectedMode
        let gameToOpen = selectedGame
        screen.onOpenGame = { [weak self] in
            self?.openGame(gameToOpen)
        }
        operationView = screen
        display(screen, animated: animated)
    }

    /// Abre Free Fire (MAX o normal) usando su esquema de URL.
    private func openGame(_ game: ARIFIGame) {
        let scheme: String
        switch game {
        case .freeFireMax: scheme = "freefiremax://"
        case .freeFire:    scheme = "freefireth://"
        }
        if let url = URL(string: scheme) {
            UIApplication.shared.open(url, options: [:]) { success in
                if !success {
                    // Si el esquema falla, intentar abrir por bundle (fallback)
                    // No siempre funciona pero es un intento extra
                }
            }
        }
    }

    private func display(_ screen: UIView, animated: Bool) {
        contentContainerView.subviews.forEach { $0.removeFromSuperview() }
        screen.translatesAutoresizingMaskIntoConstraints = false
        contentContainerView.addSubview(screen)
        screen.arifiPinEdges(to: contentContainerView)

        guard animated else {
            screen.alpha = 1.0
            screen.transform = .identity
            return
        }

        screen.alpha = 0.0
        screen.transform = CGAffineTransform(translationX: 0.0, y: 10.0)
        UIView.animate(
            withDuration: 0.28,
            delay: 0.0,
            options: [.curveEaseOut, .beginFromCurrentState, .allowUserInteraction]
        ) {
            screen.alpha = 1.0
            screen.transform = .identity
        }
    }

    private func simulateLogin(key: String) {
        guard let screen = loginView else { return }
        screen.setChecking(true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) { [weak self] in
            guard let self = self, self.currentStage == .login else { return }
            screen.setChecking(false)
            screen.setStatus("Access granted", success: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                guard let self = self, self.currentStage == .login else { return }
                self.showGameSelection(animated: true)
            }
        }
    }

    private func simulateOperation(_ operation: ARIFIOperationKind) {
        guard let screen = operationView else { return }
        let state: ARIFIOperationState
        switch operation {
        case .runExploit:
            state = .running
        case .inject:
            state = .injecting
        case .clean:
            state = .cleaning
        }
        screen.setState(state)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) { [weak self] in
            guard let self = self, self.currentStage == .operation else { return }
            let message: String
            switch operation {
            case .runExploit:
                message = "Run complete"
            case .inject:
                message = "Injection complete"
            case .clean:
                message = "Successfully cleaned !"
            }
            screen.setState(.succeeded(message))
        }
    }

    private func goBack() {
        switch currentStage {
        case .login:
            break
        case .gameSelection:
            showLogin(animated: true)
        case .modeSelection:
            showGameSelection(animated: true)
        case .operation:
            showModeSelection(animated: true)
        }
    }
}

extension ViewController: ARIFIHeaderViewDelegate {
    func headerViewDidTapBack(_ headerView: ARIFIHeaderView) {
        goBack()
    }

    func headerViewDidTapClose(_ headerView: ARIFIHeaderView) {
        // La X regresa directo a la pantalla de la key (login)
        showLogin(animated: true)
    }
}

extension ViewController: LoginViewDelegate {
    func loginView(_ loginView: LoginView, didTapContinueWithKey key: String) {
        onLoginContinue?(key)
        guard simulateUIStates else { return }
        simulateLogin(key: key)
    }
}

extension ViewController: GameSelectionViewDelegate {
    func gameSelectionView(_ view: GameSelectionView, didSelect game: ARIFIGame) {
        selectedGame = game
        onGameSelected?(game)
        showModeSelection(animated: true)
    }
}

extension ViewController: ModeSelectionViewDelegate {
    func modeSelectionView(_ view: ModeSelectionView, didSelect mode: ARIFIMode) {
        selectedMode = mode
        onModeSelected?(mode)
        showOperation(animated: true)
    }
}

extension ViewController: OperationViewDelegate {
    func operationView(_ view: OperationView, didTap operation: ARIFIOperationKind) {
        onOperation?(operation)
        guard simulateUIStates else { return }
        simulateOperation(operation)
    }
}
