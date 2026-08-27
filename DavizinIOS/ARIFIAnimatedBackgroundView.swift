import UIKit

final class ARIFIAnimatedBackgroundView: UIView {
    private struct Node {
        let point: CGPoint
        let phase: CGFloat
    }

    private var nodes: [Node] = []
    private var dotLayers: [CAShapeLayer] = []
    private var lineLayers: [CAShapeLayer] = []
    private var displayLink: CADisplayLink?
    private var elapsed: CGFloat = 0.0
    private var builtSize: CGSize = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    deinit {
        displayLink?.invalidate()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.size != builtSize, bounds.width > 0.0, bounds.height > 0.0 else { return }
        rebuildNetwork()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            stopAnimating()
        } else {
            startAnimating()
        }
    }

    func startAnimating() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(animationTick(_:)))
        link.preferredFramesPerSecond = 30
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stopAnimating() {
        displayLink?.invalidate()
        displayLink = nil
    }

    private func configure() {
        backgroundColor = AppTheme.background
        isUserInteractionEnabled = false
        clipsToBounds = true
    }

    private func rebuildNetwork() {
        builtSize = bounds.size
        dotLayers.forEach { $0.removeFromSuperlayer() }
        lineLayers.forEach { $0.removeFromSuperlayer() }
        dotLayers.removeAll()
        lineLayers.removeAll()
        nodes.removeAll()

        let columns = max(4, Int(bounds.width / 58.0))
        let rows = max(7, Int(bounds.height / 78.0))
        let horizontalStep = bounds.width / CGFloat(columns)
        let verticalStep = bounds.height / CGFloat(rows)

        for row in 0..<rows {
            for column in 0..<columns {
                let index = row * columns + column
                let xJitter = CGFloat(sin(Double(index * 17))) * horizontalStep * 0.24
                let yJitter = CGFloat(cos(Double(index * 11))) * verticalStep * 0.22
                let point = CGPoint(
                    x: (CGFloat(column) + 0.5) * horizontalStep + xJitter,
                    y: (CGFloat(row) + 0.5) * verticalStep + yJitter
                )
                let phase = CGFloat(index) * 0.61
                nodes.append(Node(point: point, phase: phase))
            }
        }

        for firstIndex in nodes.indices {
            for secondIndex in nodes.indices where secondIndex > firstIndex {
                let first = nodes[firstIndex].point
                let second = nodes[secondIndex].point
                let distance = hypot(first.x - second.x, first.y - second.y)
                let maxDistance = max(horizontalStep, verticalStep) * 1.55
                guard distance < maxDistance else { continue }
                addLine(from: first, to: second)
            }
        }

        for node in nodes {
            addDot(at: node.point)
        }
    }

    private func addLine(from start: CGPoint, to end: CGPoint) {
        let line = CAShapeLayer()
        let path = UIBezierPath()
        path.move(to: start)
        path.addLine(to: end)
        line.path = path.cgPath
        line.strokeColor = UIColor.white.withAlphaComponent(0.075).cgColor
        line.fillColor = UIColor.clear.cgColor
        line.lineWidth = 0.65
        line.lineCap = .round
        layer.addSublayer(line)
        lineLayers.append(line)
    }

    private func addDot(at point: CGPoint) {
        let dot = CAShapeLayer()
        let radius: CGFloat = 1.2
        dot.path = UIBezierPath(
            ovalIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2.0, height: radius * 2.0)
        ).cgPath
        dot.fillColor = UIColor.white.withAlphaComponent(0.18).cgColor
        layer.addSublayer(dot)
        dotLayers.append(dot)
    }

    @objc private func animationTick(_ link: CADisplayLink) {
        elapsed += CGFloat(link.duration)
        for (index, dot) in dotLayers.enumerated() {
            let pulse = (sin(elapsed * 1.2 + CGFloat(index) * 0.47) + 1.0) * 0.5
            dot.opacity = Float(0.20 + pulse * 0.45)
            let scale = 0.82 + pulse * 0.32
            dot.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
        }

        for (index, line) in lineLayers.enumerated() {
            let pulse = (sin(elapsed * 0.75 + CGFloat(index) * 0.19) + 1.0) * 0.5
            line.opacity = Float(0.32 + pulse * 0.5)
        }
    }
}
