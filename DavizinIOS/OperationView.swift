import UIKit

protocol OperationViewDelegate: AnyObject {
    func operationView(_ view: OperationView, didTap operation: ARIFIOperationKind)
}

final class OperationView: UIView {
    weak var delegate: OperationViewDelegate?

    // ── UI ────────────────────────────────────────────────────────
    private let topInfoLabel  = UILabel()
    private let runButton     = ARIFIButton(title: "Run Exploit", style: .secondary)
    private let injectButton  = ARIFIButton(title: "Inject", style: .primary)
    private let cleanButton   = ARIFIButton(title: "Clean", style: .secondary)
    private let resultLabel   = UILabel()
    private let stackView     = UIStackView()

    private(set) var operationState: ARIFIOperationState = .idle

    var selectedGame: ARIFIGame = .freeFireMax { didSet { updateInfo() } }
    var selectedMode: ARIFIMode = .drag        { didSet { updateInfo() } }

    // ── Init ──────────────────────────────────────────────────────
    override init(frame: CGRect) { super.init(frame: frame); setup() }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    // ── State ─────────────────────────────────────────────────────
    func setState(_ state: ARIFIOperationState) {
        operationState = state
        resultLabel.textColor = AppTheme.secondaryText
        runButton.setLoading(false)
        injectButton.setLoading(false)
        cleanButton.setLoading(false)

        let busy = state.isBusy
        runButton.isEnabled    = !busy
        injectButton.isEnabled = !busy
        cleanButton.isEnabled  = !busy

        switch state {
        case .idle:
            resultLabel.text = nil; resultLabel.isHidden = true
        case .checking:
            resultLabel.text = "Checking..."; resultLabel.isHidden = false
        case .running:
            runButton.setLoading(true, title: "Running...")
            resultLabel.text = "Running..."; resultLabel.isHidden = false
        case .injecting:
            injectButton.setLoading(true, title: "Injecting...")
            resultLabel.text = "Injecting..."; resultLabel.isHidden = false
        case .cleaning:
            cleanButton.setLoading(true, title: "Cleaning...")
            resultLabel.text = "Cleaning..."; resultLabel.isHidden = false
        case .succeeded(let msg):
            resultLabel.text = "✓ " + msg
            resultLabel.textColor = AppTheme.success
            resultLabel.isHidden = false
        case .failed(let msg):
            resultLabel.text = "✗ " + msg
            resultLabel.textColor = AppTheme.failure
            resultLabel.isHidden = false
        }
    }

    // ── Setup ─────────────────────────────────────────────────────
    private func setup() {
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false

        // Info label
        topInfoLabel.textColor = AppTheme.secondaryText
        topInfoLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        topInfoLabel.textAlignment = .center
        topInfoLabel.numberOfLines = 1
        updateInfo()

        // Result label
        resultLabel.font = AppTheme.captionFont()
        resultLabel.textAlignment = .center
        resultLabel.numberOfLines = 0
        resultLabel.isHidden = true

        // Targets
        runButton.addTarget(self, action: #selector(runTapped),    for: .touchUpInside)
        injectButton.addTarget(self, action: #selector(injectTapped), for: .touchUpInside)
        cleanButton.addTarget(self, action: #selector(cleanTapped), for: .touchUpInside)

        // Stack — fills the view vertically
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.spacing = 14
        stackView.translatesAutoresizingMaskIntoConstraints = false

        // Spacer helpers
        func spacer(_ h: CGFloat) -> UIView {
            let v = UIView(); v.translatesAutoresizingMaskIntoConstraints = false
            v.heightAnchor.constraint(equalToConstant: h).isActive = true
            return v
        }

        stackView.addArrangedSubview(spacer(12))
        stackView.addArrangedSubview(topInfoLabel)
        stackView.addArrangedSubview(spacer(24))
        stackView.addArrangedSubview(runButton)
        stackView.addArrangedSubview(injectButton)
        stackView.addArrangedSubview(cleanButton)
        stackView.addArrangedSubview(resultLabel)

        // Flexible spacer at bottom
        let flex = UIView()
        flex.setContentHuggingPriority(.defaultLow, for: .vertical)
        stackView.addArrangedSubview(flex)

        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -20),

            runButton.heightAnchor.constraint(equalToConstant: AppTheme.controlHeight),
            injectButton.heightAnchor.constraint(equalToConstant: AppTheme.controlHeight),
            cleanButton.heightAnchor.constraint(equalToConstant: AppTheme.controlHeight),
        ])
    }

    private func updateInfo() {
        topInfoLabel.text = "\(selectedGame.rawValue)  ·  \(selectedMode.rawValue)"
    }

    @objc private func runTapped()    { delegate?.operationView(self, didTap: .runExploit) }
    @objc private func injectTapped() { delegate?.operationView(self, didTap: .inject) }
    @objc private func cleanTapped()  { delegate?.operationView(self, didTap: .clean) }
}
