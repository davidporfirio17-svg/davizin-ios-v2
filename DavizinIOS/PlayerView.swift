import UIKit

final class PlayerView: UIView {
    var onLookupRequested: ((String, String) -> Void)?
    var onAssetRequested: ((String, @escaping (UIImage?) -> Void) -> Void)?

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
    private let clanLabel = UILabel()
    private let signatureLabel = UILabel()
    private let outfitImages = (0..<4).map { _ in UIImageView() }
    private let outfitPlaceholders = (0..<4).map { _ in UILabel() }

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
        copyUIDButton.isHidden = summary.uid.isEmpty
        heroLevelPill.text = summary.level.map { "NIVEL \($0)" } ?? "PERFIL PÚBLICO"
        heroRegionPill.text = summary.region?.uppercased() ?? "FREE FIRE"

        levelValueLabel.text = summary.level ?? "—"
        likesValueLabel.text = Self.formatted(summary.likes) ?? "—"
        seasonValueLabel.text = summary.season ?? "—"

        brPointsLabel.text = Self.formatted(summary.brPoints) ?? "—"
        brCodeLabel.text = "Rango / código  \(summary.brRankCode ?? "—")"
        brSeasonLabel.text = summary.season.map { "Temporada \($0) · dato del API" } ?? "Puntos de Battle Royale"
        csPointsLabel.text = Self.formatted(summary.csPoints) ?? "—"
        csCodeLabel.text = "Rango / código  \(summary.csRankCode ?? "—")"
        csSeasonLabel.text = summary.season.map { "Temporada \($0) · dato del API" } ?? "Puntos de Clash Squad"

        let statsByKey = Dictionary(uniqueKeysWithValues: summary.modes.map { ($0.key, $0) })
        soloStatsLabel.text = Self.modeText(statsByKey["brCareer_solo"])
        duoStatsLabel.text = Self.modeText(statsByKey["brCareer_duo"])
        squadStatsLabel.text = Self.modeText(statsByKey["brCareer_squad"])

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
        for index in outfitImages.indices {
            let itemID = summary.clothesIDs.indices.contains(index) ? summary.clothesIDs[index] : nil
            outfitPlaceholders[index].text = itemID == nil ? "—" : "ROPA \(index + 1)"
            requestAsset(itemID, into: outfitImages[index], generation: generation)
        }
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
        contentStack.addArrangedSubview(sectionHeading("RANGOS Y PUNTOS", subtitle: "Códigos y valores tal como los entrega el API"))
        contentStack.addArrangedSubview(rankRow)

        let modeRow = row([
            makeModeCard(title: "SOLO", symbol: "person.fill", label: soloStatsLabel),
            makeModeCard(title: "DÚO", symbol: "person.2.fill", label: duoStatsLabel),
            makeModeCard(title: "ESCUADRA", symbol: "person.3.fill", label: squadStatsLabel)
        ], axis: isPad ? .horizontal : .vertical)
        contentStack.addArrangedSubview(sectionHeading("ESTADÍSTICAS DE CARRERA", subtitle: "Solo, dúo y escuadra · cuando el proveedor las devuelve"))
        contentStack.addArrangedSubview(modeRow)

        contentStack.addArrangedSubview(sectionHeading("CLAN Y PERFIL", subtitle: "Información pública asociada al UID"))
        contentStack.addArrangedSubview(makeInfoCard(title: "CLAN", symbol: "person.3.sequence.fill", label: clanLabel))
        contentStack.addArrangedSubview(makeInfoCard(title: "FIRMA", symbol: "quote.opening", label: signatureLabel))

        contentStack.addArrangedSubview(sectionHeading("ROPA Y ASSETS", subtitle: "Imágenes reales cargadas desde el servicio oficial de assets del API"))
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
        let cells: [UIView] = outfitImages.indices.map { index in
            let cell = UIView()
            cell.translatesAutoresizingMaskIntoConstraints = false
            cell.backgroundColor = AppTheme.background.withAlphaComponent(0.52)
            cell.layer.cornerRadius = 14
            cell.layer.borderWidth = 1
            cell.layer.borderColor = AppTheme.hairlineStrong.cgColor
            cell.clipsToBounds = true

            let image = outfitImages[index]
            image.translatesAutoresizingMaskIntoConstraints = false
            image.contentMode = .scaleAspectFit
            image.image = UIImage(systemName: "tshirt.fill")
            image.tintColor = AppTheme.tertiaryText
            cell.addSubview(image)

            let caption = outfitPlaceholders[index]
            caption.translatesAutoresizingMaskIntoConstraints = false
            caption.font = .systemFont(ofSize: 8, weight: .bold)
            caption.textColor = AppTheme.tertiaryText
            caption.textAlignment = .center
            cell.addSubview(caption)

            NSLayoutConstraint.activate([
                cell.heightAnchor.constraint(equalToConstant: isPad ? 110 : 88),
                image.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 5),
                image.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -5),
                image.topAnchor.constraint(equalTo: cell.topAnchor, constant: 5),
                image.bottomAnchor.constraint(equalTo: caption.topAnchor, constant: -2),
                caption.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                caption.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -2),
                caption.bottomAnchor.constraint(equalTo: cell.bottomAnchor, constant: -5),
                caption.heightAnchor.constraint(equalToConstant: 11)
            ])
            return cell
        }
        let assets = UIStackView(arrangedSubviews: cells)
        assets.axis = .horizontal
        assets.distribution = .fillEqually
        assets.alignment = .fill
        assets.spacing = 9
        let note = label("Las miniaturas pueden tardar un momento en cargar.", size: 10, weight: .regular, color: AppTheme.secondaryText)
        let stack = UIStackView(arrangedSubviews: [assets, note])
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

    private func requestAsset(_ itemID: String?, into imageView: UIImageView, generation: Int) {
        guard let itemID, !itemID.isEmpty else {
            imageView.image = UIImage(systemName: imageView === avatarImageView ? "person.crop.square.fill" : "sparkles")
            return
        }
        imageView.image = UIImage(systemName: imageView === avatarImageView ? "person.crop.square.fill" : "photo")
        guard let onAssetRequested else { return }
        onAssetRequested(itemID) { [weak self, weak imageView] image in
            guard let self, self.renderGeneration == generation, let image else { return }
            imageView?.image = image
        }
    }

    private static func modeText(_ mode: FreeFireModeStats?) -> String {
        guard let mode, !mode.metrics.isEmpty else { return "El proveedor no devolvió estadísticas para este modo." }
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
}
