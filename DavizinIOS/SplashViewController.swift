import UIKit
import AVFoundation

// MARK: - SplashViewController — bienvenida audiovisual de Nyxel External.
final class SplashViewController: UIViewController {
    var onFinished: (() -> Void)?

    private let portraitView = UIImageView()
    private let wordLabel = UILabel()
    private let captionLabel = UILabel()
    private let progressLayer = CAShapeLayer()
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var endObserver: NSObjectProtocol?
    private var failureObserver: NSObjectProtocol?
    private var previousAudioSession: (category: AVAudioSession.Category, mode: AVAudioSession.Mode, options: AVAudioSession.CategoryOptions)?
    private var videoIsActive = false
    private var fallbackHasStarted = false
    private var didFinish = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.012, green: 0.018, blue: 0.055, alpha: 1)
        view.isAccessibilityElement = true
        view.accessibilityLabel = "Bienvenido a Nyxel External. Iniciando la aplicación."
        configureFallbackBranding()
        installWelcomeVideo()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = view.bounds
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if videoIsActive {
            player?.play()
        } else {
            animateFallbackSplash()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        player?.pause()
    }

    deinit {
        player?.pause()
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        if let failureObserver { NotificationCenter.default.removeObserver(failureObserver) }
    }

    private func configureFallbackBranding() {
        portraitView.image = UIImage(named: "NyxelAvatar")
        portraitView.contentMode = .scaleAspectFill
        portraitView.clipsToBounds = true
        portraitView.layer.cornerRadius = 76
        portraitView.layer.cornerCurve = .continuous
        portraitView.layer.borderWidth = 1.0
        portraitView.layer.borderColor = AppTheme.accent.withAlphaComponent(0.48).cgColor
        portraitView.layer.shadowColor = AppTheme.accent.cgColor
        portraitView.layer.shadowRadius = 24
        portraitView.layer.shadowOpacity = 0.30
        portraitView.layer.shadowOffset = .zero
        portraitView.alpha = 0
        portraitView.transform = CGAffineTransform(scaleX: 0.90, y: 0.90)
        portraitView.translatesAutoresizingMaskIntoConstraints = false

        wordLabel.text = "NYXEL EXTERNAL"
        wordLabel.font = .systemFont(ofSize: 15, weight: .bold)
        wordLabel.textColor = AppTheme.primaryText
        wordLabel.textAlignment = .center
        wordLabel.alpha = 0
        applyKerning(to: wordLabel, value: 2.4)
        wordLabel.translatesAutoresizingMaskIntoConstraints = false

        captionLabel.text = "SECURE OPERATIONS"
        captionLabel.font = AppTheme.captionFont()
        captionLabel.textColor = AppTheme.tertiaryText
        captionLabel.textAlignment = .center
        captionLabel.alpha = 0
        applyKerning(to: captionLabel, value: 1.6)
        captionLabel.translatesAutoresizingMaskIntoConstraints = false

        let track = CAShapeLayer()
        let ringRect = CGRect(x: 0, y: 0, width: 164, height: 164)
        let path = UIBezierPath(ovalIn: ringRect.insetBy(dx: 4, dy: 4))
        track.path = path.cgPath
        track.frame = ringRect
        track.strokeColor = AppTheme.hairlineStrong.cgColor
        track.fillColor = UIColor.clear.cgColor
        track.lineWidth = 2

        progressLayer.path = path.cgPath
        progressLayer.frame = ringRect
        progressLayer.strokeColor = AppTheme.accent.cgColor
        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.lineWidth = 2
        progressLayer.lineCap = .round
        progressLayer.strokeEnd = 0
        portraitView.layer.addSublayer(track)
        portraitView.layer.addSublayer(progressLayer)

        view.addSubview(portraitView)
        view.addSubview(wordLabel)
        view.addSubview(captionLabel)

        NSLayoutConstraint.activate([
            portraitView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            portraitView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -34),
            portraitView.widthAnchor.constraint(equalToConstant: 152),
            portraitView.heightAnchor.constraint(equalToConstant: 152),
            wordLabel.topAnchor.constraint(equalTo: portraitView.bottomAnchor, constant: 28),
            wordLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captionLabel.topAnchor.constraint(equalTo: wordLabel.bottomAnchor, constant: 8),
            captionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    private func installWelcomeVideo() {
        guard let url = Bundle.main.url(forResource: "nyxel_welcome", withExtension: "mp4") else { return }
        activateWelcomeAudio()
        let item = AVPlayerItem(url: url)
        let welcomePlayer = AVPlayer(playerItem: item)
        welcomePlayer.volume = 0.70
        welcomePlayer.isMuted = false
        player = welcomePlayer

        let layer = AVPlayerLayer(player: welcomePlayer)
        layer.frame = view.bounds
        layer.backgroundColor = view.backgroundColor?.cgColor
        // El video es vertical: llena iPhone y conserva todos los textos en iPad.
        layer.videoGravity = UIDevice.current.userInterfaceIdiom == .pad ? .resizeAspect : .resizeAspectFill
        playerLayer = layer
        view.layer.insertSublayer(layer, at: 0)
        portraitView.isHidden = true
        wordLabel.isHidden = true
        captionLabel.isHidden = true
        videoIsActive = true

        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.finishSplash()
        }
        failureObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.failedToPlayToEndTimeNotification,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.showFallbackSplash()
        }
    }

    private func showFallbackSplash() {
        guard !didFinish else { return }
        videoIsActive = false
        player?.pause()
        restoreAudioSession()
        playerLayer?.isHidden = true
        portraitView.isHidden = false
        wordLabel.isHidden = false
        captionLabel.isHidden = false
        animateFallbackSplash()
    }

    private func animateFallbackSplash() {
        guard !fallbackHasStarted else { return }
        fallbackHasStarted = true

        let draw = CABasicAnimation(keyPath: "strokeEnd")
        draw.fromValue = 0
        draw.toValue = 1
        draw.duration = 0.85
        draw.timingFunction = CAMediaTimingFunction(name: .easeOut)
        progressLayer.add(draw, forKey: "draw")
        progressLayer.strokeEnd = 1

        UIView.animate(withDuration: 0.60, delay: 0.12, options: [.curveEaseOut]) {
            self.portraitView.alpha = 1
            self.portraitView.transform = .identity
        }
        UIView.animate(withDuration: 0.42, delay: 0.60, options: [.curveEaseOut]) {
            self.wordLabel.alpha = 1
            self.captionLabel.alpha = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.45) { [weak self] in
            self?.finishSplash()
        }
    }

    private func finishSplash() {
        guard !didFinish else { return }
        didFinish = true
        player?.pause()
        restoreAudioSession()
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        if let failureObserver { NotificationCenter.default.removeObserver(failureObserver) }
        endObserver = nil
        failureObserver = nil
        UIView.animate(withDuration: 0.36, animations: {
            self.view.alpha = 0
        }, completion: { _ in
            self.onFinished?()
        })
    }

    private func activateWelcomeAudio() {
        let session = AVAudioSession.sharedInstance()
        previousAudioSession = (session.category, session.mode, session.categoryOptions)
        try? session.setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    private func restoreAudioSession() {
        guard let previousAudioSession else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(previousAudioSession.category, mode: previousAudioSession.mode, options: previousAudioSession.options)
        try? session.setActive(true)
        self.previousAudioSession = nil
    }

    private func applyKerning(to label: UILabel, value: CGFloat) {
        guard let text = label.text else { return }
        let attr = NSMutableAttributedString(string: text)
        attr.addAttribute(.kern, value: value, range: NSRange(location: 0, length: text.count))
        label.attributedText = attr
    }
}
