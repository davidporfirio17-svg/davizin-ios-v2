import UIKit
import NetworkExtension

/// Pantalla aislada del apartado VPN. No comparte lógica con Modos, Operación ni la inyección.
final class NyxelVPNView: UIView {
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let accessStatusLabel = UILabel()
    private let keyValueLabel = UILabel()
    private let remainingValueLabel = UILabel()
    private let statusLabel = UILabel()
    private let pairingLabel = UILabel()
    private let compatibilityLabel = UILabel()
    private let pairingLogLabel = UILabel()
    private let toggleButton = DavizinButton(title: "Activar VPN", style: .primary)
    private let pairButton = DavizinButton(title: "Emparejar (publicar 2424)", style: .secondary)
    private var activeKey: String?
    private var accessExpiresAt: Date?
    private var accessTimer: Timer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    func setAccount(key: String?, remainingSeconds: Int) {
        activeKey = key
        accessExpiresAt = key != nil && remainingSeconds > 0
            ? Date().addingTimeInterval(TimeInterval(remainingSeconds))
            : nil
        updateAccessSummary()
        accessTimer?.invalidate()
        guard accessExpiresAt != nil else { return }
        accessTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateAccessSummary()
        }
    }

    private func configure() {
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        addSubview(scrollView)

        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        let width = min(AppTheme.contentMaximumWidth, 520)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -20),
            stack.centerXAnchor.constraint(equalTo: scrollView.frameLayoutGuide.centerXAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: width),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -18)
        ])
        let fill = stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -36)
        fill.priority = .defaultHigh
        fill.isActive = true

        let category = UILabel()
        category.text = "ESTADO DEL DISPOSITIVO"
        category.font = AppTheme.captionFont()
        category.textColor = AppTheme.accent
        category.textAlignment = .center
        stack.addArrangedSubview(category)

        stack.addArrangedSubview(makeAccessCard())
        stack.addArrangedSubview(makeStatusCard())

        toggleButton.addTarget(self, action: #selector(toggleVPN), for: .touchUpInside)
        toggleButton.heightAnchor.constraint(equalToConstant: AppTheme.controlHeight).isActive = true
        stack.addArrangedSubview(toggleButton)

        let settingsButton = DavizinButton(title: "Abrir ajustes de VPN", style: .secondary)
        settingsButton.addTarget(self, action: #selector(openSettings), for: .touchUpInside)
        settingsButton.heightAnchor.constraint(equalToConstant: AppTheme.controlHeight).isActive = true
        stack.addArrangedSubview(settingsButton)

        stack.addArrangedSubview(makePairingCard())
        stack.addArrangedSubview(makeStepsCard())

        NotificationCenter.default.addObserver(self, selector: #selector(refreshStatus), name: .NEVPNStatusDidChange, object: nil)
        NixelVPNManager.shared.load { [weak self] _ in self?.refreshStatus() }
        refreshCompatibility()
        refreshStatus()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        accessTimer?.invalidate()
        // Ojo: NO detener NixelPairingSession aquí. El usuario sale de esta
        // pestaña para ir a inyectar — si apagamos el host de emparejamiento
        // al cambiar de pestaña, el dispositivo pierde la sesión justo antes
        // de necesitarla para abrir el túnel AFC.
    }

    private func makeAccessCard() -> UIView {
        let card = DavizinCardView()
        let title = UILabel()
        title.text = "Acceso Nyxel"
        title.font = AppTheme.titleFont(18)
        title.textColor = AppTheme.primaryText

        accessStatusLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        accessStatusLabel.numberOfLines = 0
        keyValueLabel.font = AppTheme.monoFont(13)
        keyValueLabel.textColor = AppTheme.primaryText
        remainingValueLabel.font = AppTheme.monoFont(13)
        remainingValueLabel.textColor = AppTheme.accent

        let inner = UIStackView(arrangedSubviews: [
            title,
            makeInfoRow(title: "Estado de acceso", value: accessStatusLabel),
            makeInfoRow(title: "Clave", value: keyValueLabel),
            makeInfoRow(title: "Vigencia", value: remainingValueLabel)
        ])
        inner.axis = .vertical
        inner.spacing = 10
        card.addContent(inner)
        updateAccessSummary()
        return card
    }

    private func makeInfoRow(title: String, value: UILabel) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = AppTheme.bodyFont()
        titleLabel.textColor = AppTheme.secondaryText
        titleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [titleLabel, value])
        row.axis = .horizontal
        row.alignment = .firstBaseline
        row.distribution = .equalSpacing
        row.spacing = 12
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 11, left: 12, bottom: 11, right: 12)
        row.backgroundColor = AppTheme.accent.withAlphaComponent(0.055)
        row.layer.cornerRadius = 13
        row.layer.borderWidth = 1
        row.layer.borderColor = AppTheme.hairline.cgColor
        return row
    }

    private func updateAccessSummary() {
        let remaining = accessExpiresAt.map { max(0, Int($0.timeIntervalSinceNow)) } ?? 0
        let isActive = activeKey != nil && remaining > 0
        accessStatusLabel.text = activeKey == nil ? "Sin validar" : (isActive ? "Activa" : "Expirada")
        accessStatusLabel.textColor = isActive ? AppTheme.success : AppTheme.warm
        keyValueLabel.text = maskedKey(activeKey)
        if isActive {
            let days = remaining / 86_400
            let hours = (remaining % 86_400) / 3_600
            let minutes = (remaining % 3_600) / 60
            remainingValueLabel.text = "\(days)d · \(hours)h · \(minutes)m restantes"
            remainingValueLabel.textColor = AppTheme.accent
        } else {
            remainingValueLabel.text = activeKey == nil ? "—" : "Vencida"
            remainingValueLabel.textColor = AppTheme.failure
        }
    }

    private func maskedKey(_ key: String?) -> String {
        guard let key, !key.isEmpty else { return "No disponible" }
        guard key.count > 4 else { return "••••" }
        return "••••-\(key.suffix(4))"
    }

    @objc private func refreshStatus() {
        DispatchQueue.main.async {
            let manager = NixelVPNManager.shared
            let connected = manager.status == .connected
            self.statusLabel.text = NixelVPNManager.statusText(manager.status)
            self.statusLabel.textColor = connected ? AppTheme.success : AppTheme.warm
            self.toggleButton.setTitle(manager.isActive ? "Detener VPN" : "Activar VPN", for: .normal)
        }
    }

    private func refreshCompatibility() {
        let version = NyxelDeviceInfo.versionTuple
        let systemVersion = NyxelDeviceInfo.osVersion
        if version.major >= 27 {
            compatibilityLabel.text = "iOS \(systemVersion) · pairing directo"
            compatibilityLabel.textColor = AppTheme.success
        } else {
            compatibilityLabel.text = "iOS \(systemVersion) · VPN de apoyo"
            compatibilityLabel.textColor = AppTheme.accent
        }
    }

    @objc private func toggleVPN() {
        let manager = NixelVPNManager.shared
        if manager.isActive {
            manager.stop()
            return
        }
        statusLabel.text = "Activando…"
        manager.start { [weak self] result in
            DispatchQueue.main.async {
                if case .failure(let error) = result {
                    self?.statusLabel.text = "No se pudo activar: \(error.localizedDescription)"
                    self?.statusLabel.textColor = AppTheme.failure
                } else {
                    self?.refreshStatus()
                }
            }
        }
    }

    private func makeStatusCard() -> UIView {
        let card = DavizinCardView()
        let title = UILabel()
        title.text = "Emparejamiento y túnel"
        title.font = AppTheme.titleFont(18)
        title.textColor = AppTheme.primaryText

        statusLabel.text = "No configurado"
        statusLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        statusLabel.textColor = AppTheme.warm
        statusLabel.numberOfLines = 0

        pairingLabel.text = "Aún no iniciado"
        pairingLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        pairingLabel.textColor = AppTheme.secondaryText
        pairingLabel.numberOfLines = 0

        compatibilityLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        compatibilityLabel.numberOfLines = 0

        let note = UILabel()
        note.text = "Los indicadores reflejan el estado detectado por Nyxel; el pairing se confirma cuando el dispositivo completa la autenticación."
        note.font = AppTheme.bodyFont()
        note.textColor = AppTheme.secondaryText
        note.numberOfLines = 0

        let inner = UIStackView(arrangedSubviews: [
            title,
            makeStatusRow(icon: "network", title: "Conexión del túnel", value: statusLabel),
            makeStatusRow(icon: "checkmark.circle", title: "Estado del emparejamiento", value: pairingLabel),
            makeStatusRow(icon: "iphone.gen3", title: "Sistema detectado", value: compatibilityLabel),
            note
        ])
        inner.axis = .vertical
        inner.spacing = 10
        card.addContent(inner)
        return card
    }

    private func makeStatusRow(icon: String, title: String, value: UILabel) -> UIView {
        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = AppTheme.accent
        iconView.contentMode = .scaleAspectFit
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20)
        ])

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = AppTheme.bodyFont()
        titleLabel.textColor = AppTheme.primaryText
        titleLabel.numberOfLines = 0

        let texts = UIStackView(arrangedSubviews: [titleLabel, value])
        texts.axis = .vertical
        texts.spacing = 3

        let row = UIStackView(arrangedSubviews: [iconView, texts])
        row.axis = .horizontal
        row.alignment = .top
        row.spacing = 10
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        row.backgroundColor = AppTheme.accent.withAlphaComponent(0.055)
        row.layer.cornerRadius = 13
        row.layer.borderWidth = 1
        row.layer.borderColor = AppTheme.hairline.cgColor
        return row
    }

    private func makeStepsCard() -> UIView {
        let card = DavizinCardView()
        let title = UILabel()
        title.text = "Guía de emparejamiento"
        title.font = AppTheme.titleFont(18)
        title.textColor = AppTheme.primaryText

        let steps = [
            "1. Activa el VPN de Nyxel.",
            "2. Abre Ajustes > Privacidad y seguridad > Modo desarrollador.",
            "3. Inicia el emparejamiento desde el botón de esta pantalla.",
            "4. Introduce en iOS el código que Nyxel muestra aquí.",
            "5. Espera a que el estado indique que el pairing está listo."
        ]
        var views: [UIView] = [title]
        for text in steps {
            let label = UILabel()
            label.text = text
            label.font = AppTheme.bodyFont()
            label.textColor = AppTheme.secondaryText
            label.numberOfLines = 0
            views.append(label)
        }
        let inner = UIStackView(arrangedSubviews: views)
        inner.axis = .vertical
        inner.spacing = 8
        card.addContent(inner)
        return card
    }

    @objc private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func makePairingCard() -> UIView {
        let card = DavizinCardView()
        let title = UILabel()
        title.text = "Vincular dispositivo · 2424"
        title.font = AppTheme.titleFont(18)
        title.textColor = AppTheme.primaryText

        pairingLogLabel.font = AppTheme.monoFont(10)
        pairingLogLabel.textColor = AppTheme.tertiaryText
        pairingLogLabel.numberOfLines = 0
        pairingLogLabel.lineBreakMode = .byWordWrapping

        pairButton.addTarget(self, action: #selector(beginPairing), for: .touchUpInside)
        pairButton.heightAnchor.constraint(equalToConstant: AppTheme.controlHeight).isActive = true

        let pinHint = UILabel()
        pinHint.text = "Cuando iOS solicite un código, introdúcelo en el diálogo del sistema. Nyxel mostrará el PIN y el resultado aquí."
        pinHint.font = AppTheme.bodyFont()
        pinHint.textColor = AppTheme.secondaryText
        pinHint.numberOfLines = 0

        let inner = UIStackView(arrangedSubviews: [title, pairButton, pinHint, pairingLogLabel])
        inner.axis = .vertical
        inner.spacing = 10
        card.addContent(inner)
        return card
    }

    @objc private func beginPairing() {
        pairingLogLabel.text = ""
        NixelHybridCoordinator.start { [weak self] result in
            DispatchQueue.main.async {
                if case .failure(let error) = result {
                    self?.pairingLabel.text = "VPN no disponible: \(error.localizedDescription)"
                    self?.pairingLabel.textColor = AppTheme.failure
                    return
                }
                self?.startPairingSession()
            }
        }
    }

    private func startPairingSession() {
        NixelPairingSession.shared.begin { [weak self] state in
            guard let self else { return }
            self.pairingLabel.text = state.message
            switch state {
            case .failed:
                self.pairingLabel.textColor = AppTheme.failure
            case .ready, .paired:
                self.pairingLabel.textColor = AppTheme.success
            case .pairingRequired:
                self.pairingLabel.textColor = AppTheme.accent
            default:
                self.pairingLabel.textColor = AppTheme.secondaryText
            }
            let previous = self.pairingLogLabel.text.map { $0 + "\n" } ?? ""
            self.pairingLogLabel.text = (previous + state.message).suffix(2000).description
        }
    }
}
