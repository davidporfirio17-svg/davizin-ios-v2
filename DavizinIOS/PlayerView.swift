import UIKit

final class PlayerView: UIView {
    var onLookupRequested: ((String, String) -> Void)?
    var onAssetRequested: ((String, @escaping (UIImage?) -> Void) -> Void)?
    var onBanCheckRequested: ((String, @escaping (Result<FreeFireBanCheck, Error>) -> Void) -> Void)?

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let queryCard = DavizinCardView()
    private let heroCard = UIView()
    private let bannerImageView = UIImageView()
    private let heroGradient = CAGradientLayer()
    private let avatarImageView = UIImageView()
    private let heroNameLabel = UILabel()
    private let heroSubtitleLabel = UILabel()
    private let heroUIDLabel = UILabel()
    private let copyUIDButton = UIButton(type: .system)
    private let heroLevelPill = UILabel()
    private let heroRegionPill = UILabel()

    private let uidField = UITextField()
    private let regionControl = UISegmentedControl(items: ["BR · NA", "SG", "IND"])
    private let searchButton = UIButton(type: .system)
    private let statusLabel = UILabel()

    private let levelValueLabel = UILabel()
    private let likesValueLabel = UILabel()
    private let seasonValueLabel = UILabel()
    private let brPointsLabel = UILabel()
    private let brCodeLabel = UILabel()
    private let brSeasonLabel = UILabel()
    private let csPointsLabel = UILabel()
    private let csCodeLabel = UILabel()
    private let csSeasonLabel = UILabel()
    private let soloStatsLabel = UILabel()
    private let duoStatsLabel = UILabel()
    private let squadStatsLabel = UILabel()
    private let statsStatusLabel = UILabel()
    private let statsStatusContainer = UIView()
    private let statsStatusIcon = UIImageView()
    private let banCheckStatusLabel = UILabel()
    private let banCheckButton = UIButton(type: .system)
    private let clanLabel = UILabel()
    private let signatureLabel = UILabel()
    private let outfitGridStack = UIStackView()

