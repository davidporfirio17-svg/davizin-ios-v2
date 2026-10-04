import UIKit
import NetworkExtension

/// Pantalla aislada del apartado VPN. No comparte lógica con Modos, Operación ni la inyección.
final class NyxelVPNView: UIView {
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let statusLabel = UILabel()
    private let toggleButton = DavizinButton(title: "Activar VPN", style: .primary)

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
        category.text = "VPN"
        category.font = AppTheme.captionFont()
        category.textColor = AppTheme.tertiaryText
        category.textAlignment = .center
        stack.addArrangedSubview(category)

        stack.addArrangedSubview(makeStatusCard())
        stack.addArrangedSubview(makeStepsCard())

        toggleButton.addTarget(self, action: #selector(toggleVPN), for: .touchUpInside)
        toggleButton.heightAnchor.constraint(equalToConstant: AppTheme.controlHeight).isActive = true
        stack.addArrangedSubview(toggleButton)

        let settingsButton = DavizinButton(title: "Abrir ajustes de VPN", style: .secondary)
        settingsButton.addTarget(self, action: #selector(openSettings), for: .touchUpInside)
        settingsButton.heightAnchor.constraint(equalToConstant: AppTheme.controlHeight).isActive = true
        stack.addArrangedSubview(settingsButton)

        NotificationCenter.default.addObserver(self, selector: #selector(refreshStatus), name: .NEVPNStatusDidChange, object: nil)
        NixelVPNManager.shared.load { [weak self] _ in self?.refreshStatus() }
        refreshStatus()
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func refreshStatus() {
        DispatchQueue.main.async {
            let manager = NixelVPNManager.shared
            self.statusLabel.text = NixelVPNManager.statusText(manager.status)
            self.statusLabel.textColor = manager.status == .connected ? AppTheme.success : AppTheme.warm
            self.toggleButton.setTitle(manager.isActive ? "Detener VPN" : "Activar VPN", for: .normal)
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
        title.text = "Estado"
        title.font = AppTheme.titleFont(18)
        title.textColor = AppTheme.primaryText

        statusLabel.text = "Sin configurar"
        statusLabel.font = AppTheme.bodyFont()
        statusLabel.textColor = AppTheme.warm
        statusLabel.numberOfLines = 0

        let note = UILabel()
        note.text = "Este apartado es independiente de Modos y de la inyección."
        note.font = AppTheme.bodyFont()
        note.textColor = AppTheme.secondaryText
        note.numberOfLines = 0

        let inner = UIStackView(arrangedSubviews: [title, statusLabel, note])
        inner.axis = .vertical
        inner.spacing = 8
        card.addContent(inner)
        return card
    }

    private func makeStepsCard() -> UIView {
        let card = DavizinCardView()
        let title = UILabel()
        title.text = "Vinculación"
        title.font = AppTheme.titleFont(18)
        title.textColor = AppTheme.primaryText

        let steps = [
            "1. Activar el VPN de Nyxel",
            "2. Ajustes > Privacidad y seguridad > Modo desarrollador",
            "3. Emparejar el dispositivo",
            "4. Introducir el código y volver a la app",
            "5. El dispositivo queda vinculado"
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
}
