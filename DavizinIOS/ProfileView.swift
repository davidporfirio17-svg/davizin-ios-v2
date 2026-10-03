import UIKit

protocol ProfileViewDelegate: AnyObject {
    func profileViewDidTapLogout(_ view: ProfileView)
}

enum ProfileMediaTarget: Equatable {
    case avatar
    case cover
}

private enum ProfileMediaStore {
    private static func url(for name: String) -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(name)
    }

    static func load(_ name: String) -> UIImage? {
        guard let url = url(for: name), let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    static func save(_ image: UIImage, as name: String) {
        guard let data = image.jpegData(compressionQuality: 0.9), let url = url(for: name) else { return }
        try? data.write(to: url, options: .atomic)
    }
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

private final class ProfileDisclosureSection: UIView {
    private let titleLabel = UILabel()
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.down"))
    private let bodyStack = UIStackView()
    private var collapsedHeightConstraint: NSLayoutConstraint?
    private var expanded = true

    init(title: String, views: [UIView], expanded: Bool = true) {
        self.expanded = expanded
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 12
        layer.borderWidth = 1
        layer.borderColor = AppTheme.hairline.cgColor
        backgroundColor = UIColor.white.withAlphaComponent(0.035)

        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        titleLabel.textColor = AppTheme.accent
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        chevron.tintColor = AppTheme.tertiaryText
        chevron.translatesAutoresizingMaskIntoConstraints = false

        let header = UIButton(type: .system)
        header.accessibilityLabel = "Sección \(title.lowercased())"
        header.addTarget(self, action: #selector(toggle), for: .touchUpInside)
        header.translatesAutoresizingMaskIntoConstraints = false
        addSubview(header)
        addSubview(titleLabel)
        addSubview(chevron)

        bodyStack.axis = .vertical
        bodyStack.spacing = 11
        bodyStack.translatesAutoresizingMaskIntoConstraints = false
        views.forEach { bodyStack.addArrangedSubview($0) }
        addSubview(bodyStack)

        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: leadingAnchor), header.trailingAnchor.constraint(equalTo: trailingAnchor),
            header.topAnchor.constraint(equalTo: topAnchor), header.heightAnchor.constraint(equalToConstant: 38),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14), titleLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            chevron.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14), chevron.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            bodyStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14), bodyStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            bodyStack.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 2), bodyStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14)
        ])
        collapsedHeightConstraint = bodyStack.heightAnchor.constraint(equalToConstant: 0)
        applyExpandedState(animated: false)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func toggle() {
        expanded.toggle()
        applyExpandedState(animated: true)
    }

    private func applyExpandedState(animated: Bool) {
        let updates = {
            self.bodyStack.isHidden = !self.expanded
            self.collapsedHeightConstraint?.isActive = !self.expanded
            self.chevron.transform = self.expanded ? .identity : CGAffineTransform(rotationAngle: -.pi / 2)
        }
        if animated { UIView.animate(withDuration: 0.2, animations: updates) } else { updates() }
    }
}

final class ProfileView: UIView {
    weak var delegate: ProfileViewDelegate?
    var onRefreshRequested: (() -> Void)?
    var onAppearanceChanged: (() -> Void)?
    var onEditProfileRequested: (() -> Void)?
    var onRequestMedia: ((ProfileMediaTarget) -> Void)?
    var onSearchRequested: ((String) -> Void)?

    private let socialHeader = UIView()
    private let sceneBackgroundView = UIImageView()
    private let sceneShade = CAGradientLayer()
    private let commandTitleLabel = UILabel()
    private let commandSubtitleLabel = UILabel()
    private let coverView = UIView()
    private let coverGradient = CAGradientLayer()
    private let coverImageView = UIImageView()
    private let coverBrandLabel = UILabel()
    private let coverStatusLabel = UILabel()
    private let avatarCircle = UIView()
    private let avatarImageView = UIImageView()
    private let nameLabel = UILabel()
    private let usernameLabel = UILabel()
    private let profileMetaLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let aboutUsernameLabel = UILabel()
    private let aboutBioLabel = UILabel()
    private let aboutCountryLabel = UILabel()
    private let publicSearchField = UITextField()
    private let publicSearchButton = UIButton(type: .system)
    private let publicSearchResultLabel = UILabel()
    private let profileTabs = UISegmentedControl(items: ["PERFIL", "ACTIVIDAD", "INFORMACIÓN"])
    private let headMetricLabel = UILabel()
    private let neckMetricLabel = UILabel()
    private let chestMetricLabel = UILabel()
    private let mostUsedModeLabel = UILabel()
    private let showCountrySwitch = UISwitch()
    private let showLastSeenSwitch = UISwitch()
    private let showStatsSwitch = UISwitch()
    private var tabViews: [UIView] = []
    private let editProfileButton = UIButton(type: .system)
    private let avatarEditButton = UIButton(type: .system)
    private let coverEditButton = UIButton(type: .system)
    private let rankBadge = UIView()
    private let rankLabel = UILabel()
    private let keyValueLabel = UILabel()
    private let countryValueLabel = UILabel()
    private let expirationValueLabel = UILabel()
    private let accountStatusLabel = UILabel()
    private let countValueLabel = UILabel()
    private let serviceStatusLabel = UILabel()
    private let diagnosticsLabel = UILabel()
    private let activityLabel = UILabel()
    private let gamesLabel = UILabel()
    private let historyLabel = UILabel()
    private let deviceLabel = UILabel()
    private let rankProgressLabel = UILabel()
    private let appearanceControl = UISegmentedControl(items: ["Cian", "Fuego", "Violeta"])
    private let biometricSwitch = UISwitch()
    private let activationVoiceSwitch = UISwitch()
    private let refreshButton = UIButton(type: .system)
    private let logoutButton = DavizinButton(title: "CERRAR SESIÓN", style: .destructive)
    private let scrollView = UIScrollView()
    private let progressTrack = CAShapeLayer()
    private let progressRing = CAShapeLayer()
    private var activeKey: String?
    private var activeCountryCode: String?
    private var activeRemainingSeconds = 0
    private var initialRemainingSeconds = 0
    private var usernameLocked = UserDefaults.standard.bool(forKey: "nyxel.profile.username.locked")

