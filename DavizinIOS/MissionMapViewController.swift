import UIKit

// MARK: - MissionMapViewController — reemplaza ARIFIModeSheet.
// Nodos conectados por curvas (CAShapeLayer), con respiracion idle (glow en loop)
// y una particula que viaja por cada linea. Al tocar un nodo, se selecciona
// y navega directo a OperationView, como en el HTML aprobado.
// Los nodos se posicionan con frames directos (no Auto Layout) porque sus
// posiciones son porcentuales sobre un canvas de alto fijo — mas simple y
// predecible que constraints relativas con multiplicadores dinamicos.

protocol MissionMapDelegate: AnyObject {
    func missionMap(_ vc: MissionMapViewController, didSelect mode: ARIFIMode)
}

final class MissionMapViewController: UIViewController {
    weak var delegate: MissionMapDelegate?
    private let modes: [ARIFIMode]
    private let gameName: String
    private var nodeViews: [MissionNodeView] = []
    private let scrollView = UIScrollView()
    private let canvas = UIView()
    private let canvasHeight: CGFloat = 520
    private var connectionsDrawn = false

    private let positions: [CGPoint] = [
        CGPoint(x: 0.30, y: 0.08),
        CGPoint(x: 0.42, y: 0.34),
        CGPoint(x: 0.32, y: 0.62)
    ]

    init(modes: [ARIFIMode], gameName: String) {
        self.modes = modes
        self.gameName = gameName
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.background

        let eyebrow = UILabel()
        eyebrow.text = "02 — CONFIGURACIÓN"
        eyebrow.font = .systemFont(ofSize: 11, weight: .heavy)
        eyebrow.textColor = AppTheme.accent

        let title = UILabel()
        title.text = "Elige tu modo"
        title.font = AppTheme.titleFont(24)
        title.textColor = AppTheme.primaryText

        let subtitle = UILabel()
        subtitle.text = "Toca un nodo para avanzar por el mapa."
        subtitle.font = .systemFont(ofSize: 12, weight: .regular)
        subtitle.textColor = AppTheme.secondaryText

        let headerStack = UIStackView(arrangedSubviews: [eyebrow, title, subtitle])
        headerStack.axis = .vertical
        headerStack.spacing = 4
        headerStack.alignment = .center
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        canvas.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(headerStack)
        view.addSubview(scrollView)
        scrollView.addSubview(canvas)

        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            headerStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            scrollView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            canvas.topAnchor.constraint(equalTo: scrollView.topAnchor),
            canvas.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            canvas.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            canvas.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            canvas.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            canvas.heightAnchor.constraint(equalToConstant: canvasHeight)
        ])

        buildNodes()
    }

    private func buildNodes() {
        for (index, mode) in modes.enumerated() {
            let node = MissionNodeView(mode: mode, index: index)
            node.onTap = { [weak self] in self?.selectNode(at: index) }
            canvas.addSubview(node)
            nodeViews.append(node)
        }
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let w = canvas.bounds.width > 0 ? canvas.bounds.width : UIScreen.main.bounds.width
        for (index, node) in nodeViews.enumerated() {
            let pos = positions[index % positions.count]
            let size: CGFloat = 92
            node.frame = CGRect(x: pos.x * w - size / 2, y: pos.y * canvasHeight, width: size, height: size)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !connectionsDrawn && canvas.bounds.width > 0 {
            connectionsDrawn = true
            drawConnections()
        }
    }

    private func drawConnections() {
        guard nodeViews.count > 1 else { return }
        let container = CALayer()
        container.frame = canvas.bounds

        for i in 0..<(nodeViews.count - 1) {
            let start = nodeViews[i].center
            let end = nodeViews[i + 1].center
            let path = UIBezierPath()
            path.move(to: start)
            let control = CGPoint(x: (start.x + end.x) / 2 - 40, y: (start.y + end.y) / 2)
            path.addQuadCurve(to: end, controlPoint: control)

            let track = CAShapeLayer()
            track.path = path.cgPath
            track.strokeColor = AppTheme.hairlineStrong.cgColor
            track.fillColor = UIColor.clear.cgColor
            track.lineWidth = 2
            track.lineDashPattern = [3, 9]
            container.addSublayer(track)

            let flow = CAShapeLayer()
            flow.path = path.cgPath
            flow.strokeColor = AppTheme.accent.cgColor
            flow.fillColor = UIColor.clear.cgColor
            flow.lineWidth = 2
            flow.lineDashPattern = [3, 9]
            flow.opacity = 0.65
            flow.shadowColor = AppTheme.accent.cgColor
            flow.shadowRadius = 4
            flow.shadowOpacity = 0.8
            flow.shadowOffset = .zero
            container.addSublayer(flow)

            let dashAnim = CABasicAnimation(keyPath: "lineDashPhase")
            dashAnim.fromValue = 0
            dashAnim.toValue = -24
            dashAnim.duration = 1.4
            dashAnim.repeatCount = .infinity
            flow.add(dashAnim, forKey: "flow")

            let particle = CALayer()
            particle.backgroundColor = AppTheme.accentHot.cgColor
            particle.bounds = CGRect(x: 0, y: 0, width: 5, height: 5)
            particle.cornerRadius = 2.5
            particle.shadowColor = AppTheme.accentHot.cgColor
            particle.shadowRadius = 6
            particle.shadowOpacity = 1
            particle.shadowOffset = .zero
            container.addSublayer(particle)

            let travel = CAKeyframeAnimation(keyPath: "position")
            travel.path = path.cgPath
            travel.duration = 2.6
            travel.repeatCount = .infinity
            travel.beginTime = CACurrentMediaTime() + Double(i) * 0.5
            particle.add(travel, forKey: "travel")
        }
        canvas.layer.insertSublayer(container, at: 0)

        for node in nodeViews {
            node.startBreathing()
        }
    }

    private func selectNode(at index: Int) {
        SoundService.shared.playClick()
        nodeViews.forEach { $0.setSelected(false) }
        nodeViews[index].setSelected(true)
        let mode = modes[index]
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            self.delegate?.missionMap(self, didSelect: mode)
        }
    }
}

