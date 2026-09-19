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
    private var missionMapView: MissionMapView?
    private var profileView: ProfileView?
    private var stageBeforeProfile: ARIFIScreenStage = .modeSelection
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
        switch state {
        case .succeeded(let message):
            ARIFIToastCenter.shared.show(title: "Operación completada", subtitle: message, kind: .success)
        case .failed(let message):
            ARIFIToastCenter.shared.show(title: "Operación fallida", subtitle: message, kind: .danger)
        default:
            break
        }
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
        headerView.showsAvatarButton = false

        let screen = LoginView()
        screen.delegate = self
        loginView = screen
        display(screen, animated: animated)

        // Chequeo inteligente de compatibilidad del dispositivo
        runCompatibilityCheck()
    }

    /// Prueba si el dispositivo puede inyectar y pinta el estado en el login.
	private func runCompatibilityCheck() {
		guard NyxelSupportPolicy.isCurrentSystemSupported else {
			headerView.setSystemCompatibility(
				"iOS/iPadOS \(NyxelSupportPolicy.currentSystemDescription) • No compatible",
				color: AppTheme.failure
			)
			loginView?.setCompatibility(
				"❌ No compatible: \(NyxelSupportPolicy.currentSystemDescription) no está verificado",
				color: AppTheme.failure
			)
			return
		}

		DispatchQueue.global(qos: .userInitiated).async { [weak self] in
			let result = InjectorService.checkCompatibility()
			DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
				case .compatible:
					self.headerView.setSystemCompatibility(
						"iOS/iPadOS \(NyxelSupportPolicy.currentSystemDescription) • Compatible",
						color: AppTheme.success
					)
					self.loginView?.setCompatibility(
						"✅ Compatible — \(NyxelSupportPolicy.currentSystemDescription)",
						color: AppTheme.success
					)
				case .notCompatible:
					self.headerView.setSystemCompatibility(
						"iOS/iPadOS \(NyxelSupportPolicy.currentSystemDescription) • Sin acceso",
						color: AppTheme.failure
					)
					self.loginView?.setCompatibility(
						"❌ No se pudo acceder al contenedor en \(NyxelSupportPolicy.currentSystemDescription)",
						color: AppTheme.failure
					)
				case .noGameInstalled:
					self.headerView.setSystemCompatibility(
						"iOS/iPadOS \(NyxelSupportPolicy.currentSystemDescription) • Verificado",
						color: AppTheme.accentWarm
					)
					self.loginView?.setCompatibility("⚠️ Instala Free Fire para verificar", color: AppTheme.accentWarm)
				case .unsupportedSystem:
					self.headerView.setSystemCompatibility(
						"iOS/iPadOS \(NyxelSupportPolicy.currentSystemDescription) • No compatible",
						color: AppTheme.failure
					)
					self.loginView?.setCompatibility(
						"❌ No compatible — \(NyxelSupportPolicy.currentSystemDescription) no está verificado",
						color: AppTheme.failure
					)
				}
            }
        }
    }

    private func showGameSelection(animated: Bool) {
        currentStage = .gameSelection
        headerView.title = "Seleccionar entorno"
        headerView.showsBackButton = true
        headerView.showsAvatarButton = true

        let screen = GameSelectionView()
        screen.delegate = self
        screen.setSelectedGame(selectedGame)
        gameSelectionView = screen
        display(screen, animated: animated)
    }

    private func showModeSelection(animated: Bool) {
        currentStage = .modeSelection
        if let firstActive = ARIFIModeCatalog.enabledModes(for: selectedGame).first, !ARIFIModeCatalog.enabledModes(for: selectedGame).contains(selectedMode) {
            selectedMode = firstActive
        }
        headerView.title = "Configurar / \(selectedGame.rawValue)"
        headerView.showsBackButton = true

        let screen = MissionMapView()
        screen.delegate = self
        screen.setModes(ARIFIModeCatalog.enabledModes(for: selectedGame), selected: selectedMode)
        missionMapView = screen
        display(screen, animated: animated)
    }

    private func showOperation(animated: Bool) {
        guard ARIFIModeCatalog.enabledModes(for: selectedGame).contains(selectedMode) else {
            showModeSelection(animated: animated)
            return
        }
        currentStage = .operation
        headerView.title = "Control / \(selectedMode.displayName)"
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

    /// Perfil: accesible desde el avatar del header en cualquier pantalla (excepto login).
    private func showProfile(animated: Bool) {
        stageBeforeProfile = currentStage == .profile ? stageBeforeProfile : currentStage
        currentStage = .profile
        headerView.title = "Perfil de cuenta"
        headerView.showsBackButton = true

		let screen = ProfileView()
		screen.delegate = self
		screen.onSafeModeChanged = { [weak self] enabled in
			let message = enabled
				? "Modo seguro activo: las operaciones están bloqueadas."
				: "Modo seguro desactivado. Verifica el sistema antes de operar."
			ARIFIToastCenter.shared.show(
				title: enabled ? "Modo seguro" : "Modo operativo",
				subtitle: message,
				kind: enabled ? .warning : .success
			)
			self?.headerView.setSystemCompatibility(
				"iOS/iPadOS \(NyxelSupportPolicy.currentSystemDescription) • \(enabled ? "Seguro" : "Verificado")",
				color: enabled ? AppTheme.accentWarm : AppTheme.success
			)
		}
		screen.refresh()
        profileView = screen
        display(screen, animated: animated)
    }

	/// Abre Free Fire (MAX o normal) usando su esquema de URL.
	private func openGame(_ game: ARIFIGame) {
		let urls: [URL]
		switch game {
		case .freeFireMax:
			urls = ["freefiremax://", "freefire://"].compactMap(URL.init(string:))
		case .freeFire:
			urls = ["freefireth://", "freefire://"].compactMap(URL.init(string:))
		}

		func showOpenError() {
			let alert = UIAlertController(
				title: "No se pudo abrir el juego",
				message: "No se encontró el esquema de \(game.rawValue). Verifica que el juego esté instalado y prueba de nuevo.",
				preferredStyle: .alert
			)
			alert.addAction(UIAlertAction(title: "Entendido", style: .default))
			present(alert, animated: true)
		}

		func attemptOpen(at index: Int) {
			guard index < urls.count else {
				showOpenError()
				return
			}

			UIApplication.shared.open(urls[index], options: [:]) { success in
				guard !success else { return }
				DispatchQueue.main.async {
					attemptOpen(at: index + 1)
				}
			}
		}

		// Se intenta directamente: canOpenURL puede devolver false por restricciones
		// de consulta aun cuando el esquema pueda abrirse correctamente.
		attemptOpen(at: 0)
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
                message = "¡\(self.selectedMode.displayName) inyectado! (simulación)"
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
        case .profile:
            switch stageBeforeProfile {
            case .operation: showOperation(animated: true)
            case .modeSelection: showModeSelection(animated: true)
            case .gameSelection: showGameSelection(animated: true)
            default: showModeSelection(animated: true)
            }
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

    func headerViewDidTapAvatar(_ headerView: ARIFIHeaderView) {
        guard currentStage != .login, currentStage != .profile else { return }
        showProfile(animated: true)
    }

    func headerViewDidLongPressAvatar(_ headerView: ARIFIHeaderView) {
        guard currentStage != .login else { return }
        let alert = UIAlertController(
            title: "¿Cerrar sesión?",
            message: "Vas a regresar a la pantalla de la key.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        alert.addAction(UIAlertAction(title: "Cerrar sesión", style: .destructive) { [weak self] _ in
            self?.showLogin(animated: true)
        })
        present(alert, animated: true)
    }
}

extension ViewController: ProfileViewDelegate {
    func profileViewDidTapLogout(_ view: ProfileView) {
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

extension ViewController: MissionMapViewDelegate {
    func missionMapView(_ view: MissionMapView, didSelect mode: ARIFIMode) {
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
