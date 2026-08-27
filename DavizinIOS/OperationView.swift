import UIKit

protocol OperationViewDelegate: AnyObject {
    func operationView(_ view: OperationView, didTap operation: ARIFIOperationKind)
}

final class OperationView: UIView {
    weak var delegate: OperationViewDelegate?

    private let gameLabel = UILabel()
    private let statusLabel = UILabel()
    private let runButton = ARIFIButton(title: "Run Exploit", style: .secondary)
    private let injectButton = ARIFIButton(title: "Inject", style: .primary)
    private let cleanButton = ARIFIButton(title: "Clean", style: .secondary)
    private let resultLabel = UILabel()

    private(set) var operationState: ARIFIOperationState = .idle

    var selectedGame: ARIFIGame = .freeFireMax { didSet { updateContent() } }
    var selectedMode: ARIFIMode = .drag { didSet { updateContent() } }

    override init(frame: CGRect) { super.init(frame: frame); configure() }
    required init?(coder: NSCoder) { super.init(coder: coder); configure() }

    func setState(_ state: ARIFIOperationState) {
        operationState = state
        resultLabel.textColor = AppTheme.secondaryText
        runButton.setLoading(false)
        injectButton.setLoading(false)
        cleanButton.setLoading(false)

        let enabled = !state.isBusy
        runButton.isEnabled = enabled
        injectButton.isEnabled = enabled
        cleanButton.isEnabled = enabled

        switch state {
        case .idle:
            resultLabel.text = nil
            resultLabel.isHidden = true
        case .checking:
            resultLabel.text = "Checking..."
            resultLabel.isHidden = false
        case .running:
            runButton.setLoading(true, title: "Running...")
            resultLabel.text = "Running exploit..."
            resultLabel.isHidden = false
        case .injecting:
            injectButton.setLoading(true, title: "Injecting...")
            resultLabel.text = "Injecting mod..."
            resultLabel.isHidden = false
        case .cleaning:
            cleanButton.setLoading(true, title: "Cleaning...")
            resultLabel.text = "Cleaning..."
            resultLabel.isHidden = false
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

    private func configure() {
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false

        // Game label
        gameLabel.textColor = AppTheme.secondaryText
        gameLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        gameLabel.textAlignment = .center
        gameLabel.translatesAutoresizingMaskIntoConstraints = false

        // Result label
        resultLabel.textColor = AppTheme.secondaryText
        resultLabel.font = AppTheme.captionFont()
        resultLabel.textAlignment = .center
        resultLabel.numberOfLines = 0
        resultLabel.isHidden = true
        resultLabel.translatesAutoresizingMaskIntoConstraints = false

        // Buttons
        runButton.translatesAutoresizingMaskIntoConstraints = false
        injectButton.translatesAutoresizingMaskIntoConstraints = false
        cleanButton.translatesAutoresizingMaskIntoConstraints = false

        runButton.addTarget(self, action: #selector(runTapped), for: .touchUpInside)
        injectButton.addTarget(self, action: #selector(injectTapped), for: .touchUpInside)
        cleanButton.addTarget(self, action: #selector(cleanTapped), for: .touchUpInside)

        addSubview(gameLabel)
        addSubview(runButton)
        addSubview(injectButton)
        addSubview(cleanButton)
        addSubview(resultLabel)

        let pad: CGFloat = 20
        let btnH: CGFloat = AppTheme.controlHeight

        NSLayoutConstraint.activate([
            // Game label at top
            gameLabel.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 20),
            gameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: pad),
            gameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -pad),

            // Buttons centered vertically
            runButton.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -btnH - 16),
            runButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: pad),
            runButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -pad),
            runButton.heightAnchor.constraint(equalToConstant: btnH),

            injectButton.topAnchor.constraint(equalTo: runButton.bottomAnchor, constant: 12),
            injectButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: pad),
            injectButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -pad),
            injectButton.heightAnchor.constraint(equalToConstant: btnH),

            cleanButton.topAnchor.constraint(equalTo: injectButton.bottomAnchor, constant: 12),
            cleanButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: pad),
            cleanButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -pad),
            cleanButton.heightAnchor.constraint(equalToConstant: btnH),

            // Result below buttons
            resultLabel.topAnchor.constraint(equalTo: cleanButton.bottomAnchor, constant: 16),
            resultLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: pad),
            resultLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -pad),
        ])

        updateContent()
    }

    private func updateContent() {
        gameLabel.text = "\(selectedGame.rawValue) · \(selectedMode.rawValue)"
    }

    @objc private func runTapped()    { delegate?.operationView(self, didTap: .runExploit) }
    @objc private func injectTapped() { delegate?.operationView(self, didTap: .inject) }
    @objc private func cleanTapped()  { delegate?.operationView(self, didTap: .clean) }
}