    var isUsernameLocked: Bool { usernameLocked }

    override init(frame: CGRect) { super.init(frame: frame); configure() }
    required init?(coder: NSCoder) { super.init(coder: coder); configure() }

    func setAccount(key: String?, remainingSeconds: Int, countryCode: String? = nil) {
        let previousKey = activeKey
        activeKey = key
        if countryCode != nil { activeCountryCode = countryCode }
        if key == nil { activeCountryCode = nil }
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
        countryValueLabel.text = countryName(for: activeCountryCode)
        aboutUsernameLabel.text = usernameLabel.text ?? "@nyxel_user"
        aboutBioLabel.text = descriptionLabel.text ?? "Sin descripción todavía."
        aboutCountryLabel.text = countryName(for: activeCountryCode)
        let presence = activeKey != nil && activeRemainingSeconds > 0 ? "ACTIVO" : "SIN SESIÓN"
        profileMetaLabel.text = "●  \(presence)   ·   \(countryName(for: activeCountryCode))"
        profileMetaLabel.textColor = presence == "ACTIVO" ? AppTheme.success : AppTheme.tertiaryText
        accountStatusLabel.text = activeKey == nil ? "Sin validar" : (activeRemainingSeconds > 0 ? "Activa" : "Expirada")
        accountStatusLabel.textColor = activeRemainingSeconds > 0 ? AppTheme.success : AppTheme.failure
        expirationValueLabel.text = formattedRemaining(activeRemainingSeconds)
        countValueLabel.text = "\(count)"
        let next = rankTiers.first(where: { $0.minCount > count })?.minCount
        rankProgressLabel.text = next.map { "Progreso de rango: \(count)/\($0)" } ?? "Progreso de rango: máximo alcanzado"
        deviceLabel.text = "NYXEL EXTERNAL\n\(KeyValidator.getDeviceModel()) • \(NyxelSupportPolicy.currentSystemDescription)"
        appearanceControl.selectedSegmentIndex = NyxelAppearanceStore.theme.rawValue
        biometricSwitch.isOn = UserDefaults.standard.bool(forKey: "nyxel.biometric.enabled")
        activationVoiceSwitch.isOn = SoundService.shared.activationVoiceEnabled
        serviceStatusLabel.text = "●  \(NyxelRemoteConfigStore.status)"
        serviceStatusLabel.textColor = NyxelRemoteConfigStore.status == "Configuración válida" ? AppTheme.success : AppTheme.warm
        diagnosticsLabel.text = diagnosticText()
        gamesLabel.text = NyxelInstalledGames.statusText()
        let history = NyxelActivityLog.entries
        historyLabel.text = history.isEmpty ? "HISTORIAL\nSin actividad registrada" : "HISTORIAL\n" + history.joined(separator: "\n")
        let formatter = DateFormatter(); formatter.dateFormat = "HH:mm:ss"
        activityLabel.text = "Última actividad  •  Perfil consultado a las \(formatter.string(from: Date()))"
        updateProgressRing()
    }

    private func configure() {
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false

        sceneBackgroundView.image = ProfileMediaStore.load("nyxel-profile-cover.jpg")
        sceneBackgroundView.contentMode = .scaleAspectFill
        sceneBackgroundView.clipsToBounds = true
        sceneBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sceneBackgroundView)
        sceneShade.colors = [
            UIColor.black.withAlphaComponent(0.32).cgColor,
            AppTheme.background.withAlphaComponent(0.72).cgColor,
            AppTheme.background.withAlphaComponent(0.98).cgColor
        ]
        sceneShade.startPoint = CGPoint(x: 0.5, y: 0)
        sceneShade.endPoint = CGPoint(x: 0.5, y: 1)
        sceneBackgroundView.layer.addSublayer(sceneShade)

        commandTitleLabel.text = "PLAYER // COMMAND CENTER"
        commandTitleLabel.font = AppTheme.monoFont(11)
        commandTitleLabel.textColor = AppTheme.accent
        commandTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        commandSubtitleLabel.text = "NYXEL EXTERNAL  ·  CONTROL DE SESIÓN"
        commandSubtitleLabel.font = AppTheme.monoFont(9)
        commandSubtitleLabel.textColor = UIColor.white.withAlphaComponent(0.62)
        commandSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(commandTitleLabel)
        addSubview(commandSubtitleLabel)

