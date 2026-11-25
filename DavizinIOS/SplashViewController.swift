import UIKit
import AVFoundation
import WebKit

// Envoltura débil para el handler de mensajes de la intro (evita ciclo de retención).
private final class SplashWeakScriptHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ t: WKScriptMessageHandler) { target = t }
    func userContentController(_ u: WKUserContentController, didReceive m: WKScriptMessage) {
        target?.userContentController(u, didReceive: m)
    }
}

// MARK: - SplashViewController — bienvenida audiovisual de Nyxel External.
final class SplashViewController: UIViewController, WKScriptMessageHandler {
    var onFinished: (() -> Void)?
    private var introWebView: WKWebView?
    private var introActive = false

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
        if !installParticleIntro() {
            installWelcomeVideo()
        }
    }

    /// Intro de partículas (NYXEL → manzanita mordida) en un WKWebView.
    /// Devuelve false si no se puede montar (entonces se usa el video/estático).
    private func installParticleIntro() -> Bool {
        guard NyxelAppearanceStore.animationsEnabled,
              let url = Bundle.main.url(forResource: "nyxel_intro", withExtension: "html") else { return false }
        let cfg = WKWebViewConfiguration()
        let ucc = WKUserContentController()
        ucc.add(SplashWeakScriptHandler(self), name: "intro")
        cfg.userContentController = ucc
        let wv = WKWebView(frame: view.bounds, configuration: cfg)
        wv.isOpaque = false
        wv.backgroundColor = UIColor(red: 0.019, green: 0.023, blue: 0.051, alpha: 1)
        wv.scrollView.isScrollEnabled = false
        wv.scrollView.bounces = false
        wv.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(wv)
        NSLayoutConstraint.activate([
            wv.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            wv.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            wv.topAnchor.constraint(equalTo: view.topAnchor),
            wv.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        wv.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        introWebView = wv
        introActive = true
        portraitView.isHidden = true
        wordLabel.isHidden = true
        captionLabel.isHidden = true
        // Seguro: si el webview nunca avisa, termina solo.
        DispatchQueue.main.asyncAfter(deadline: .now() + 7.0) { [weak self] in
            self?.finishSplash()
        }
        return true
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = view.bounds
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if videoIsActive {
            player?.play()
        } else if introActive {
            // La intro de partículas se controla sola (avisa por 'intro' o por el seguro).
        } else if !didFinish {
            animateFallbackSplash()
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "intro" { finishSplash() }
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
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        let avatarSize: CGFloat = isIPad ? 110 : 120
        let avatarRadius: CGFloat = avatarSize / 2

        portraitView.image = UIImage(named: "NyxelAvatar")
        portraitView.contentMode = .scaleAspectFill
        portraitView.clipsToBounds = true
        portraitView.layer.cornerRadius = avatarRadius
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
        wordLabel.font = .systemFont(ofSize: isIPad ? 13 : 15, weight: .bold)
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
        let ringRect = CGRect(x: 0, y: 0, width: avatarSize, height: avatarSize)
        let path = UIBezierPath(ovalIn: ringRect.insetBy(dx: 2, dy: 2))
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
            portraitView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: isIPad ? -28 : -34),
            portraitView.widthAnchor.constraint(equalToConstant: avatarSize),
            portraitView.heightAnchor.constraint(equalToConstant: avatarSize),
            wordLabel.topAnchor.constraint(equalTo: portraitView.bottomAnchor, constant: 22),
            wordLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captionLabel.topAnchor.constraint(equalTo: wordLabel.bottomAnchor, constant: 8),
            captionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    private func installWelcomeVideo() {
        guard NyxelAppearanceStore.animationsEnabled,
              let url = EmbeddedResources.shared.url(for: .splashVideo) else {
            showStaticSplash()
            return
        }
        activateWelcomeAudio()
        let item = AVPlayerItem(url: url)
        let welcomePlayer = AVPlayer(playerItem: item)
        welcomePlayer.volume = 0.70
        welcomePlayer.isMuted = false
        player = welcomePlayer

        let layer = AVPlayerLayer(player: welcomePlayer)
        layer.frame = view.bounds
        layer.backgroundColor = view.backgroundColor?.cgColor
        layer.videoGravity = .resizeAspectFill
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

    private func showStaticSplash() {
        portraitView.isHidden = false
        wordLabel.isHidden = false
        captionLabel.isHidden = false
        portraitView.alpha = 1
        portraitView.transform = .identity
        wordLabel.alpha = 1
        captionLabel.alpha = 1
        progressLayer.strokeEnd = 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.finishSplash()
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
