import UIKit
import AVFoundation

final class DavizinCardView: UIView {
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let contentView = UIView()
    private let glassHighlight = CAGradientLayer()
    private var backgroundVideoPlayer: AVQueuePlayer?
    private var backgroundVideoLooper: AVPlayerLooper?
    private let backgroundVideoLayer = AVPlayerLayer()
    private let backgroundVideoOverlay = CALayer()
    private var contentConstraints: [NSLayoutConstraint] = []

    var contentInsets: UIEdgeInsets = UIEdgeInsets(
        top: AppTheme.cardPadding,
        left: AppTheme.cardPadding,
        bottom: AppTheme.cardPadding,
        right: AppTheme.cardPadding
    ) {
        didSet { updateContentConstraints() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: AppTheme.cardCornerRadius).cgPath
        glassHighlight.frame = bounds
        backgroundVideoLayer.frame = bounds
        backgroundVideoLayer.cornerRadius = AppTheme.cardCornerRadius
        backgroundVideoOverlay.frame = bounds
        backgroundVideoOverlay.cornerRadius = AppTheme.cardCornerRadius
    }

    func addContent(_ view: UIView) {
        contentView.addSubview(view)
        view.davizinPinEdges(to: contentView)
        updateContentConstraints()
    }

    /// Coloca un video silencioso en loop detrás de todo el contenido de la tarjeta.
    func setBackgroundVideo(resourceName: String) {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "mp4") else { return }
        let player = AVQueuePlayer()
        backgroundVideoLooper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        backgroundVideoPlayer = player
        backgroundVideoLayer.player = player
        backgroundVideoLayer.videoGravity = .resizeAspectFill
        backgroundVideoLayer.masksToBounds = true
        backgroundVideoOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.08).cgColor
        if backgroundVideoLayer.superlayer == nil {
            layer.insertSublayer(backgroundVideoLayer, at: 0)
            layer.insertSublayer(backgroundVideoOverlay, above: backgroundVideoLayer)
        }
        blurView.alpha = 0.34
        player.isMuted = true
        player.play()
    }

    func useTransparentAppearance() {
        backgroundColor = .clear
        blurView.alpha = 0.30
        layer.borderColor = UIColor.white.withAlphaComponent(0.30).cgColor
        layer.shadowColor = AppTheme.accent.cgColor
        layer.shadowOpacity = 0.18
        layer.shadowRadius = 32.0
        layer.shadowOffset = CGSize(width: 0.0, height: 14.0)
        glassHighlight.colors = [
            UIColor.white.withAlphaComponent(0.18).cgColor,
            UIColor.white.withAlphaComponent(0.035).cgColor,
            UIColor.clear.cgColor
        ]
        glassHighlight.locations = [0.0, 0.14, 0.46]
        glassHighlight.startPoint = CGPoint(x: 0.5, y: 0.0)
        glassHighlight.endPoint = CGPoint(x: 0.5, y: 1.0)
        glassHighlight.cornerRadius = AppTheme.cardCornerRadius
        glassHighlight.masksToBounds = true
        layer.insertSublayer(glassHighlight, at: 0)
    }

    private func configure() {
        backgroundColor = AppTheme.card
        layer.cornerRadius = AppTheme.cardCornerRadius
        layer.cornerCurve = .continuous
        layer.masksToBounds = false
        layer.borderWidth = 1.0
        layer.borderColor = UIColor.white.withAlphaComponent(0.18).cgColor
        layer.shadowColor = AppTheme.accentWarm.cgColor
        layer.shadowOpacity = 0.28
        layer.shadowRadius = 28.0
        layer.shadowOffset = CGSize(width: 0.0, height: 16.0)

        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.layer.cornerRadius = AppTheme.cardCornerRadius
        blurView.layer.cornerCurve = .continuous
        blurView.clipsToBounds = true
        blurView.alpha = 0.72
        addSubview(blurView)
        blurView.davizinPinEdges(to: self)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentView)
        updateContentConstraints()
    }

    private func updateContentConstraints() {
        guard contentView.superview != nil else { return }
        NSLayoutConstraint.deactivate(contentConstraints)
        contentConstraints = [
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: contentInsets.left),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -contentInsets.right),
            contentView.topAnchor.constraint(equalTo: topAnchor, constant: contentInsets.top),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -contentInsets.bottom)
        ]
        NSLayoutConstraint.activate(contentConstraints)
    }
}
