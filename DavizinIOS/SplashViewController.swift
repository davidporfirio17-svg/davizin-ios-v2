import UIKit

// MARK: - SplashViewController — intro de marca.
// El anillo se dibuja con CAShapeLayer.strokeEnd (equivalente nativo de
// stroke-dashoffset animado en SVG que usamos en el HTML), luego aparece
// la "N" y el texto "NYXEL". Se llama antes de decidir si mostrar el
// aviso (NoticeViewController) o el login.

final class SplashViewController: UIViewController {
    var onFinished: (() -> Void)?

    private let ringLayer = CAShapeLayer()
    private let markLabel = UILabel()
    private let wordLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.background

        let ringSize: CGFloat = 84
        let ringContainer = UIView()
        ringContainer.translatesAutoresizingMaskIntoConstraints = false

        let trackLayer = CAShapeLayer()
        let path = UIBezierPath(arcCenter: CGPoint(x: ringSize / 2, y: ringSize / 2),
                                 radius: ringSize / 2 - 3,
                                 startAngle: -.pi / 2,
                                 endAngle: .pi * 1.5,
                                 clockwise: true)
        trackLayer.path = path.cgPath
        trackLayer.strokeColor = AppTheme.hairlineStrong.cgColor
        trackLayer.fillColor = UIColor.clear.cgColor
        trackLayer.lineWidth = 2.5
        trackLayer.frame = CGRect(x: 0, y: 0, width: ringSize, height: ringSize)

        ringLayer.path = path.cgPath
        ringLayer.strokeColor = AppTheme.accent.cgColor
        ringLayer.fillColor = UIColor.clear.cgColor
        ringLayer.lineWidth = 2.5
        ringLayer.lineCap = .round
        ringLayer.strokeEnd = 0
        ringLayer.frame = CGRect(x: 0, y: 0, width: ringSize, height: ringSize)
        ringLayer.shadowColor = AppTheme.accent.cgColor
        ringLayer.shadowRadius = 6
        ringLayer.shadowOpacity = 0.8
        ringLayer.shadowOffset = .zero

        ringContainer.layer.addSublayer(trackLayer)
        ringContainer.layer.addSublayer(ringLayer)

        markLabel.text = "N"
        markLabel.font = .systemFont(ofSize: 26, weight: .black)
        markLabel.textColor = AppTheme.primaryText
        markLabel.textAlignment = .center
        markLabel.alpha = 0
        markLabel.translatesAutoresizingMaskIntoConstraints = false

        wordLabel.text = "NYXEL"
        wordLabel.font = .systemFont(ofSize: 12, weight: .heavy)
        wordLabel.textColor = AppTheme.tertiaryText
        wordLabel.textAlignment = .center
        wordLabel.alpha = 0
        applyKerning(to: wordLabel, value: 5)
        wordLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(ringContainer)
        ringContainer.addSubview(markLabel)
        view.addSubview(wordLabel)

        NSLayoutConstraint.activate([
            ringContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            ringContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -14),
            ringContainer.widthAnchor.constraint(equalToConstant: ringSize),
            ringContainer.heightAnchor.constraint(equalToConstant: ringSize),

            markLabel.centerXAnchor.constraint(equalTo: ringContainer.centerXAnchor),
            markLabel.centerYAnchor.constraint(equalTo: ringContainer.centerYAnchor),

            wordLabel.topAnchor.constraint(equalTo: ringContainer.bottomAnchor, constant: 18),
            wordLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateSplash()
    }

    private func animateSplash() {
        let drawAnimation = CABasicAnimation(keyPath: "strokeEnd")
        drawAnimation.fromValue = 0
        drawAnimation.toValue = 1
        drawAnimation.duration = 1.0
        drawAnimation.timingFunction = CAMediaTimingFunction(controlPoints: 0.65, 0, 0.35, 1)
        drawAnimation.fillMode = .forwards
        drawAnimation.isRemovedOnCompletion = false
        ringLayer.add(drawAnimation, forKey: "draw")
        ringLayer.strokeEnd = 1

        UIView.animate(withDuration: 0.4, delay: 0.75, options: [.curveEaseOut]) {
            self.markLabel.alpha = 1
        }
        UIView.animate(withDuration: 0.5, delay: 1.0, options: [.curveEaseOut]) {
            self.wordLabel.alpha = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.45) { [weak self] in
            guard let self = self else { return }
            UIView.animate(withDuration: 0.5, animations: {
                self.view.alpha = 0
            }, completion: { _ in
                self.onFinished?()
            })
        }
    }

    private func applyKerning(to label: UILabel, value: CGFloat) {
        guard let text = label.text else { return }
        let attr = NSMutableAttributedString(string: text)
        attr.addAttribute(.kern, value: value, range: NSRange(location: 0, length: text.count))
        label.attributedText = attr
    }
}