        avatarCircle.backgroundColor = AppTheme.card
        avatarCircle.layer.cornerRadius = 59
        avatarCircle.layer.borderWidth = 2
        avatarCircle.layer.borderColor = AppTheme.accent.cgColor
        avatarCircle.layer.shadowColor = AppTheme.accent.cgColor
        avatarCircle.layer.shadowOpacity = 0.16
        avatarCircle.layer.shadowRadius = 9
        avatarCircle.clipsToBounds = true
        avatarCircle.translatesAutoresizingMaskIntoConstraints = false

        avatarImageView.image = ProfileMediaStore.load("nyxel-profile-avatar.jpg") ?? UIImage(named: "NyxelAvatar")
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

        nameLabel.text = UserDefaults.standard.string(forKey: "nyxel.profile.name") ?? "NYXEL EXTERNAL"
        nameLabel.font = AppTheme.titleFont(23)
        nameLabel.textColor = AppTheme.primaryText
        nameLabel.adjustsFontSizeToFitWidth = true
        nameLabel.minimumScaleFactor = 0.72
        usernameLabel.text = UserDefaults.standard.string(forKey: "nyxel.profile.username") ?? "@nyxel_user"
        usernameLabel.font = .systemFont(ofSize: 18, weight: .bold)
        usernameLabel.textColor = AppTheme.accent
        usernameLabel.adjustsFontSizeToFitWidth = true
        usernameLabel.minimumScaleFactor = 0.75
        profileMetaLabel.font = AppTheme.monoFont(10)
        profileMetaLabel.textColor = AppTheme.tertiaryText
        profileMetaLabel.textAlignment = .center
        descriptionLabel.text = UserDefaults.standard.string(forKey: "nyxel.profile.description") ?? "Perfil de prueba de Nyxel External. Aquí podrás mostrar tu identidad y actividad."
        descriptionLabel.font = .systemFont(ofSize: 16, weight: .medium)
        descriptionLabel.textColor = AppTheme.secondaryText
        descriptionLabel.numberOfLines = 0
        [aboutUsernameLabel, aboutBioLabel, aboutCountryLabel].forEach {
            $0.font = .systemFont(ofSize: 15, weight: .regular)
            $0.textColor = AppTheme.primaryText
            $0.numberOfLines = 0
        }

        socialHeader.translatesAutoresizingMaskIntoConstraints = false
        socialHeader.backgroundColor = UIColor.black.withAlphaComponent(0.28)
        socialHeader.layer.cornerRadius = 8
        socialHeader.layer.borderWidth = 1
        socialHeader.layer.borderColor = UIColor.white.withAlphaComponent(0.18).cgColor
        socialHeader.clipsToBounds = true