// MARK: - Nodo individual del mapa

final class MissionNodeView: UIView {
    var onTap: (() -> Void)?
    private let mode: ARIFIMode
    private let glyphLabel = UILabel()
    private let nameLabel = UILabel()

    init(mode: ARIFIMode, index: Int) {
        self.mode = mode
        super.init(frame: .zero)
        backgroundColor = AppTheme.card
        layer.cornerRadius = 46
        layer.borderWidth = 2.5
        layer.borderColor = AppTheme.hairlineStrong.cgColor
        isUserInteractionEnabled = true

        glyphLabel.text = mode.symbol
        glyphLabel.font = .systemFont(ofSize: 20)
        glyphLabel.textColor = AppTheme.primaryText
        glyphLabel.textAlignment = .center

        nameLabel.text = mode.displayName
        nameLabel.font = .systemFont(ofSize: 10.5, weight: .heavy)
        nameLabel.textColor = AppTheme.primaryText
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 1

        let stack = UIStackView(arrangedSubviews: [glyphLabel, nameLabel])
        stack.axis = .vertical
        stack.spacing = 2
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
        addGestureRecognizer(tap)

        alpha = 0
        transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
        UIView.animate(withDuration: 0.45, delay: Double(index) * 0.08, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.3, options: [.curveEaseOut]) {
            self.alpha = 1
            self.transform = .identity
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    @objc private func tapped() {
        UIView.animate(withDuration: 0.1, animations: { self.transform = CGAffineTransform(scaleX: 0.92, y: 0.92) }) { _ in
            UIView.animate(withDuration: 0.1) { self.transform = .identity }
        }
        onTap?()
    }

    func setSelected(_ selected: Bool) {
        UIView.animate(withDuration: 0.25) {
            self.layer.borderColor = (selected ? AppTheme.accent : AppTheme.hairlineStrong).cgColor
            self.layer.shadowColor = AppTheme.accent.cgColor
            self.layer.shadowOpacity = selected ? 0.4 : 0
            self.layer.shadowRadius = 20
            self.layer.shadowOffset = .zero
        }
    }

    func startBreathing() {
        let pulse = CABasicAnimation(keyPath: "shadowOpacity")
        pulse.fromValue = 0.0
        pulse.toValue = 0.18
        pulse.duration = 1.7
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.beginTime = CACurrentMediaTime() + 0.8
        layer.shadowColor = AppTheme.accent.cgColor
        layer.shadowRadius = 14
        layer.shadowOffset = .zero
        layer.add(pulse, forKey: "breathe")
    }
}

private extension ARIFIMode {
    var symbol: String {
        switch id {
        case "drag": return "◆"
        case "pecho": return "◇"
        case "body100": return "●"
        default: return "▸"
        }
    }
}
