import UIKit

protocol ProfileViewDelegate: AnyObject {
    func profileViewDidTapLogout(_ view: ProfileView)
}

enum SessionStats {
    private static let key = "dz_injection_count"
    static var injectionCount: Int {
        get { UserDefaults.standard.integer(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
    static func recordInjection() { injectionCount += 1 }
}

private struct RankTier {
    let minCount: Int
    let name: String
    let color: UIColor
}

private let rankTiers = [
    RankTier(minCount: 0, name: "BRONCE", color: UIColor(red: 0.54, green: 0.43, blue: 0.29, alpha: 1)),
    RankTier(minCount: 50, name: "PLATA", color: UIColor(red: 0.72, green: 0.77, blue: 0.80, alpha: 1)),
    RankTier(minCount: 150, name: "ORO", color: UIColor(red: 0.88, green: 0.72, blue: 0.29, alpha: 1)),
    RankTier(minCount: 300, name: "DIAMANTE", color: AppTheme.accentHot)
]

private func currentRankTier(for count: Int) -> RankTier { rankTiers.last { count >= $0.minCount } ?? rankTiers[0] }

final class ProfileView: UIView {
    weak var delegate: ProfileViewDelegate?
    var onRefreshRequested: (() -> Void)?

    private let avatarCircle = UIView()
    private let avatarImageView = UIImageView()
    private let nameLabel = UILabel()
    private let rankBadge = UIView()
    private let rankLabel = UILabel()
    private let keyValueLabel = UILabel()
    private let expirationValueLabel = UILabel()
    private let accountStatusLabel = UILabel()
    private let countValueLabel = UILabel()
    private let serviceStatusLabel = UILabel()
    private let diagnosticsLabel = UILabel()
    private let activityLabel = UILabel()
    private let refreshButton = UIButton(type: .system)
    private let logoutButton = ARIFIButton(title: "CERRAR SESIÓN", style: .destructive)
    private let progressTrack = CAShapeLayer()
    private let progressRing = CAShapeLayer()
    private var activeKey: String?
    private var activeRemainingSeconds = 0
    private var initialRemainingSeconds = 0

    override init(frame: CGRect) { super.init(frame: frame); configure() }
    required init?(coder: NSCoder) { super.init(coder: coder); configure() }

    func setAccount(key: String?, remainingSeconds: Int) {
        let previousKey = activeKey
        activeKey = key
        activeRemainingSeconds = max(0, remainingSeconds)
        if key != previousKey { initialRemainingSeconds = max(remainingSeconds, 1) }
        if initialRemainingSeconds == 0 { initialRemainingSeconds = max(remainingSeconds, 1) }
        refresh()
    }

    func refresh() {
        let count = SessionStats.injectionCount
        let tier = currentRankTier(for: count)
        rankLabel.text = "◆ \(tier.name)"
        rankLabel.textColor = tier.color
        rankBadge.layer.borderColor = tier.color.withAlphaComponent(0.5).cgColor
        rankBadge.backgroundColor = tier.color.withAlphaComponent(0.12)
        keyValueLabel.text = maskedKey(activeKey)
        accountStatusLabel.text = activeKey == nil ? "Sin validar" : (activeRemainingSeconds > 0 ? "Activa" : "Expirada")
        accountStatusLabel.textColor = activeRemainingSeconds > 0 ? AppTheme.success : AppTheme.failure
        expirationValueLabel.text = formattedRemaining(activeRemainingSeconds)
        countValueLabel.text = "\(count)"
        serviceStatusLabel.text = "●  \(NyxelRemoteConfigStore.status)"
        serviceStatusLabel.textColor = NyxelRemoteConfigStore.status == "Configuración válida" ? AppTheme.success : AppTheme.warm
        diagnosticsLabel.text = diagnosticText()
        let formatter = DateFormatter(); formatter.dateFormat = "HH:mm:ss"
        activityLabel.text = "Última actividad  •  Perfil consultado a las \(formatter.string(from: Date()))"
        updateProgressRing()
    }

    private func configure() {
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false

        avatarCircle.backgroundColor = AppTheme.card
        avatarCircle.layer.cornerRadius = 31
        avatarCircle.layer.borderWidth = 2
        avatarCircle.layer.borderColor = AppTheme.accent.cgColor
        avatarCircle.layer.shadowColor = AppTheme.accent.cgColor
        avatarCircle.layer.shadowOpacity = 0.3
        avatarCircle.layer.shadowRadius = 14
        avatarCircle.clipsToBounds = true
        avatarCircle.translatesAutoresizingMaskIntoConstraints = false

        avatarImageView.image = UIImage(named: "NyxelAvatar")
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.clipsToBounds = true
        avatarImageView.translatesAutoresizingMaskIntoConstraints = false
        avatarCircle.addSubview(avatarImageView)
        progressTrack.fillColor = UIColor.clear.cgColor
        progressTrack.strokeColor = AppTheme.hairlineStrong.cgColor
        progressTrack.lineWidth = 3
        progressRing.fillColor = UIColor.clear.cgColor
        progressRing.strokeColor = AppTheme.accent.cgColor
        progressRing.lineWidth = 3
        progressRing.lineCap = .round
        avatarImageView.layer.addSublayer(progressTrack)
        avatarImageView.layer.addSublayer(progressRing)

        nameLabel.text = "CUENTA ACTIVA"
        nameLabel.font = AppTheme.titleFont(19)
        nameLabel.textColor = AppTheme.primaryText
        rankLabel.font = .systemFont(ofSize: 10, weight: .heavy)
        rankLabel.translatesAutoresizingMaskIntoConstraints = false
        rankBadge.layer.cornerRadius = 100
        rankBadge.layer.borderWidth = 1
        rankBadge.translatesAutoresizingMaskIntoConstraints = false
        rankBadge.addSubview(rankLabel)

        let nameStack = UIStackView(arrangedSubviews: [nameLabel, rankBadge])
        nameStack.axis = .vertical; nameStack.alignment = .leading; nameStack.spacing = 6
        let heroStack = UIStackView(arrangedSubviews: [avatarCircle, nameStack])
        heroStack.axis = .horizontal; heroStack.alignment = .center; heroStack.spacing = 16
        heroStack.translatesAutoresizingMaskIntoConstraints = false

        let sectionTitle = UILabel()
        sectionTitle.text = "CUENTA"
        sectionTitle.font = .systemFont(ofSize: 10, weight: .heavy)
        sectionTitle.textColor = AppTheme.accent

        let keyRow = makeRow(label: "Key", valueLabel: keyValueLabel)
        let statusRow = makeRow(label: "Estado", valueLabel: accountStatusLabel)
        let expirationRow = makeRow(label: "Expira en", valueLabel: expirationValueLabel)
        let countRow = makeRow(label: "Inyecciones totales", valueLabel: countValueLabel)

        serviceStatusLabel.font = AppTheme.monoFont(11)
        diagnosticsLabel.font = UIFont.monospacedSystemFont(ofSize: 10, weight: .medium)
        diagnosticsLabel.textColor = AppTheme.secondaryText
        diagnosticsLabel.numberOfLines = 0
        activityLabel.font = .systemFont(ofSize: 10, weight: .medium)
        activityLabel.textColor = AppTheme.tertiaryText
        activityLabel.numberOfLines = 0

        refreshButton.setTitle("↻  ACTUALIZAR DATOS", for: .normal)
        refreshButton.setTitleColor(AppTheme.accent, for: .normal)
        refreshButton.titleLabel?.font = .systemFont(ofSize: 11, weight: .heavy)
        refreshButton.backgroundColor = AppTheme.accentDim
        refreshButton.layer.cornerRadius = 10
        refreshButton.layer.borderWidth = 1
        refreshButton.layer.borderColor = AppTheme.accent.withAlphaComponent(0.35).cgColor
        refreshButton.heightAnchor.constraint(equalToConstant: 38).isActive = true

        let card = ARIFICardView()
        let stack = UIStackView(arrangedSubviews: [heroStack, sectionTitle, keyRow, statusRow, expirationRow, countRow, serviceStatusLabel, diagnosticsLabel, refreshButton, activityLabel, logoutButton])
        stack.axis = .vertical; stack.spacing = 13
        stack.setCustomSpacing(22, after: heroStack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.translatesAutoresizingMaskIntoConstraints = false
        card.addContent(stack)
        addSubview(card)

        refreshButton.addTarget(self, action: #selector(refreshTapped), for: .touchUpInside)
        logoutButton.addTarget(self, action: #selector(logoutTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            avatarCircle.widthAnchor.constraint(equalToConstant: 62), avatarCircle.heightAnchor.constraint(equalToConstant: 62),
            avatarImageView.leadingAnchor.constraint(equalTo: avatarCircle.leadingAnchor), avatarImageView.trailingAnchor.constraint(equalTo: avatarCircle.trailingAnchor),
            avatarImageView.topAnchor.constraint(equalTo: avatarCircle.topAnchor), avatarImageView.bottomAnchor.constraint(equalTo: avatarCircle.bottomAnchor),
            rankBadge.heightAnchor.constraint(equalToConstant: 22), rankLabel.leadingAnchor.constraint(equalTo: rankBadge.leadingAnchor, constant: 10),
            rankLabel.trailingAnchor.constraint(equalTo: rankBadge.trailingAnchor, constant: -10), rankLabel.centerYAnchor.constraint(equalTo: rankBadge.centerYAnchor),
            card.centerXAnchor.constraint(equalTo: centerXAnchor), card.centerYAnchor.constraint(equalTo: centerYAnchor),
            card.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 22), card.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -22),
            card.widthAnchor.constraint(lessThanOrEqualToConstant: AppTheme.contentMaximumWidth), stack.widthAnchor.constraint(greaterThanOrEqualToConstant: 240),
            logoutButton.heightAnchor.constraint(equalToConstant: AppTheme.controlHeight)
        ])
        refresh()
    }

    private func makeRow(label: String, valueLabel: UILabel) -> UIView {
        let left = UILabel(); left.text = label; left.font = .systemFont(ofSize: 13, weight: .medium); left.textColor = AppTheme.secondaryText
        valueLabel.font = AppTheme.monoFont(13); valueLabel.textColor = AppTheme.accentHot; valueLabel.textAlignment = .right
        let row = UIStackView(arrangedSubviews: [left, valueLabel]); row.axis = .horizontal; row.distribution = .equalSpacing
        return row
    }

    @objc private func refreshTapped() {
        refreshButton.isEnabled = false
        refreshButton.setTitle("↻  ACTUALIZANDO...", for: .normal)
        onRefreshRequested?()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.refreshButton.isEnabled = true
            self?.refreshButton.setTitle("↻  ACTUALIZAR DATOS", for: .normal)
            self?.refresh()
        }
    }

    @objc private func logoutTapped() { SoundService.shared.playClick(); delegate?.profileViewDidTapLogout(self) }

    private func maskedKey(_ key: String?) -> String {
        guard let key, !key.isEmpty else { return "—" }
        let value = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.count > 8 else { return String(repeating: "•", count: value.count) }
        return "\(value.prefix(4))••••\(value.suffix(4))"
    }

    private func formattedRemaining(_ seconds: Int) -> String {
        guard seconds > 0 else { return activeKey == nil ? "—" : "Expirada" }
        let d = seconds / 86400; let h = (seconds % 86400) / 3600; let m = (seconds % 3600) / 60; let s = seconds % 60
        if d > 0 { return String(format: "%dd %02dh %02dm", d, h, m) }
        return String(format: "%02dh %02dm %02ds", h, m, s)
    }

    private func diagnosticText() -> String {
        let system = NyxelSupportPolicy.currentSystemDescription
        let compatibility = NyxelSupportPolicy.isCurrentSystemSupported ? "Compatible" : "No compatible"
        let formatter = DateFormatter(); formatter.dateFormat = "HH:mm:ss"
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        return "Sistema: \(system)\nCompatibilidad: \(compatibility)\nHora local: \(formatter.string(from: Date()))\nNyxel: v\(version)\nConfiguración: \(NyxelRemoteConfigStore.status) (\(NyxelRemoteConfigStore.ageDescription))"
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let rect = avatarImageView.bounds.insetBy(dx: 5, dy: 5)
        let path = UIBezierPath(ovalIn: rect).cgPath
        progressTrack.frame = avatarImageView.bounds; progressRing.frame = avatarImageView.bounds
        progressTrack.path = path; progressRing.path = path
        updateProgressRing()
    }

    private func updateProgressRing() {
        let progress = initialRemainingSeconds > 0 ? max(0, min(1, CGFloat(activeRemainingSeconds) / CGFloat(initialRemainingSeconds))) : 0
        progressRing.strokeEnd = progress
        progressRing.strokeColor = activeRemainingSeconds <= 3600 ? AppTheme.failure.cgColor : AppTheme.accent.cgColor
    }
}