        coverView.translatesAutoresizingMaskIntoConstraints = false
        coverView.backgroundColor = AppTheme.backgroundRaise
        coverView.layer.cornerRadius = 0
        coverView.clipsToBounds = true
        coverGradient.colors = [
            UIColor.black.withAlphaComponent(0.05).cgColor,
            AppTheme.accent.withAlphaComponent(0.12).cgColor,
            AppTheme.background.withAlphaComponent(0.94).cgColor
        ]
        coverGradient.startPoint = CGPoint(x: 0, y: 0)
        coverGradient.endPoint = CGPoint(x: 1, y: 1)
        coverImageView.image = ProfileMediaStore.load("nyxel-profile-cover.jpg")
        coverImageView.contentMode = .scaleAspectFill
        coverImageView.clipsToBounds = true
        coverImageView.translatesAutoresizingMaskIntoConstraints = false
        coverView.addSubview(coverImageView)
        coverView.layer.addSublayer(coverGradient)
        coverBrandLabel.text = "NYXEL  //  PLAYER PROFILE"
        coverBrandLabel.font = AppTheme.monoFont(10)
        coverBrandLabel.textColor = UIColor.white.withAlphaComponent(0.86)
        coverBrandLabel.translatesAutoresizingMaskIntoConstraints = false
        coverView.addSubview(coverBrandLabel)
        coverStatusLabel.text = "●  ACTIVO"
        coverStatusLabel.font = .systemFont(ofSize: 10, weight: .bold)
        coverStatusLabel.textColor = AppTheme.success
        coverStatusLabel.backgroundColor = UIColor.black.withAlphaComponent(0.42)
        coverStatusLabel.layer.cornerRadius = 10
        coverStatusLabel.clipsToBounds = true
        coverStatusLabel.textAlignment = .center
        coverStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        coverView.addSubview(coverStatusLabel)
        NSLayoutConstraint.activate([
            coverImageView.leadingAnchor.constraint(equalTo: coverView.leadingAnchor),
            coverImageView.trailingAnchor.constraint(equalTo: coverView.trailingAnchor),
            coverImageView.topAnchor.constraint(equalTo: coverView.topAnchor),
            coverImageView.bottomAnchor.constraint(equalTo: coverView.bottomAnchor)
        ])
        socialHeader.addSubview(coverView)
        coverView.isHidden = false
        socialHeader.addSubview(avatarCircle)
        socialHeader.addSubview(nameLabel)
        socialHeader.addSubview(usernameLabel)
        socialHeader.addSubview(profileMetaLabel)
        socialHeader.addSubview(rankBadge)
        socialHeader.addSubview(descriptionLabel)
        configureEditButton(editProfileButton, title: "EDITAR PERFIL", imageName: "pencil")
        configureEditButton(avatarEditButton, title: nil, imageName: "camera.fill")
        configureEditButton(coverEditButton, title: nil, imageName: "photo.fill")
        coverEditButton.isHidden = false
        socialHeader.addSubview(editProfileButton)
        socialHeader.addSubview(avatarEditButton)
        socialHeader.addSubview(coverEditButton)
        editProfileButton.addTarget(self, action: #selector(editProfileTapped), for: .touchUpInside)
        avatarEditButton.addTarget(self, action: #selector(editAvatarTapped), for: .touchUpInside)
        coverEditButton.addTarget(self, action: #selector(editCoverTapped), for: .touchUpInside)

        rankLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        rankLabel.translatesAutoresizingMaskIntoConstraints = false
        rankBadge.layer.cornerRadius = 100
        rankBadge.layer.borderWidth = 1
        rankBadge.isHidden = true
        rankBadge.translatesAutoresizingMaskIntoConstraints = false
        rankBadge.addSubview(rankLabel)

        let keyRow = makeRow(label: "Key", valueLabel: keyValueLabel)
        let countryRow = makeRow(label: "País", valueLabel: countryValueLabel)
        let statusRow = makeRow(label: "Estado", valueLabel: accountStatusLabel)
        let expirationRow = makeRow(label: "Expira en", valueLabel: expirationValueLabel)
        let countRow = makeRow(label: "Inyecciones totales", valueLabel: countValueLabel)
        let aboutSection = ProfileDisclosureSection(title: "MÁS INFORMACIÓN", views: [
            makeInfoBlock(title: "Usuario", valueLabel: aboutUsernameLabel),
            makeInfoBlock(title: "Descripción", valueLabel: aboutBioLabel),
            makeInfoBlock(title: "País", valueLabel: aboutCountryLabel)
        ])
        publicSearchField.placeholder = "Buscar usuario"
        publicSearchField.textColor = AppTheme.primaryText
        publicSearchField.font = .systemFont(ofSize: 14, weight: .medium)
        publicSearchField.autocapitalizationType = .none
        publicSearchField.backgroundColor = AppTheme.backgroundRaise
        publicSearchField.layer.cornerRadius = 10
        publicSearchField.layer.borderWidth = 1
        publicSearchField.layer.borderColor = AppTheme.hairline.cgColor
        publicSearchField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
        publicSearchField.leftViewMode = .always
        publicSearchField.heightAnchor.constraint(equalToConstant: 42).isActive = true
        publicSearchButton.setTitle("BUSCAR", for: .normal)
        publicSearchButton.setTitleColor(AppTheme.background, for: .normal)
        publicSearchButton.backgroundColor = AppTheme.accent
        publicSearchButton.titleLabel?.font = .systemFont(ofSize: 11, weight: .heavy)
        publicSearchButton.layer.cornerRadius = 10
        publicSearchButton.widthAnchor.constraint(equalToConstant: 82).isActive = true
        publicSearchButton.heightAnchor.constraint(equalToConstant: 42).isActive = true
        publicSearchButton.addTarget(self, action: #selector(searchPublicProfileTapped), for: .touchUpInside)
        publicSearchResultLabel.text = "Busca un usuario para ver su perfil público."
        publicSearchResultLabel.textColor = AppTheme.secondaryText
        publicSearchResultLabel.font = AppTheme.monoFont(11)
        publicSearchResultLabel.numberOfLines = 0
        publicSearchResultLabel.backgroundColor = AppTheme.backgroundRaise
        publicSearchResultLabel.layer.cornerRadius = 12
        publicSearchResultLabel.layer.borderWidth = 1
        publicSearchResultLabel.layer.borderColor = AppTheme.hairline.cgColor
        publicSearchResultLabel.isHidden = false
        let searchRow = UIStackView(arrangedSubviews: [publicSearchField, publicSearchButton])
        searchRow.axis = .horizontal
        searchRow.spacing = 8
        let searchSection = ProfileDisclosureSection(title: "COMUNIDAD", views: [searchRow, publicSearchResultLabel])
        searchSection.isHidden = true
        profileTabs.selectedSegmentIndex = 0
        profileTabs.selectedSegmentTintColor = AppTheme.accent
        profileTabs.setTitleTextAttributes([.foregroundColor: AppTheme.background, .font: UIFont.systemFont(ofSize: 10, weight: .bold)], for: .selected)
        profileTabs.setTitleTextAttributes([.foregroundColor: AppTheme.secondaryText, .font: UIFont.systemFont(ofSize: 10, weight: .semibold)], for: .normal)
        profileTabs.addTarget(self, action: #selector(profileTabChanged), for: .valueChanged)
        profileTabs.heightAnchor.constraint(equalToConstant: 42).isActive = true
        let metricsRow = UIStackView(arrangedSubviews: [
            makeMetricCard(title: "HEAD", valueLabel: headMetricLabel),
            makeMetricCard(title: "CUELLO", valueLabel: neckMetricLabel),
            makeMetricCard(title: "PECHO", valueLabel: chestMetricLabel)
        ])
        metricsRow.axis = .horizontal
        metricsRow.spacing = 8
        metricsRow.distribution = .fillEqually
        let modeBlock = makeInfoBlock(title: "MODO MÁS USADO", valueLabel: mostUsedModeLabel)
        let activitySection = ProfileDisclosureSection(title: "PLAYER STATS", views: [metricsRow, modeBlock, searchSection])

        serviceStatusLabel.font = AppTheme.monoFont(11)
        diagnosticsLabel.font = UIFont.monospacedSystemFont(ofSize: 10, weight: .medium)
        diagnosticsLabel.textColor = AppTheme.secondaryText
        diagnosticsLabel.numberOfLines = 0
        activityLabel.font = .systemFont(ofSize: 10, weight: .medium)
        activityLabel.textColor = AppTheme.tertiaryText
        activityLabel.numberOfLines = 0
        gamesLabel.font = AppTheme.monoFont(10)
        gamesLabel.textColor = AppTheme.secondaryText
        gamesLabel.numberOfLines = 0
        historyLabel.font = AppTheme.monoFont(10)
        historyLabel.textColor = AppTheme.tertiaryText
        historyLabel.numberOfLines = 0
        deviceLabel.font = AppTheme.monoFont(10)
        deviceLabel.textColor = AppTheme.secondaryText
        deviceLabel.numberOfLines = 0
        rankProgressLabel.font = AppTheme.monoFont(10)
        rankProgressLabel.textColor = AppTheme.accentHot
        appearanceControl.selectedSegmentIndex = NyxelAppearanceStore.theme.rawValue
        appearanceControl.selectedSegmentTintColor = AppTheme.accent
        appearanceControl.setTitleTextAttributes([.foregroundColor: AppTheme.background], for: .selected)
        appearanceControl.setTitleTextAttributes([.foregroundColor: AppTheme.secondaryText], for: .normal)
        appearanceControl.addTarget(self, action: #selector(appearanceChanged), for: .valueChanged)
        biometricSwitch.onTintColor = AppTheme.accent
        biometricSwitch.addTarget(self, action: #selector(biometricChanged), for: .valueChanged)
        activationVoiceSwitch.onTintColor = AppTheme.accent
        activationVoiceSwitch.addTarget(self, action: #selector(activationVoiceChanged), for: .valueChanged)

        refreshButton.setTitle("↻  ACTUALIZAR PERFIL", for: .normal)
        refreshButton.setTitleColor(AppTheme.accent, for: .normal)
        refreshButton.titleLabel?.font = .systemFont(ofSize: 11, weight: .heavy)
        refreshButton.backgroundColor = AppTheme.accentDim.withAlphaComponent(0.72)
        refreshButton.layer.cornerRadius = 10
        refreshButton.layer.borderWidth = 1
        refreshButton.layer.borderColor = AppTheme.accent.withAlphaComponent(0.35).cgColor
        refreshButton.heightAnchor.constraint(equalToConstant: 38).isActive = true

        let card = DavizinCardView()
        card.useTransparentAppearance()
        card.contentInsets = .zero
        card.layer.cornerRadius = 0
        card.layer.shadowOpacity = 0
        card.layer.borderWidth = 0
        let biometricRow = UIStackView(arrangedSubviews: [makeCaptionLabel("Face ID / Touch ID antes de inyectar"), biometricSwitch])
        biometricRow.axis = .horizontal
        biometricRow.alignment = .center
        biometricRow.distribution = .equalSpacing
        let activationVoiceRow = UIStackView(arrangedSubviews: [makeCaptionLabel("Audio \"Opción activada\" después de inyectar"), activationVoiceSwitch])
        activationVoiceRow.axis = .horizontal
        activationVoiceRow.alignment = .center
        activationVoiceRow.distribution = .equalSpacing

        let accountSection = ProfileDisclosureSection(title: "CUENTA", views: [keyRow, countryRow, statusRow, expirationRow, countRow, rankProgressLabel, deviceLabel])
        let appearanceSection = ProfileDisclosureSection(title: "APARIENCIA", views: [appearanceControl])
        let securitySection = ProfileDisclosureSection(title: "SEGURIDAD", views: [biometricRow])
        let audioSection = ProfileDisclosureSection(title: "AUDIO", views: [activationVoiceRow])
        let diagnosticSection = ProfileDisclosureSection(title: "DIAGNÓSTICO", views: [serviceStatusLabel, diagnosticsLabel, gamesLabel], expanded: false)
        let historyActivitySection = ProfileDisclosureSection(title: "HISTORIAL TÉCNICO", views: [historyLabel, activityLabel], expanded: false)
        [showCountrySwitch, showLastSeenSwitch, showStatsSwitch].forEach { $0.onTintColor = AppTheme.accent; $0.addTarget(self, action: #selector(privacyChanged), for: .valueChanged) }
        showCountrySwitch.isOn = UserDefaults.standard.object(forKey: "nyxel.privacy.country") as? Bool ?? true
        showLastSeenSwitch.isOn = UserDefaults.standard.object(forKey: "nyxel.privacy.lastSeen") as? Bool ?? true
        showStatsSwitch.isOn = UserDefaults.standard.object(forKey: "nyxel.privacy.stats") as? Bool ?? true
        let privacySection = ProfileDisclosureSection(title: "PRIVACIDAD", views: [privacyRow("Mostrar país", showCountrySwitch), privacyRow("Mostrar última conexión", showLastSeenSwitch), privacyRow("Mostrar estadísticas", showStatsSwitch)], expanded: false)
        let settingsSection = ProfileDisclosureSection(title: "PLAYER SETTINGS", views: [accountSection, privacySection, appearanceSection, securitySection, audioSection, diagnosticSection, historyActivitySection], expanded: false)
        profileTabs.isHidden = true
        let stack = UIStackView(arrangedSubviews: [socialHeader, activitySection, settingsSection, refreshButton, logoutButton])
        tabViews = [activitySection, settingsSection]
        tabViews.forEach { $0.isHidden = false }
        stack.axis = .vertical; stack.spacing = 15
        stack.setCustomSpacing(22, after: socialHeader)
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.translatesAutoresizingMaskIntoConstraints = false
        card.addContent(stack)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = true
        scrollView.indicatorStyle = .white
        addSubview(scrollView)
        scrollView.addSubview(card)

        refreshButton.addTarget(self, action: #selector(refreshTapped), for: .touchUpInside)
        logoutButton.addTarget(self, action: #selector(logoutTapped), for: .touchUpInside)

        nameLabel.textAlignment = .left
        usernameLabel.textAlignment = .left
        NSLayoutConstraint.activate([
            sceneBackgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            sceneBackgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            sceneBackgroundView.topAnchor.constraint(equalTo: topAnchor),
            sceneBackgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
            commandTitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22),
            commandTitleLabel.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 12),
            commandSubtitleLabel.leadingAnchor.constraint(equalTo: commandTitleLabel.leadingAnchor),
            commandSubtitleLabel.topAnchor.constraint(equalTo: commandTitleLabel.bottomAnchor, constant: 4),
            socialHeader.heightAnchor.constraint(equalToConstant: 390),
            coverView.leadingAnchor.constraint(equalTo: socialHeader.leadingAnchor),
            coverView.trailingAnchor.constraint(equalTo: socialHeader.trailingAnchor),
            coverView.topAnchor.constraint(equalTo: socialHeader.topAnchor),
            coverView.heightAnchor.constraint(equalTo: socialHeader.heightAnchor),
            coverBrandLabel.leadingAnchor.constraint(equalTo: coverView.leadingAnchor, constant: 16),
            coverBrandLabel.topAnchor.constraint(equalTo: coverView.topAnchor, constant: 16),
            coverStatusLabel.trailingAnchor.constraint(equalTo: coverView.trailingAnchor, constant: -16),
            coverStatusLabel.topAnchor.constraint(equalTo: coverView.topAnchor, constant: 12),
            coverStatusLabel.widthAnchor.constraint(equalToConstant: 82),
            coverStatusLabel.heightAnchor.constraint(equalToConstant: 24),
            avatarCircle.widthAnchor.constraint(equalToConstant: 112), avatarCircle.heightAnchor.constraint(equalToConstant: 112),
            avatarCircle.leadingAnchor.constraint(equalTo: socialHeader.leadingAnchor, constant: 24),
            avatarCircle.topAnchor.constraint(equalTo: socialHeader.topAnchor, constant: 92),
            avatarImageView.leadingAnchor.constraint(equalTo: avatarCircle.leadingAnchor), avatarImageView.trailingAnchor.constraint(equalTo: avatarCircle.trailingAnchor),
            avatarImageView.topAnchor.constraint(equalTo: avatarCircle.topAnchor), avatarImageView.bottomAnchor.constraint(equalTo: avatarCircle.bottomAnchor),
            nameLabel.leadingAnchor.constraint(equalTo: avatarCircle.trailingAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: editProfileButton.leadingAnchor, constant: -12),
            nameLabel.topAnchor.constraint(equalTo: socialHeader.topAnchor, constant: 112),
            usernameLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            usernameLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            usernameLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            profileMetaLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            profileMetaLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            profileMetaLabel.topAnchor.constraint(equalTo: usernameLabel.bottomAnchor, constant: 8),
            editProfileButton.trailingAnchor.constraint(equalTo: socialHeader.trailingAnchor, constant: -16),
            editProfileButton.topAnchor.constraint(equalTo: socialHeader.topAnchor, constant: 18),
            editProfileButton.widthAnchor.constraint(equalToConstant: 112),
            editProfileButton.heightAnchor.constraint(equalToConstant: 32),
            avatarEditButton.trailingAnchor.constraint(equalTo: avatarCircle.trailingAnchor, constant: -4),
            avatarEditButton.bottomAnchor.constraint(equalTo: avatarCircle.bottomAnchor, constant: -4),
            avatarEditButton.widthAnchor.constraint(equalToConstant: 30),
            avatarEditButton.heightAnchor.constraint(equalToConstant: 30),
            coverEditButton.trailingAnchor.constraint(equalTo: coverView.trailingAnchor, constant: -14),
            coverEditButton.topAnchor.constraint(equalTo: coverView.topAnchor, constant: 14),
            coverEditButton.widthAnchor.constraint(equalToConstant: 34),
            coverEditButton.heightAnchor.constraint(equalToConstant: 34),
            rankBadge.heightAnchor.constraint(equalToConstant: 22), rankLabel.leadingAnchor.constraint(equalTo: rankBadge.leadingAnchor, constant: 10),
            rankLabel.trailingAnchor.constraint(equalTo: rankBadge.trailingAnchor, constant: -10), rankLabel.centerYAnchor.constraint(equalTo: rankBadge.centerYAnchor),
            rankBadge.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            rankBadge.topAnchor.constraint(equalTo: usernameLabel.bottomAnchor, constant: 7),
            descriptionLabel.leadingAnchor.constraint(equalTo: socialHeader.leadingAnchor, constant: 22),
            descriptionLabel.trailingAnchor.constraint(equalTo: socialHeader.trailingAnchor, constant: -18),
            descriptionLabel.topAnchor.constraint(equalTo: socialHeader.topAnchor, constant: 270),
            descriptionLabel.bottomAnchor.constraint(lessThanOrEqualTo: socialHeader.bottomAnchor, constant: -16),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor), scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: commandSubtitleLabel.bottomAnchor, constant: 18), scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            card.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor), card.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 22),
            card.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -22),
            card.leadingAnchor.constraint(greaterThanOrEqualTo: scrollView.leadingAnchor, constant: 22), card.trailingAnchor.constraint(lessThanOrEqualTo: scrollView.trailingAnchor, constant: -22),
            card.widthAnchor.constraint(lessThanOrEqualToConstant: UIDevice.current.userInterfaceIdiom == .pad ? 680 : AppTheme.contentMaximumWidth), stack.widthAnchor.constraint(greaterThanOrEqualToConstant: 240),
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

    private func makeInfoBlock(title: String, valueLabel: UILabel) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = title.uppercased()
        titleLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        titleLabel.textColor = AppTheme.tertiaryText
        let stack = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        stack.axis = .vertical
        stack.spacing = 5
        return stack
    }

    private func makeMetricCard(title: String, valueLabel: UILabel) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 9, weight: .bold)
        titleLabel.textColor = AppTheme.secondaryText
        valueLabel.text = "0"
        valueLabel.font = AppTheme.titleFont(24)
        valueLabel.textColor = AppTheme.accent
        valueLabel.textAlignment = .center
        let stack = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 5
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 12, left: 6, bottom: 12, right: 6)
        stack.backgroundColor = AppTheme.backgroundRaise
        stack.layer.cornerRadius = 12
        stack.layer.borderWidth = 1
        stack.layer.borderColor = AppTheme.hairline.cgColor
        return stack
    }

    private func privacyRow(_ title: String, _ control: UISwitch) -> UIView {
        let label = UILabel(); label.text = title; label.font = .systemFont(ofSize: 13, weight: .medium); label.textColor = AppTheme.secondaryText
        let row = UIStackView(arrangedSubviews: [label, control]); row.axis = .horizontal; row.alignment = .center; row.distribution = .equalSpacing
        return row
    }

    private func configureEditButton(_ button: UIButton, title: String?, imageName: String) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: imageName), for: .normal)
        button.setTitle(title, for: .normal)
        button.tintColor = AppTheme.background
        button.setTitleColor(AppTheme.background, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 10, weight: .heavy)
        button.backgroundColor = AppTheme.accent
        button.layer.cornerRadius = 9
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.28).cgColor
        button.accessibilityLabel = title ?? "Cambiar imagen"
    }

    var profileDraft: (name: String, username: String, description: String) {
        (nameLabel.text ?? "NYXEL EXTERNAL", usernameLabel.text ?? "@nyxel_user", descriptionLabel.text ?? "")
    }

    func setUsernameLocked(_ locked: Bool) {
        usernameLocked = locked
        UserDefaults.standard.set(locked, forKey: "nyxel.profile.username.locked")
        usernameLabel.textColor = locked ? AppTheme.secondaryText : AppTheme.accent
    }

    func showPublicSearchResult(_ text: String) {
        publicSearchResultLabel.text = text
        publicSearchResultLabel.textColor = AppTheme.primaryText
    }

    func showPublicSearchError(_ text: String) {
        publicSearchResultLabel.text = text
        publicSearchResultLabel.textColor = AppTheme.failure
    }

    func setRemoteStats(head: Int, neck: Int, chest: Int, mostUsedMode: String) {
        let hasActivity = head + neck + chest > 0 || !mostUsedMode.isEmpty
        headMetricLabel.text = hasActivity ? "\(head)" : "—"
        neckMetricLabel.text = hasActivity ? "\(neck)" : "—"
        chestMetricLabel.text = hasActivity ? "\(chest)" : "—"
        mostUsedModeLabel.text = mostUsedMode.isEmpty ? "Todavía no hay actividad" : mostUsedMode
    }

    func updateProfile(name: String, username: String, description: String) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        nameLabel.text = cleanName.isEmpty ? "NYXEL EXTERNAL" : cleanName
        if !usernameLocked {
            usernameLabel.text = cleanUsername.isEmpty ? "@nyxel_user" : (cleanUsername.hasPrefix("@") ? cleanUsername : "@" + cleanUsername)
            if !cleanUsername.isEmpty { setUsernameLocked(true) }
        }
        descriptionLabel.text = cleanDescription.isEmpty ? "Sin descripción todavía." : cleanDescription
        aboutUsernameLabel.text = usernameLabel.text
        aboutBioLabel.text = descriptionLabel.text
        aboutCountryLabel.text = countryName(for: activeCountryCode)
        UserDefaults.standard.set(nameLabel.text, forKey: "nyxel.profile.name")
        UserDefaults.standard.set(usernameLabel.text, forKey: "nyxel.profile.username")
        UserDefaults.standard.set(descriptionLabel.text, forKey: "nyxel.profile.description")
    }

    func setProfileImage(_ image: UIImage, target: ProfileMediaTarget) {
        switch target {
        case .avatar:
            avatarImageView.image = image
            ProfileMediaStore.save(image, as: "nyxel-profile-avatar.jpg")
        case .cover:
            coverImageView.image = image
            sceneBackgroundView.image = image
            ProfileMediaStore.save(image, as: "nyxel-profile-cover.jpg")
        }
        setNeedsLayout()
    }

    @objc private func editProfileTapped() { onEditProfileRequested?() }
    @objc private func searchPublicProfileTapped() {
        let query = (publicSearchField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { showPublicSearchError("Escribe un usuario para buscar."); return }
        publicSearchResultLabel.text = "Buscando…"
        onSearchRequested?(query)
    }
    @objc private func profileTabChanged() {
        tabViews.enumerated().forEach { $0.element.isHidden = $0.offset != profileTabs.selectedSegmentIndex }
    }
    @objc private func privacyChanged() {
        UserDefaults.standard.set(showCountrySwitch.isOn, forKey: "nyxel.privacy.country")
        UserDefaults.standard.set(showLastSeenSwitch.isOn, forKey: "nyxel.privacy.lastSeen")
        UserDefaults.standard.set(showStatsSwitch.isOn, forKey: "nyxel.privacy.stats")
    }
    @objc private func editAvatarTapped() { onRequestMedia?(.avatar) }
    @objc private func editCoverTapped() { onRequestMedia?(.cover) }

    @objc private func refreshTapped() {
        refreshButton.isEnabled = false
        refreshButton.setTitle("↻  ACTUALIZANDO...", for: .normal)
        onRefreshRequested?()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.refreshButton.isEnabled = true
            self?.refreshButton.setTitle("↻  ACTUALIZAR PERFIL", for: .normal)
            self?.refresh()
        }
    }

    @objc private func logoutTapped() { SoundService.shared.playClick(); delegate?.profileViewDidTapLogout(self) }

    @objc private func appearanceChanged() {
        let theme = NyxelAppearanceStore.Theme(rawValue: appearanceControl.selectedSegmentIndex) ?? .cyan
        NyxelAppearanceStore.setTheme(theme)
        onAppearanceChanged?()
    }

    @objc private func biometricChanged() {
        UserDefaults.standard.set(biometricSwitch.isOn, forKey: "nyxel.biometric.enabled")
        NyxelActivityLog.record(biometricSwitch.isOn ? "Biometría activada" : "Biometría desactivada")
    }

    @objc private func activationVoiceChanged() {
        SoundService.shared.activationVoiceEnabled = activationVoiceSwitch.isOn
        NyxelActivityLog.record(activationVoiceSwitch.isOn ? "Audio de confirmación activado" : "Audio de confirmación desactivado")
    }

    private func makeCaptionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = AppTheme.secondaryText
        return label
    }

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

    private func countryName(for code: String?) -> String {
        guard let code, !code.isEmpty else { return "País no disponible" }
        let names = ["MX": "México", "GT": "Guatemala", "US": "Estados Unidos", "CA": "Canadá", "ES": "España", "CO": "Colombia", "AR": "Argentina", "CL": "Chile", "PE": "Perú", "BR": "Brasil", "DO": "República Dominicana", "HN": "Honduras", "SV": "El Salvador", "CR": "Costa Rica", "PA": "Panamá", "NI": "Nicaragua", "VE": "Venezuela", "EC": "Ecuador", "BO": "Bolivia", "UY": "Uruguay", "PY": "Paraguay", "PR": "Puerto Rico", "EU": "Europa"]
        let normalized = code.uppercased()
        return names[normalized].map { "\(normalized) · \($0)" } ?? normalized
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
        sceneShade.frame = sceneBackgroundView.bounds
        coverGradient.frame = coverView.bounds
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