    private var renderGeneration = 0
    private let isPad = UIDevice.current.userInterfaceIdiom == .pad

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
        heroGradient.frame = heroCard.bounds
    }

    func setLookupLoading(_ loading: Bool, message: String) {
        searchButton.isEnabled = !loading
        searchButton.alpha = loading ? 0.62 : 1.0
        searchButton.setTitle(loading ? "CONSULTANDO PERFIL…" : "BUSCAR PERFIL", for: .normal)
        statusLabel.text = message
        statusLabel.textColor = loading ? AppTheme.readableAccent : AppTheme.secondaryText
    }

    func setLookupError(_ message: String) {
        setLookupLoading(false, message: message)
        statusLabel.textColor = AppTheme.accentWarm
    }

    func showSummary(_ summary: FreeFireLookupSummary) {
        renderGeneration += 1
        let generation = renderGeneration

        heroNameLabel.text = summary.nickname?.isEmpty == false ? summary.nickname : "Jugador de Free Fire"
        heroSubtitleLabel.text = [summary.level.map { "Nivel \($0)" }, summary.region.map { "Región \($0.uppercased())" }]
            .compactMap { $0 }
            .joined(separator: "  ·  ")
        heroUIDLabel.text = "UID  \(summary.uid)"
        banCheckStatusLabel.text = "Estado sin consultar para este UID."
        banCheckStatusLabel.textColor = AppTheme.secondaryText
        copyUIDButton.isHidden = summary.uid.isEmpty
        heroLevelPill.text = summary.level.map { "NIVEL \($0)" } ?? "PERFIL PÚBLICO"
        heroRegionPill.text = summary.region?.uppercased() ?? "FREE FIRE"

        levelValueLabel.text = summary.level ?? "—"
        likesValueLabel.text = Self.formatted(summary.likes) ?? "—"
        seasonValueLabel.text = summary.season ?? "—"

        brPointsLabel.text = Self.formatted(summary.brPoints) ?? "—"
        brCodeLabel.text = "Código del API  \(summary.brRankCode ?? "—")"
        brSeasonLabel.text = summary.season.map { "Temporada \($0) · dato del API" } ?? "Puntos de Battle Royale"
        csPointsLabel.text = Self.formatted(summary.csPoints) ?? "—"
        csCodeLabel.text = "Código del API  \(summary.csRankCode ?? "—")"
        csSeasonLabel.text = summary.season.map { "Temporada \($0) · dato del API" } ?? "Puntos de Clash Squad"

        let statsByKey = Dictionary(uniqueKeysWithValues: summary.modes.map { ($0.key, $0) })
        let statsWarning = summary.warnings.first { $0.localizedCaseInsensitiveContains("estadística") }
        let providerStatsUnavailable = statsWarning != nil
        soloStatsLabel.text = Self.modeText(statsByKey["brCareer_solo"], providerUnavailable: providerStatsUnavailable)
        duoStatsLabel.text = Self.modeText(statsByKey["brCareer_duo"], providerUnavailable: providerStatsUnavailable)
        squadStatsLabel.text = Self.modeText(statsByKey["brCareer_squad"], providerUnavailable: providerStatsUnavailable)
        if let statsWarning {
            let detail = statsWarning.replacingOccurrences(of: "Estadísticas:", with: "", options: [.caseInsensitive]).trimmingCharacters(in: .whitespaces)
            if detail.localizedCaseInsensitiveContains("jwt") {
                statsStatusLabel.text = "El proveedor no pudo obtener su token de estadísticas (error JWT). No es un problema con tu sesión de Nyxel. El perfil y los assets disponibles siguen cargados; esto no significa 0 partidas. Inténtalo más tarde."
            } else {
                statsStatusLabel.text = "El proveedor no pudo cargar las estadísticas: \(detail). No es un problema con tu sesión de Nyxel y no significa 0 partidas. El perfil y los assets disponibles siguen cargados."
            }
            statsStatusLabel.textColor = AppTheme.accentWarm
            statsStatusIcon.image = UIImage(systemName: "exclamationmark.triangle.fill")
            statsStatusIcon.tintColor = AppTheme.accentWarm
            statsStatusContainer.backgroundColor = AppTheme.accentWarm.withAlphaComponent(0.10)
            statsStatusContainer.layer.borderColor = AppTheme.accentWarm.withAlphaComponent(0.30).cgColor
        } else if summary.modes.isEmpty {
            statsStatusLabel.text = "El proveedor no devolvió estadísticas para estos modos. Los datos faltantes no equivalen a 0 partidas."
            statsStatusLabel.textColor = AppTheme.secondaryText
            statsStatusIcon.image = UIImage(systemName: "info.circle.fill")
            statsStatusIcon.tintColor = AppTheme.readableAccent
            statsStatusContainer.backgroundColor = AppTheme.background.withAlphaComponent(0.40)
            statsStatusContainer.layer.borderColor = AppTheme.hairlineStrong.cgColor
        } else {
            statsStatusLabel.text = "Estadísticas públicas devueltas por el proveedor."
            statsStatusLabel.textColor = AppTheme.secondaryText
            statsStatusIcon.image = UIImage(systemName: "checkmark.circle.fill")
            statsStatusIcon.tintColor = AppTheme.success
            statsStatusContainer.backgroundColor = AppTheme.background.withAlphaComponent(0.40)
            statsStatusContainer.layer.borderColor = AppTheme.hairlineStrong.cgColor
        }

        let clanParts = [summary.clanName, summary.clanLevel.map { "Nv. \($0)" }, summary.clanMembers.map { "\($0) integrantes" }]
            .compactMap { $0 }
        clanLabel.text = clanParts.isEmpty ? "Sin clan público disponible" : clanParts.joined(separator: "  ·  ")
        signatureLabel.text = summary.signature?.isEmpty == false ? "“\(summary.signature!)”" : "Sin firma pública"

        if summary.warnings.isEmpty {
            setLookupLoading(false, message: "Perfil actualizado. Datos públicos obtenidos del API.")
            statusLabel.textColor = AppTheme.success
        } else {
            setLookupLoading(false, message: "Perfil cargado parcialmente. Algunas estadísticas no llegaron del proveedor.")
            statusLabel.textColor = AppTheme.accentWarm
        }

        requestAsset(summary.bannerID, into: bannerImageView, generation: generation)
        requestAsset(summary.avatarID ?? summary.headPicID, into: avatarImageView, generation: generation)
        updateOutfitItems(summary.clothesIDs, generation: generation)
    }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
        configureScrollView()
        configureQueryCard()
        configureHeroCard()
        buildContent()
    }

    private func configureScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = true
        scrollView.indicatorStyle = .white
        addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = 14
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        let availableWidth = contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -28)
        availableWidth.priority = .defaultHigh
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 14),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -14),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            contentStack.widthAnchor.constraint(lessThanOrEqualToConstant: 1120),
            contentStack.centerXAnchor.constraint(equalTo: scrollView.frameLayoutGuide.centerXAnchor),
            availableWidth
        ])
    }

    private func configureQueryCard() {
        queryCard.useTransparentAppearance()
        queryCard.contentInsets = UIEdgeInsets(top: 18, left: 18, bottom: 16, right: 18)

        let title = label("ENCUENTRA UN JUGADOR", size: 12, weight: .heavy, color: AppTheme.readableAccent)
        let note = label("Consulta información pública. No modifica la cuenta ni el juego.", size: 11, weight: .regular, color: AppTheme.secondaryText)
        note.numberOfLines = 0

        uidField.placeholder = "UID de Free Fire · 5 a 15 dígitos"
        uidField.attributedPlaceholder = NSAttributedString(
            string: "UID de Free Fire · 5 a 15 dígitos",
            attributes: [.foregroundColor: AppTheme.tertiaryText]
        )
        uidField.text = UserDefaults.standard.string(forKey: "nyxel.last_player_uid")
        uidField.keyboardType = .numberPad
        uidField.autocorrectionType = .no
        uidField.autocapitalizationType = .none
        uidField.backgroundColor = AppTheme.background.withAlphaComponent(0.72)
        uidField.textColor = AppTheme.primaryText
        uidField.font = AppTheme.monoFont(13)
        uidField.layer.cornerRadius = 12
        uidField.layer.borderWidth = 1
        uidField.layer.borderColor = AppTheme.hairlineStrong.cgColor
        uidField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
        uidField.leftViewMode = .always
        uidField.heightAnchor.constraint(equalToConstant: 46).isActive = true
        uidField.accessibilityLabel = "UID de Free Fire"

        regionControl.selectedSegmentIndex = UserDefaults.standard.integer(forKey: "nyxel.last_player_region")
        regionControl.selectedSegmentTintColor = AppTheme.accent
        regionControl.setTitleTextAttributes([.foregroundColor: AppTheme.primaryText], for: .normal)
        regionControl.setTitleTextAttributes([.foregroundColor: AppTheme.accentForeground], for: .selected)
        regionControl.heightAnchor.constraint(equalToConstant: 34).isActive = true
        regionControl.accessibilityLabel = "Región de la cuenta"

        searchButton.setTitle("BUSCAR PERFIL", for: .normal)
        searchButton.setTitleColor(AppTheme.accentForeground, for: .normal)
        searchButton.titleLabel?.font = .systemFont(ofSize: 11, weight: .heavy)
        searchButton.backgroundColor = AppTheme.readableAccent
        searchButton.layer.cornerRadius = 12
        searchButton.layer.borderWidth = 1
        searchButton.layer.borderColor = AppTheme.readableAccent.withAlphaComponent(0.55).cgColor
        searchButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        searchButton.addTarget(self, action: #selector(searchTapped), for: .touchUpInside)

        statusLabel.text = "BR cubre Brasil, Estados Unidos, NA y LATAM."
        statusLabel.font = .systemFont(ofSize: 10, weight: .medium)
        statusLabel.textColor = AppTheme.secondaryText
        statusLabel.numberOfLines = 0
        statusLabel.minimumScaleFactor = 0.85

        let stack = UIStackView(arrangedSubviews: [title, note, uidField, regionControl, searchButton, statusLabel])
        stack.axis = .vertical
        stack.spacing = 9
        queryCard.addContent(stack)
    }

    private func configureHeroCard() {
        heroCard.translatesAutoresizingMaskIntoConstraints = false
        heroCard.backgroundColor = AppTheme.backgroundRaise
        heroCard.layer.cornerRadius = AppTheme.cardCornerRadius
        heroCard.layer.cornerCurve = .continuous
        heroCard.layer.borderWidth = 1
        heroCard.layer.borderColor = UIColor.white.withAlphaComponent(0.20).cgColor
        heroCard.layer.shadowColor = AppTheme.accent.cgColor
        heroCard.layer.shadowOpacity = 0.13
        heroCard.layer.shadowRadius = 24
        heroCard.layer.shadowOffset = CGSize(width: 0, height: 10)
        heroCard.clipsToBounds = true

        bannerImageView.translatesAutoresizingMaskIntoConstraints = false
        bannerImageView.contentMode = .scaleAspectFill
        bannerImageView.clipsToBounds = true
        bannerImageView.alpha = 0.72
        bannerImageView.image = UIImage(systemName: "sparkles")
        bannerImageView.tintColor = AppTheme.readableAccent.withAlphaComponent(0.24)
        heroCard.addSubview(bannerImageView)
        bannerImageView.davizinPinEdges(to: heroCard)

        heroGradient.colors = [
            UIColor.black.withAlphaComponent(0.18).cgColor,
            UIColor.black.withAlphaComponent(0.88).cgColor
        ]
        heroGradient.locations = [0.0, 1.0]
        heroGradient.startPoint = CGPoint(x: 0.5, y: 0.0)
        heroGradient.endPoint = CGPoint(x: 0.5, y: 1.0)
        heroCard.layer.addSublayer(heroGradient)

        let avatarShell = UIView()
        avatarShell.translatesAutoresizingMaskIntoConstraints = false
        avatarShell.backgroundColor = UIColor.black.withAlphaComponent(0.46)
        avatarShell.layer.cornerRadius = 37
        avatarShell.layer.borderWidth = 2
        avatarShell.layer.borderColor = AppTheme.readableAccent.withAlphaComponent(0.8).cgColor
        avatarShell.clipsToBounds = true

        avatarImageView.translatesAutoresizingMaskIntoConstraints = false
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.clipsToBounds = true
        avatarImageView.image = UIImage(systemName: "person.crop.square.fill")
        avatarImageView.tintColor = AppTheme.readableAccent.withAlphaComponent(0.65)
        avatarShell.addSubview(avatarImageView)
        NSLayoutConstraint.activate([
            avatarShell.widthAnchor.constraint(equalToConstant: 74),
            avatarShell.heightAnchor.constraint(equalToConstant: 74),
            avatarImageView.leadingAnchor.constraint(equalTo: avatarShell.leadingAnchor),
            avatarImageView.trailingAnchor.constraint(equalTo: avatarShell.trailingAnchor),
            avatarImageView.topAnchor.constraint(equalTo: avatarShell.topAnchor),
            avatarImageView.bottomAnchor.constraint(equalTo: avatarShell.bottomAnchor)
        ])

        heroNameLabel.text = "Tu perfil de jugador"
        heroNameLabel.font = .systemFont(ofSize: isPad ? 24 : 20, weight: .bold)
        heroNameLabel.textColor = .white
        heroNameLabel.numberOfLines = 2
        heroNameLabel.minimumScaleFactor = 0.82
        heroNameLabel.adjustsFontSizeToFitWidth = true

        heroSubtitleLabel.text = "Busca un UID para mostrar el perfil"
        heroSubtitleLabel.font = .systemFont(ofSize: 11, weight: .medium)
        heroSubtitleLabel.textColor = UIColor.white.withAlphaComponent(0.82)
        heroSubtitleLabel.numberOfLines = 1

        heroUIDLabel.text = "UID  —"
        heroUIDLabel.font = AppTheme.monoFont(11)
        heroUIDLabel.textColor = UIColor.white.withAlphaComponent(0.88)

        copyUIDButton.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
        copyUIDButton.tintColor = AppTheme.readableAccent
        copyUIDButton.accessibilityLabel = "Copiar UID del jugador"
        copyUIDButton.addTarget(self, action: #selector(copyUIDTapped), for: .touchUpInside)
        copyUIDButton.isHidden = true
        copyUIDButton.widthAnchor.constraint(equalToConstant: 30).isActive = true

        let uidRow = UIStackView(arrangedSubviews: [heroUIDLabel, copyUIDButton])
        uidRow.axis = .horizontal
        uidRow.alignment = .center
        uidRow.spacing = 6

        configurePill(heroLevelPill)
        configurePill(heroRegionPill)
        let pillRow = UIStackView(arrangedSubviews: [heroLevelPill, heroRegionPill])
        pillRow.axis = .horizontal
        pillRow.alignment = .center
        pillRow.spacing = 8

        let textStack = UIStackView(arrangedSubviews: [heroNameLabel, heroSubtitleLabel, uidRow, pillRow])
        textStack.axis = .vertical
        textStack.alignment = .leading
        textStack.spacing = 6

        let heroContent = UIStackView(arrangedSubviews: [avatarShell, textStack])
        heroContent.axis = .horizontal
        heroContent.alignment = .center
        heroContent.spacing = 14
        heroContent.translatesAutoresizingMaskIntoConstraints = false
        heroCard.addSubview(heroContent)
        NSLayoutConstraint.activate([
            heroCard.heightAnchor.constraint(equalToConstant: isPad ? 270 : 230),
            heroContent.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 18),
            heroContent.trailingAnchor.constraint(lessThanOrEqualTo: heroCard.trailingAnchor, constant: -16),
            heroContent.centerYAnchor.constraint(equalTo: heroCard.centerYAnchor),
            textStack.widthAnchor.constraint(greaterThanOrEqualToConstant: 120)
        ])
    }

    private func buildContent() {
        let topRow = row([queryCard, heroCard], axis: isPad ? .horizontal : .vertical)
        if isPad {
            queryCard.widthAnchor.constraint(equalTo: heroCard.widthAnchor).isActive = true
        }
        contentStack.addArrangedSubview(topRow)

        let metricRow = row([
            makeMetricCard(title: "NIVEL", value: levelValueLabel, symbol: "chart.bar.fill"),
            makeMetricCard(title: "ME GUSTA", value: likesValueLabel, symbol: "heart.fill"),
            makeMetricCard(title: "TEMPORADA", value: seasonValueLabel, symbol: "calendar")
        ], axis: .horizontal)
        contentStack.addArrangedSubview(metricRow)

        let rankRow = row([
            makeRankCard(title: "BATTLE ROYALE", symbol: "shield.lefthalf.filled", points: brPointsLabel, code: brCodeLabel, season: brSeasonLabel),
            makeRankCard(title: "CLASH SQUAD", symbol: "bolt.shield.fill", points: csPointsLabel, code: csCodeLabel, season: csSeasonLabel)
        ], axis: isPad ? .horizontal : .vertical)
        contentStack.addArrangedSubview(sectionHeading("RANGOS Y PUNTOS", subtitle: "Puntos y códigos del API; no hay un mapeo fiable del código a una insignia vigente"))
        contentStack.addArrangedSubview(rankRow)

        let modeRow = row([
            makeModeCard(title: "SOLO", symbol: "person.fill", label: soloStatsLabel),
            makeModeCard(title: "DÚO", symbol: "person.2.fill", label: duoStatsLabel),
            makeModeCard(title: "ESCUADRA", symbol: "person.3.fill", label: squadStatsLabel)
        ], axis: isPad ? .horizontal : .vertical)
        contentStack.addArrangedSubview(sectionHeading("ESTADÍSTICAS DE CARRERA", subtitle: "Solo, dúo y escuadra · cuando el proveedor las devuelve"))
        statsStatusContainer.translatesAutoresizingMaskIntoConstraints = false
        statsStatusContainer.layer.cornerRadius = 12
        statsStatusContainer.layer.borderWidth = 1
        statsStatusContainer.layer.borderColor = AppTheme.hairlineStrong.cgColor
        statsStatusContainer.backgroundColor = AppTheme.background.withAlphaComponent(0.40)

        statsStatusIcon.translatesAutoresizingMaskIntoConstraints = false
        statsStatusIcon.image = UIImage(systemName: "info.circle.fill")
        statsStatusIcon.tintColor = AppTheme.readableAccent
        statsStatusIcon.contentMode = .scaleAspectFit

        statsStatusLabel.font = .systemFont(ofSize: 11, weight: .medium)
        statsStatusLabel.textColor = AppTheme.secondaryText
        statsStatusLabel.numberOfLines = 0
        let statsNoticeStack = UIStackView(arrangedSubviews: [statsStatusIcon, statsStatusLabel])
        statsNoticeStack.axis = .horizontal
        statsNoticeStack.alignment = .top
        statsNoticeStack.spacing = 9
        statsNoticeStack.translatesAutoresizingMaskIntoConstraints = false
        statsStatusContainer.addSubview(statsNoticeStack)
        NSLayoutConstraint.activate([
            statsStatusIcon.widthAnchor.constraint(equalToConstant: 16),
            statsStatusIcon.heightAnchor.constraint(equalToConstant: 16),
            statsNoticeStack.leadingAnchor.constraint(equalTo: statsStatusContainer.leadingAnchor, constant: 12),
            statsNoticeStack.trailingAnchor.constraint(equalTo: statsStatusContainer.trailingAnchor, constant: -12),
            statsNoticeStack.topAnchor.constraint(equalTo: statsStatusContainer.topAnchor, constant: 11),
            statsNoticeStack.bottomAnchor.constraint(equalTo: statsStatusContainer.bottomAnchor, constant: -11)
        ])
        contentStack.addArrangedSubview(statsStatusContainer)
        contentStack.addArrangedSubview(modeRow)

        contentStack.addArrangedSubview(sectionHeading("ESTADO DE LA CUENTA", subtitle: "Ban Check · consulta manual · información del proveedor"))
        contentStack.addArrangedSubview(makeBanCheckCard())

        contentStack.addArrangedSubview(sectionHeading("CLAN Y PERFIL", subtitle: "Información pública asociada al UID"))
        contentStack.addArrangedSubview(makeInfoCard(title: "CLAN", symbol: "person.3.sequence.fill", label: clanLabel))
        contentStack.addArrangedSubview(makeInfoCard(title: "FIRMA", symbol: "quote.opening", label: signatureLabel))

        contentStack.addArrangedSubview(sectionHeading("ROPA Y ASSETS", subtitle: "Imágenes del servicio Free Fire Community y nombres de un catálogo comunitario"))
        contentStack.addArrangedSubview(makeOutfitCard())
    }

    private func makeMetricCard(title: String, value: UILabel, symbol: String) -> UIView {
        let card = DavizinCardView()
        card.useTransparentAppearance()
        card.contentInsets = UIEdgeInsets(top: 13, left: 13, bottom: 13, right: 13)
        let icon = UIImageView(image: UIImage(systemName: symbol))
        icon.tintColor = AppTheme.readableAccent
        icon.contentMode = .scaleAspectFit
        icon.widthAnchor.constraint(equalToConstant: 18).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 18).isActive = true
        let heading = UIStackView(arrangedSubviews: [icon, label(title, size: 9, weight: .bold, color: AppTheme.secondaryText)])
        heading.axis = .horizontal
        heading.alignment = .center
        heading.spacing = 7
        value.text = "—"
        value.font = AppTheme.monoFont(isPad ? 19 : 16)
        value.textColor = AppTheme.primaryText
        value.adjustsFontSizeToFitWidth = true
        value.minimumScaleFactor = 0.72
        let stack = UIStackView(arrangedSubviews: [heading, value])
        stack.axis = .vertical
        stack.spacing = 9
        card.addContent(stack)
        card.heightAnchor.constraint(equalToConstant: isPad ? 82 : 76).isActive = true
        return card
    }

    private func makeRankCard(title: String, symbol: String, points: UILabel, code: UILabel, season: UILabel) -> UIView {
        let card = DavizinCardView()
        card.useTransparentAppearance()
        card.contentInsets = UIEdgeInsets(top: 16, left: 17, bottom: 15, right: 17)
        let icon = UIImageView(image: UIImage(systemName: symbol))
        icon.tintColor = AppTheme.readableAccent
        icon.contentMode = .scaleAspectFit
        icon.widthAnchor.constraint(equalToConstant: 25).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 25).isActive = true
        let titleLabel = label(title, size: 10, weight: .heavy, color: AppTheme.readableAccent)
        let header = UIStackView(arrangedSubviews: [icon, titleLabel, UIView()])
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = 9

        points.text = "—"
        points.font = AppTheme.monoFont(isPad ? 27 : 24)
        points.textColor = AppTheme.primaryText
        code.text = "Código de rango  —"
        code.font = AppTheme.monoFont(10)
        code.textColor = AppTheme.secondaryText
        season.text = "Puntos publicados por el API"
        season.font = .systemFont(ofSize: 10, weight: .medium)
        season.textColor = AppTheme.tertiaryText
        season.numberOfLines = 1

        let stack = UIStackView(arrangedSubviews: [header, points, code, season])
        stack.axis = .vertical
        stack.spacing = 8
        card.addContent(stack)
        card.heightAnchor.constraint(equalToConstant: isPad ? 156 : 148).isActive = true
        return card
    }

    private func makeModeCard(title: String, symbol: String, label: UILabel) -> UIView {
        let card = DavizinCardView()
        card.useTransparentAppearance()
        card.contentInsets = UIEdgeInsets(top: 15, left: 16, bottom: 15, right: 16)
        let icon = UIImageView(image: UIImage(systemName: symbol))
        icon.tintColor = AppTheme.readableAccent
        icon.contentMode = .scaleAspectFit
        icon.widthAnchor.constraint(equalToConstant: 18).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 18).isActive = true
        let titleLabel = self.label(title, size: 10, weight: .heavy, color: AppTheme.readableAccent)
        let header = UIStackView(arrangedSubviews: [icon, titleLabel])
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = 8
        label.text = "Sin datos de carrera disponibles."
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = AppTheme.secondaryText
        label.numberOfLines = 0
        let stack = UIStackView(arrangedSubviews: [header, label])
        stack.axis = .vertical
        stack.spacing = 13
        card.addContent(stack)
        card.heightAnchor.constraint(equalToConstant: isPad ? 146 : 126).isActive = true
        return card
    }

    private func makeInfoCard(title: String, symbol: String, label: UILabel) -> UIView {
        let card = DavizinCardView()
        card.useTransparentAppearance()
        card.contentInsets = UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        let icon = UIImageView(image: UIImage(systemName: symbol))
        icon.tintColor = AppTheme.readableAccent
        icon.widthAnchor.constraint(equalToConstant: 18).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 18).isActive = true
        let titleLabel = self.label(title, size: 9, weight: .heavy, color: AppTheme.secondaryText)
        let header = UIStackView(arrangedSubviews: [icon, titleLabel])
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = 8
        label.text = "Sin información pública disponible"
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = AppTheme.primaryText
        label.numberOfLines = 0
        let stack = UIStackView(arrangedSubviews: [header, label])
        stack.axis = .vertical
        stack.spacing = 9
        card.addContent(stack)
        return card
    }

    private func makeOutfitCard() -> UIView {
        let card = DavizinCardView()
        card.useTransparentAppearance()
        card.contentInsets = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        outfitGridStack.axis = .vertical
        outfitGridStack.alignment = .fill
        outfitGridStack.distribution = .fill
        outfitGridStack.spacing = 9
        let note = label("Se muestran todos los objetos devueltos. Nombres y tipos provienen de un catálogo comunitario y pueden no estar actualizados.", size: 10, weight: .regular, color: AppTheme.secondaryText)
        note.numberOfLines = 0
        let stack = UIStackView(arrangedSubviews: [outfitGridStack, note])
        stack.axis = .vertical
        stack.spacing = 10
        card.addContent(stack)
        return card
    }

    private func updateOutfitItems(_ itemIDs: [String], generation: Int) {
        for row in outfitGridStack.arrangedSubviews {
            outfitGridStack.removeArrangedSubview(row)
            row.removeFromSuperview()
        }
        let validIDs = itemIDs.filter { $0.range(of: "^\\d{5,15}$", options: .regularExpression) != nil }
        guard !validIDs.isEmpty else {
            let emptyLabel = label("El proveedor no devolvió imágenes de ropa para este perfil.", size: 11, weight: .medium, color: AppTheme.secondaryText)
            emptyLabel.numberOfLines = 0
            outfitGridStack.addArrangedSubview(emptyLabel)
            return
        }

        let columns = isPad ? 4 : 3
        for start in stride(from: 0, to: validIDs.count, by: columns) {
            let row = UIStackView()
            row.axis = .horizontal
            row.distribution = .fillEqually
            row.alignment = .fill
            row.spacing = 9

            let end = min(start + columns, validIDs.count)
            for index in start..<end {
                row.addArrangedSubview(makeOutfitCell(itemID: validIDs[index], generation: generation))
            }
            if end - start < columns {
                for _ in (end - start)..<columns {
                    row.addArrangedSubview(UIView())
                }
            }
            outfitGridStack.addArrangedSubview(row)
        }
    }

    private func makeOutfitCell(itemID: String, generation: Int) -> UIView {
        let metadata = FreeFireClothingCatalog.item(for: itemID)
        let cell = UIView()
        cell.translatesAutoresizingMaskIntoConstraints = false
        cell.backgroundColor = AppTheme.background.withAlphaComponent(0.52)
        cell.layer.cornerRadius = 14
        cell.layer.borderWidth = 1
        cell.layer.borderColor = AppTheme.hairlineStrong.cgColor
        cell.clipsToBounds = true

        let image = UIImageView(image: UIImage(systemName: "tshirt.fill"))
        image.translatesAutoresizingMaskIntoConstraints = false
        image.contentMode = .scaleAspectFit
        image.tintColor = AppTheme.tertiaryText
        cell.addSubview(image)

        let nameLabel = label(metadata?.name ?? "Prenda sin nombre en catálogo", size: 9, weight: .semibold, color: AppTheme.primaryText)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 2
        nameLabel.lineBreakMode = .byTruncatingTail
        cell.addSubview(nameLabel)

        let categoryLabel = label(metadata?.category ?? "Tipo no identificado", size: 8, weight: .bold, color: AppTheme.readableAccent)
        categoryLabel.translatesAutoresizingMaskIntoConstraints = false
        categoryLabel.textAlignment = .center
        categoryLabel.lineBreakMode = .byTruncatingTail
        cell.addSubview(categoryLabel)

        let idLabel = label("ID \(itemID)", size: 7, weight: .medium, color: AppTheme.tertiaryText)
        idLabel.translatesAutoresizingMaskIntoConstraints = false
        idLabel.textAlignment = .center
        cell.addSubview(idLabel)

        let imageStatusLabel = label("Imagen no disponible", size: 7, weight: .medium, color: AppTheme.accentWarm)
        imageStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        imageStatusLabel.textAlignment = .center
        imageStatusLabel.isHidden = true
        cell.addSubview(imageStatusLabel)

        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.color = AppTheme.readableAccent
        spinner.hidesWhenStopped = true
        spinner.startAnimating()
        cell.addSubview(spinner)

        NSLayoutConstraint.activate([
            cell.heightAnchor.constraint(equalToConstant: isPad ? 148 : 136),
            image.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 5),
            image.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -5),
            image.topAnchor.constraint(equalTo: cell.topAnchor, constant: 5),
            image.bottomAnchor.constraint(equalTo: nameLabel.topAnchor, constant: -2),
            nameLabel.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 3),
            nameLabel.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -3),
            nameLabel.heightAnchor.constraint(equalToConstant: 27),
            categoryLabel.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 3),
            categoryLabel.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -3),
            categoryLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 1),
            categoryLabel.heightAnchor.constraint(equalToConstant: 11),
            idLabel.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 3),
            idLabel.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -3),
            idLabel.topAnchor.constraint(equalTo: categoryLabel.bottomAnchor, constant: 1),
            idLabel.heightAnchor.constraint(equalToConstant: 9),
            imageStatusLabel.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 3),
            imageStatusLabel.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -3),
            imageStatusLabel.topAnchor.constraint(equalTo: idLabel.bottomAnchor, constant: 1),
            imageStatusLabel.bottomAnchor.constraint(equalTo: cell.bottomAnchor, constant: -3),
            spinner.centerXAnchor.constraint(equalTo: image.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: image.centerYAnchor)
        ])

        cell.accessibilityLabel = "\(metadata?.name ?? "Prenda sin nombre"), \(metadata?.category ?? "tipo no identificado"), ID \(itemID)"
        requestAsset(itemID, into: image, generation: generation) { imageLoaded in
            spinner.stopAnimating()
            imageStatusLabel.isHidden = imageLoaded
            if !imageLoaded {
                image.image = UIImage(systemName: "photo.badge.exclamationmark")
                image.tintColor = AppTheme.accentWarm
            }
        }
        return cell
    }

    private func makeBanCheckCard() -> UIView {
        let card = DavizinCardView()
        card.useTransparentAppearance()
        card.contentInsets = UIEdgeInsets(top: 15, left: 16, bottom: 15, right: 16)

        let note = label("Consulta de solo lectura. El resultado no es una verificación oficial de Garena.", size: 10, weight: .regular, color: AppTheme.secondaryText)
        note.numberOfLines = 0

        banCheckButton.setTitle("CONSULTAR ESTADO DE CUENTA", for: .normal)
        banCheckButton.setTitleColor(AppTheme.accentForeground, for: .normal)
        banCheckButton.titleLabel?.font = .systemFont(ofSize: 10, weight: .heavy)
        banCheckButton.backgroundColor = AppTheme.readableAccent
        banCheckButton.layer.cornerRadius = 11
        banCheckButton.heightAnchor.constraint(equalToConstant: 42).isActive = true
        banCheckButton.addTarget(self, action: #selector(banCheckTapped), for: .touchUpInside)
        banCheckButton.accessibilityLabel = "Consultar estado de baneo reportado por el proveedor"

        banCheckStatusLabel.text = "La consulta se ejecuta solo cuando tocas el botón."
        banCheckStatusLabel.font = .systemFont(ofSize: 11, weight: .medium)
        banCheckStatusLabel.textColor = AppTheme.secondaryText
        banCheckStatusLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [note, banCheckButton, banCheckStatusLabel])
        stack.axis = .vertical
        stack.spacing = 10
        card.addContent(stack)
        return card
    }

    private func sectionHeading(_ title: String, subtitle: String) -> UIView {
        let heading = label(title, size: 11, weight: .heavy, color: AppTheme.readableAccent)
        let note = label(subtitle, size: 10, weight: .regular, color: AppTheme.secondaryText)
        note.numberOfLines = 0
        let stack = UIStackView(arrangedSubviews: [heading, note])
        stack.axis = .vertical
        stack.spacing = 3
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 7, left: 3, bottom: 1, right: 3)
        return stack
    }

    private func row(_ views: [UIView], axis: NSLayoutConstraint.Axis) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = axis
        stack.distribution = axis == .horizontal ? .fillEqually : .fill
        stack.alignment = .fill
        stack.spacing = 11
        return stack
    }

    private func configurePill(_ view: UILabel) {
        view.font = .systemFont(ofSize: 8, weight: .heavy)
        view.textColor = .white
        view.backgroundColor = UIColor.black.withAlphaComponent(0.42)
        view.layer.cornerRadius = 8
        view.layer.masksToBounds = true
        view.textAlignment = .center
        view.text = "FREE FIRE"
        view.isUserInteractionEnabled = false
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    private func label(_ text: String, size: CGFloat, weight: UIFont.Weight, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = color
        return label
    }

    private func requestAsset(_ itemID: String?, into imageView: UIImageView, generation: Int, completion: ((Bool) -> Void)? = nil) {
        guard let itemID, !itemID.isEmpty else {
            imageView.image = UIImage(systemName: imageView === avatarImageView ? "person.crop.square.fill" : "sparkles")
            completion?(false)
            return
        }
        imageView.image = UIImage(systemName: imageView === avatarImageView ? "person.crop.square.fill" : "photo")
        guard let onAssetRequested else {
            completion?(false)
            return
        }
        onAssetRequested(itemID) { [weak self, weak imageView] image in
            guard let self, self.renderGeneration == generation else { return }
            if let image {
                imageView?.image = image
            }
            completion?(image != nil)
        }
    }

    private static func modeText(_ mode: FreeFireModeStats?, providerUnavailable: Bool) -> String {
        guard let mode, !mode.metrics.isEmpty else {
            return providerUnavailable
                ? "No disponible por un fallo temporal del proveedor. No significa 0 partidas."
                : "El proveedor no devolvió datos para este modo. No significa 0 partidas."
        }
        return mode.metrics.map { "\($0.title): \($0.value)" }.joined(separator: "\n")
    }

    private static func formatted(_ value: String?) -> String? {
        guard let value, let number = Int64(value) else { return value }
        return NumberFormatter.localizedString(from: NSNumber(value: number), number: .decimal)
    }

    @objc private func searchTapped() {
        endEditing(true)
        let uid = (uidField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard uid.range(of: "^\\d{5,15}$", options: .regularExpression) != nil else {
            setLookupError("Escribe un UID numérico de 5 a 15 dígitos.")
            return
        }
        let regions = ["br", "sg", "ind"]
        guard regions.indices.contains(regionControl.selectedSegmentIndex) else {
            setLookupError("Selecciona la región real de la cuenta.")
            return
        }
        let region = regions[regionControl.selectedSegmentIndex]
        UserDefaults.standard.set(uid, forKey: "nyxel.last_player_uid")
        UserDefaults.standard.set(regionControl.selectedSegmentIndex, forKey: "nyxel.last_player_region")
        guard let onLookupRequested else {
            setLookupError("La consulta no está conectada al servicio.")
            return
        }
        setLookupLoading(true, message: "Validando sesión y consultando perfil…")
        onLookupRequested(uid, region)
    }

    @objc private func copyUIDTapped() {
        let value = heroUIDLabel.text?.replacingOccurrences(of: "UID  ", with: "") ?? ""
        guard !value.isEmpty, value != "—" else { return }
        UIPasteboard.general.string = value
        setLookupLoading(false, message: "UID copiado al portapapeles.")
        statusLabel.textColor = AppTheme.success
    }

    @objc private func banCheckTapped() {
        endEditing(true)
        let uid = (uidField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard uid.range(of: "^\\d{5,15}$", options: .regularExpression) != nil else {
            banCheckStatusLabel.text = "Escribe un UID numérico válido de 5 a 15 dígitos."
            banCheckStatusLabel.textColor = AppTheme.accentWarm
            return
        }
        guard let onBanCheckRequested else {
            banCheckStatusLabel.text = "La consulta Ban Check aún no está conectada."
            banCheckStatusLabel.textColor = AppTheme.accentWarm
            return
        }

        banCheckButton.isEnabled = false
        banCheckButton.alpha = 0.62
        banCheckButton.setTitle("CONSULTANDO…", for: .normal)
        banCheckStatusLabel.text = "Validando sesión de Nyxel y consultando al proveedor…"
        banCheckStatusLabel.textColor = AppTheme.readableAccent
        onBanCheckRequested(uid) { [weak self] result in
            guard let self else { return }
            self.banCheckButton.isEnabled = true
            self.banCheckButton.alpha = 1
            self.banCheckButton.setTitle("CONSULTAR ESTADO DE CUENTA", for: .normal)
            switch result {
            case .success(let result):
                if result.isBanned {
                    var message = "El proveedor reporta un baneo activo."
                    if let period = result.period {
                        message += "\nValor de período (tal como lo devuelve la API): \(period)"
                    }
                    self.banCheckStatusLabel.text = message
                    self.banCheckStatusLabel.textColor = AppTheme.accentWarm
                } else {
                    self.banCheckStatusLabel.text = "El proveedor no reporta un baneo activo. Esto no garantiza el estado oficial de la cuenta."
                    self.banCheckStatusLabel.textColor = AppTheme.success
                }
            case .failure(let error):
                self.banCheckStatusLabel.text = "No se pudo consultar: \(error.localizedDescription)"
                self.banCheckStatusLabel.textColor = AppTheme.accentWarm
            }
        }
    }
}
