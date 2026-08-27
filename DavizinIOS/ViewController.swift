import UIKit

final class ViewController: UIViewController {
    var simulateUIStates = true

    var onLoginContinue: ((String) -> Void)?
    var onGameSelected: ((ARIFIGame) -> Void)?
    var onModeSelected: ((ARIFIMode) -> Void)?
    var onOperation: ((ARIFIOperationKind) -> Void)?
    var onClose: (() -> Void)?

    private let animatedBG = ARIFIAnimatedBackgroundView()
    private let headerView = ARIFIHeaderView()
    private let contentView = UIView()

    private var currentStage: ARIFIScreenStage = .login
    private var selectedGame: ARIFIGame = .freeFireMax
    private var selectedMode: ARIFIMode = .drag

    private var loginView: LoginView?
    private var gameSelectionView: GameSelectionView?
    private var modeSelectionView: ModeSelectionView?
    private var operationView: OperationView?

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    // MARK: - Public controls
    func showGameSelectionScreen()  { showGameSelection(animated: true) }
    func showModeSelectionScreen()  { showModeSelection(animated: true) }
    func showOperationScreen()      { showOperation(animated: true) }
    func setLoginChecking(_ c: Bool){ loginView?.setChecking(c) }
    func setLoginStatus(_ t: String?, success: Bool = false) { loginView?.setStatus(t, success: success) }
    func setOperationState(_ s: ARIFIOperationState) { operationView?.setState(s) }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupLayout()
        showLogin(animated: false)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animatedBG.startAnimating()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        animatedBG.stopAnimating()
    }

    private func setupLayout() {
        view.backgroundColor = .black

        // Background — full screen
        animatedBG.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(animatedBG)
        animatedBG.arifiPinEdges(to: view)

        // Header
        headerView.delegate = self
        headerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerView)

        // Content — fills everything below header
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.backgroundColor = .clear
        view.addSubview(contentView)

        NSLayoutConstraint.activate([
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 6),

            contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 8),
            contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Screen transitions
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
        headerView.title = "Davizin"
        headerView.showsBackButton = false
        let screen = OperationView()
        screen.delegate = self
        screen.selectedGame = selectedGame
        screen.selectedMode = selectedMode
        operationView = screen
        display(screen, animated: animated)
    }

    private func display(_ screen: UIView, animated: Bool) {
        contentView.subviews.forEach { $0.removeFromSuperview() }
        screen.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(screen)
        screen.arifiPinEdges(to: contentView)

        guard animated else { screen.alpha = 1; screen.transform = .identity; return }
        screen.alpha = 0
        screen.transform = CGAffineTransform(translationX: 0, y: 12)
        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseOut]) {
            screen.alpha = 1
            screen.transform = .identity
        }
    }

    private func goBack() {
        switch currentStage {
        case .login: break
        case .gameSelection: showLogin(animated: true)
        case .modeSelection: showGameSelection(animated: true)
        case .operation: showModeSelection(animated: true)
        }
    }

    // MARK: - Simulate
    private func simulateLogin(key: String) {
        loginView?.setChecking(true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) { [weak self] in
            guard let self, self.currentStage == .login else { return }
            self.loginView?.setChecking(false)
            self.loginView?.setStatus("Access granted", success: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self, self.currentStage == .login else { return }
                self.showGameSelection(animated: true)
            }
        }
    }

    private func simulateOperation(_ op: ARIFIOperationKind) {
        let state: ARIFIOperationState = op == .runExploit ? .running : op == .inject ? .injecting : .cleaning
        operationView?.setState(state)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { [weak self] in
            guard let self, self.currentStage == .operation else { return }
            let msg = op == .runExploit ? "Run complete" : op == .inject ? "Injection complete" : "Successfully cleaned!"
            self.operationView?.setState(.succeeded(msg))
        }
    }
}

extension ViewController: ARIFIHeaderViewDelegate {
    func headerViewDidTapBack(_ h: ARIFIHeaderView) { goBack() }
    func headerViewDidTapClose(_ h: ARIFIHeaderView) { onClose?() }
}

extension ViewController: LoginViewDelegate {
    func loginView(_ v: LoginView, didTapContinueWithKey key: String) {
        onLoginContinue?(key)
        if simulateUIStates { simulateLogin(key: key) }
    }
}

extension ViewController: GameSelectionViewDelegate {
    func gameSelectionView(_ v: GameSelectionView, didSelect game: ARIFIGame) {
        selectedGame = game
        onGameSelected?(game)
        showModeSelection(animated: true)
    }
}

extension ViewController: ModeSelectionViewDelegate {
    func modeSelectionView(_ v: ModeSelectionView, didSelect mode: ARIFIMode) {
        selectedMode = mode
        onModeSelected?(mode)
        showOperation(animated: true)
    }
}

extension ViewController: OperationViewDelegate {
    func operationView(_ v: OperationView, didTap op: ARIFIOperationKind) {
        onOperation?(op)
        if simulateUIStates { simulateOperation(op) }
    }
}
