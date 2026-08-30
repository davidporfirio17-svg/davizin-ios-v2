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

    /// Muestra un mensaje personalizado del panel al cliente (popup).
    func showNotice(_ message: String, completion: @escaping () -> Void) {
        let alert = UIAlertController(title: "Aviso", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completion()
        })
        present(alert, animated: true)
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
        headerView.title = "Davizin"
        headerView.showsBackButton = false

        let screen = LoginView()
        screen.delegate = self
        loginView = screen
        display(screen, animated: animated)
    }

    private func showGameSelection(animated: Bool) {
        currentStage = .gameSelection
        headerView.title = "Select Game"
        headerView.showsBackButton = true

        let screen = GameSelectionView()
        screen.delegate = self
        screen.setSelectedGame(selectedGame)
        gameSelectionView = screen
        display(screen, animated: animated)
    }

    private func showModeSelection(animated: Bool) {
        currentStage = .modeSelection
        headerView.title = selectedGame.rawValue
        headerView.showsBackButton = true

        let screen = ModeSelectionView()
        screen.delegate = self
        screen.setSelectedMode(selectedMode)
        modeSelectionView = screen
        display(screen, animated: animated)
    }

    private func showOperation(animated: Bool) {
        currentStage = .operation
        headerView.title = "\(selectedGame.rawValue) - \(selectedMode.rawValue)"
        headerView.showsBackButton = true

        let screen = OperationView()
        screen.delegate = self
        screen.selectedGame = selectedGame
        screen.selectedMode = selectedMode
        operationView = screen
        display(screen, animated: animated)
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
        onClose?()
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
