import UIKit
import NetworkExtension
import UserNotifications

/// Pantalla de conectividad y pairing de iOS 27.
/// Mantiene la lógica existente; los detalles técnicos permanecen en Perfil > Diagnóstico.
final class NyxelVPNView: UIView {
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let statusLabel = UILabel()
    private let statusDot = UIView()
    private let toggleButton = DavizinButton(title: "Conectar", style: .primary)
    private let pairingLabel = UILabel()
    private let pairingDot = UIView()
    private let pairButton = DavizinButton(title: "Iniciar vinculación", style: .secondary)

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        addSubview(scrollView)

        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        let width = min(AppTheme.contentMaximumWidth, 520)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.centerXAnchor.constraint(equalTo: scrollView.frameLayoutGuide.centerXAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: width),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -18)
        ])
        let fill = stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -36)
        fill.priority = .defaultHigh
        fill.isActive = true

        let category = UILabel()
        category.text = "CONEXIÓN DEL DISPOSITIVO"
        category.font = AppTheme.captionFont()
        category.textColor = AppTheme.tertiaryText
        category.textAlignment = .center
        category.accessibilityTraits = .header
        stack.addArrangedSubview(category)

        stack.addArrangedSubview(makeConnectionCard())
        stack.addArrangedSubview(makePairingCard())

        toggleButton.addTarget(self, action: #selector(toggleConnection), for: .touchUpInside)
        pairButton.addTarget(self, action: #selector(beginPairing), for: .touchUpInside)

        NotificationCenter.default.addObserver(self, selector: #selector(refreshStatus), name: .NEVPNStatusDidChange, object: nil)
        NixelVPNManager.shared.load { [weak self] _ in self?.refreshStatus() }
        refreshStatus()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        // No detener la sesión al cambiar de pestaña: el pairing debe seguir vivo
        // mientras el usuario cambia de pantalla para completar la operación.
    }

    @objc private func refreshStatus() {
        DispatchQueue.main.async {
            let manager = NixelVPNManager.shared
            self.statusLabel.text = NixelVPNManager.statusText(manager.status)
            self.toggleButton.setTitle(manager.isActive ? "Desconectar" : "Conectar", for: .normal)

            switch manager.status {
            case .connected:
                self.statusLabel.textColor = AppTheme.success
                self.statusDot.backgroundColor = AppTheme.success
            case .connecting, .reasserting:
                self.statusLabel.textColor = AppTheme.warm
                self.statusDot.backgroundColor = AppTheme.warm
            case .invalid, .disconnected, .disconnecting:
                self.statusLabel.textColor = AppTheme.secondaryText
                self.statusDot.backgroundColor = AppTheme.tertiaryText
            @unknown default:
                self.statusLabel.textColor = AppTheme.secondaryText
                self.statusDot.backgroundColor = AppTheme.tertiaryText
            }
        }
    }

    @objc private func toggleConnection() {
        let manager = NixelVPNManager.shared
        if manager.isActive {
            manager.stop()
            return
        }

        statusLabel.text = "Conectando…"
        statusLabel.textColor = AppTheme.warm
        statusDot.backgroundColor = AppTheme.warm
        toggleButton.setLoading(true, title: "Conectando")
        manager.start { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.toggleButton.setLoading(false)
                switch result {
                case .success:
                    self.refreshStatus()
                case .failure(let error):
                    NyxelActivityLog.record("iOS 27 connection setup failed: \(error.localizedDescription)")
                    self.statusLabel.text = "No se pudo conectar. Revisa Perfil > Diagnóstico."
                    self.statusLabel.textColor = AppTheme.failure
                    self.statusDot.backgroundColor = AppTheme.failure
                }
            }
        }
    }

    private func makeConnectionCard() -> UIView {
        let card = DavizinCardView()
        card.contentInsets = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        let icon = UIImageView(image: UIImage(systemName: "network"))
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.contentMode = .scaleAspectFit
        icon.tintColor = AppTheme.accent
        icon.backgroundColor = AppTheme.accent.withAlphaComponent(0.12)
        icon.layer.cornerRadius = 13
        icon.layer.cornerCurve = .continuous
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 42),
            icon.heightAnchor.constraint(equalToConstant: 42)
        ])

        let title = UILabel()
        title.text = "Conexión de red"
        title.font = AppTheme.titleFont(18)
        title.textColor = AppTheme.primaryText

        let subtitle = UILabel()
        subtitle.text = "Canal local para completar la vinculación."
        subtitle.font = AppTheme.bodyFont()
        subtitle.textColor = AppTheme.secondaryText
        subtitle.numberOfLines = 2

        let heading = UIStackView(arrangedSubviews: [icon, title])
        heading.axis = .horizontal
        heading.alignment = .center
        heading.spacing = 12

        statusDot.translatesAutoresizingMaskIntoConstraints = false
        statusDot.layer.cornerRadius = 4
        NSLayoutConstraint.activate([
            statusDot.widthAnchor.constraint(equalToConstant: 8),
            statusDot.heightAnchor.constraint(equalToConstant: 8)
        ])
        statusLabel.text = "No configurado"
        statusLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        statusLabel.textColor = AppTheme.secondaryText
        statusLabel.numberOfLines = 2
        let statusRow = UIStackView(arrangedSubviews: [statusDot, statusLabel])
        statusRow.axis = .horizontal
        statusRow.alignment = .center
        statusRow.spacing = 9

        toggleButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        let settingsButton = DavizinButton(title: "Ajustes de la app", style: .secondary)
        settingsButton.heightAnchor.constraint(equalToConstant: 46).isActive = true
        settingsButton.addTarget(self, action: #selector(openSettings), for: .touchUpInside)

        let inner = UIStackView(arrangedSubviews: [heading, subtitle, statusRow, toggleButton, settingsButton])
        inner.axis = .vertical
        inner.spacing = 13
        card.addContent(inner)
        return card
    }

    private func makePairingCard() -> UIView {
        let card = DavizinCardView()
        card.contentInsets = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        let title = UILabel()
        title.text = "Vinculación"
        title.font = AppTheme.titleFont(18)
        title.textColor = AppTheme.primaryText

        let identifier = UILabel()
        identifier.text = "2424"
        identifier.font = .systemFont(ofSize: 11, weight: .bold)
        identifier.textColor = AppTheme.accent
        identifier.textAlignment = .center
        identifier.backgroundColor = AppTheme.accent.withAlphaComponent(0.12)
        identifier.layer.cornerRadius = 9
        identifier.layer.cornerCurve = .continuous
        identifier.clipsToBounds = true
        identifier.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            identifier.widthAnchor.constraint(greaterThanOrEqualToConstant: 48),
            identifier.heightAnchor.constraint(equalToConstant: 28)
        ])

        let header = UIStackView(arrangedSubviews: [title, UIView(), identifier])
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = 8

        let subtitle = UILabel()
        subtitle.text = "Confirma la solicitud en Ajustes. El código llega en una notificación temporal."
        subtitle.font = AppTheme.bodyFont()
        subtitle.textColor = AppTheme.secondaryText
        subtitle.numberOfLines = 0

        pairingDot.translatesAutoresizingMaskIntoConstraints = false
        pairingDot.layer.cornerRadius = 4
        pairingDot.backgroundColor = AppTheme.tertiaryText
        NSLayoutConstraint.activate([
            pairingDot.widthAnchor.constraint(equalToConstant: 8),
            pairingDot.heightAnchor.constraint(equalToConstant: 8)
        ])
        pairingLabel.text = "Listo para iniciar"
        pairingLabel.font = .systemFont(ofSize: 13, weight: .medium)
        pairingLabel.textColor = AppTheme.secondaryText
        pairingLabel.numberOfLines = 2
        let pairingStatus = UIStackView(arrangedSubviews: [pairingDot, pairingLabel])
        pairingStatus.axis = .horizontal
        pairingStatus.alignment = .center
        pairingStatus.spacing = 9

        pairButton.heightAnchor.constraint(equalToConstant: 48).isActive = true

        let inner = UIStackView(arrangedSubviews: [header, subtitle, pairingStatus, pairButton])
        inner.axis = .vertical
        inner.spacing = 13
        card.addContent(inner)
        return card
    }

    @objc private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    @objc private func beginPairing() {
        pairButton.setLoading(true, title: "Preparando…")
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.pairButton.setLoading(false)
                self?.startPairingSession()
            }
        }
    }

    private func startPairingSession() {
        pairingLabel.text = "Preparando vinculación…"
        pairingDot.backgroundColor = AppTheme.warm
        NixelPairingSession.shared.begin { [weak self] state in
            DispatchQueue.main.async {
                guard let self else { return }
                self.pairingLabel.text = self.concisePairingMessage(for: state)
                switch state {
                case .failed:
                    self.pairingLabel.textColor = AppTheme.failure
                    self.pairingDot.backgroundColor = AppTheme.failure
                case .ready, .paired:
                    self.pairingLabel.textColor = AppTheme.success
                    self.pairingDot.backgroundColor = AppTheme.success
                case .pairingRequired:
                    self.pairingLabel.textColor = AppTheme.accent
                    self.pairingDot.backgroundColor = AppTheme.accent
                default:
                    self.pairingLabel.textColor = AppTheme.secondaryText
                    self.pairingDot.backgroundColor = AppTheme.warm
                }
            }
        }
    }

    private func concisePairingMessage(for state: NixelPairingSessionState) -> String {
        switch state {
        case .idle:
            return "Listo para iniciar"
        case .searching:
            return "Preparando vinculación…"
        case .serviceDetected:
            return "Dispositivo detectado"
        case .transportReachable:
            return "Conexión disponible"
        case .pairingRecordFound:
            return "Registro encontrado"
        case .pairingRequired:
            return "Revisa la notificación para el código"
        case .paired:
            return "Dispositivo vinculado"
        case .developerModeRequired:
            return "Confirma la solicitud en Ajustes"
        case .ready:
            return "Vinculación lista"
        case .failed:
            return "No se completó. Revisa Perfil > Diagnóstico."
        }
    }
}
