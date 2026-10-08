import UIKit
import NetworkExtension

/// Pantalla de diagnóstico y conexión inspirada en Settings de SupportPatch.
/// Todos los estados se derivan de APIs locales; no marca un build como soportado
/// si NyxelSupportPolicy no lo verifica.
final class NixleSettingsView: UIView {
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let tunnelValue = UILabel()
    private let pairingValue = UILabel()
    private let compatibilityValue = UILabel()
    private let pluginValue = UILabel()
    private let pairingMessage = UILabel()
    private let pairButton = DavizinButton(title: "Pair on this iPhone", style: .secondary)
    private let importButton = DavizinButton(title: "Import pairing file", style: .secondary)
    private let deleteButton = DavizinButton(title: "Delete pairing file", style: .destructive)
    private var documentPicker: UIDocumentPickerViewController?

    override init(frame: CGRect) { super.init(frame: frame); configure() }
    required init?(coder: NSCoder) { super.init(coder: coder); configure() }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        addSubview(scrollView)
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        let maxWidth = UIDevice.current.userInterfaceIdiom == .pad ? 680.0 : AppTheme.contentMaximumWidth
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 18),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.centerXAnchor.constraint(equalTo: scrollView.frameLayoutGuide.centerXAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: maxWidth),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20)
        ])
        let fill = stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40)
        fill.priority = .defaultHigh
        fill.isActive = true

        let appCard = makeCard(title: "TRY STORE", subtitle: "NIXLE EXTERNAL")
        stack.addArrangedSubview(appCard)
        stack.addArrangedSubview(makeDeviceCard())
        stack.addArrangedSubview(makeConnectionCard())
        stack.addArrangedSubview(makeCompatibilityCard())
        stack.addArrangedSubview(makeSocialCard())

        pairButton.addTarget(self, action: #selector(pairTapped), for: .touchUpInside)
        importButton.addTarget(self, action: #selector(importTapped), for: .touchUpInside)
        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: .NEVPNStatusDidChange, object: nil)
        refresh()
        NixelVPNManager.shared.load { [weak self] _ in self?.refresh() }
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    private func makeCard(title: String, subtitle: String) -> UIView {
        let card = DavizinCardView()
        let titleLabel = UILabel(); titleLabel.text = title; titleLabel.font = AppTheme.titleFont(17); titleLabel.textColor = AppTheme.primaryText
        let sub = UILabel(); sub.text = subtitle; sub.font = AppTheme.monoFont(10); sub.textColor = AppTheme.secondaryText
        let content = UIStackView(arrangedSubviews: [titleLabel, sub]); content.axis = .vertical; content.spacing = 4
        card.addContent(content)
        return card
    }

    private func makeDeviceCard() -> UIView {
        let card = DavizinCardView()
        let title = sectionTitle("Device")
        let model = makeRow("Hardware model", value: NyxelDeviceInfo.displayMachineName)
        let version = makeRow("iOS Version", value: NyxelSupportPolicy.currentSystemDescription)
        let content = UIStackView(arrangedSubviews: [title, model, version]); content.axis = .vertical; content.spacing = 10
        card.addContent(content)
        return card
    }

    private func makeConnectionCard() -> UIView {
        let card = DavizinCardView()
        let title = sectionTitle("Pairing & Tunnel")
        configureStatus(tunnelValue); configureStatus(pairingValue)
        let tunnel = makeStatusRow("Tunnel connection", value: tunnelValue)
        let pairing = makeStatusRow("Pairing status", value: pairingValue)
        pairingMessage.text = "En iOS 27, el pairing directo depende del build y del handshake real. Las demás versiones pueden importar un pairing file."
        pairingMessage.font = AppTheme.bodyFont(); pairingMessage.textColor = AppTheme.secondaryText; pairingMessage.numberOfLines = 0
        let content = UIStackView(arrangedSubviews: [title, tunnel, pairing, pairingMessage, pairButton, importButton, deleteButton])
        content.axis = .vertical; content.spacing = 10
        card.addContent(content)
        return card
    }

    private func makeCompatibilityCard() -> UIView {
        let card = DavizinCardView()
        let title = sectionTitle("Verified versions")
        configureStatus(compatibilityValue)
        let compatibility = makeStatusRow("Exploit compatibility", value: compatibilityValue)
        let versions = ["iOS 17  ·  17.0–17.7.2", "iOS 18  ·  18.0–18.7.10", "iOS 26  ·  26.0–26.7.0", "iOS 27  ·  27.0 beta verificado y 27.2"]
        let labels = versions.map { makePlainRow($0) }
        let footer = UILabel(); footer.text = "Solo los builds exactos declarados por la política local aparecen como verificados."; footer.font = .systemFont(ofSize: 11); footer.textColor = AppTheme.tertiaryText; footer.numberOfLines = 0
        let content = UIStackView(arrangedSubviews: [title, compatibility] + labels + [footer]); content.axis = .vertical; content.spacing = 9
        card.addContent(content)
        return card
    }

    private func makeSocialCard() -> UIView {
        let card = DavizinCardView()
        let title = sectionTitle("Support")
        let note = UILabel(); note.text = "Estado local del conector, plugin ExternalTunnel y pairing 2424"; note.font = AppTheme.bodyFont(); note.textColor = AppTheme.secondaryText; note.numberOfLines = 0
        let content = UIStackView(arrangedSubviews: [title, note]); content.axis = .vertical; content.spacing = 9
        card.addContent(content)
        return card
    }

    private func sectionTitle(_ text: String) -> UILabel { let label = UILabel(); label.text = text; label.font = AppTheme.titleFont(18); label.textColor = AppTheme.primaryText; return label }
    private func makeRow(_ name: String, value: String) -> UIView {
        let left = UILabel(); left.text = name; left.font = AppTheme.bodyFont(); left.textColor = AppTheme.secondaryText
        let right = UILabel(); right.text = value; right.font = AppTheme.monoFont(11); right.textColor = AppTheme.primaryText; right.textAlignment = .right; right.numberOfLines = 0
        let row = UIStackView(arrangedSubviews: [left, right]); row.axis = .horizontal; row.alignment = .center; row.distribution = .equalSpacing
        return row
    }
    private func makePlainRow(_ text: String) -> UIView {
        let row = UILabel(); row.text = "›  \(text)"; row.font = AppTheme.bodyFont(); row.textColor = AppTheme.secondaryText; return row
    }
    private func makeStatusRow(_ name: String, value: UILabel) -> UIView {
        let left = UILabel(); left.text = name; left.font = AppTheme.bodyFont(); left.textColor = AppTheme.secondaryText
        let row = UIStackView(arrangedSubviews: [left, value]); row.axis = .horizontal; row.alignment = .center; row.distribution = .equalSpacing; return row
    }
    private func configureStatus(_ label: UILabel) { label.font = AppTheme.monoFont(12); label.textAlignment = .right; label.numberOfLines = 0; label.setContentCompressionResistancePriority(.required, for: .horizontal) }

    @objc private func refresh() {
        DispatchQueue.main.async {
            let manager = NixelVPNManager.shared
            let connected = manager.status == .connected
            self.tunnelValue.text = connected ? "● Connected" : "○ \(NixelVPNManager.statusText(manager.status))"
            self.tunnelValue.textColor = connected ? AppTheme.success : AppTheme.warm
            let ready = NixelPairingRecordStore.shared.load(deviceID: "2424") != nil
            self.pairingValue.text = ready ? "● Ready" : "○ Missing"
            self.pairingValue.textColor = ready ? AppTheme.success : AppTheme.warm
            let supported = NyxelSupportPolicy.isCurrentSystemSupported
            self.compatibilityValue.text = supported ? "● Supported by policy" : "○ Build not verified"
            self.compatibilityValue.textColor = supported ? AppTheme.success : AppTheme.failure
            self.deleteButton.isEnabled = ready
            self.deleteButton.alpha = ready ? 1 : 0.45
        }
    }

    @objc private func pairTapped() {
        pairingMessage.text = "Publicando host 2424 y esperando el handshake…"
        NixelPairingSession.shared.begin { [weak self] state in
            self?.pairingMessage.text = state.message
            self?.refresh()
        }
    }

    @objc private func importTapped() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.data], asCopy: true)
        picker.delegate = self
        documentPicker = picker
        owningViewController?.present(picker, animated: true)
    }

    @objc private func deleteTapped() {
        NixelPairingRecordStore.shared.remove(deviceID: "2424")
        pairingMessage.text = "Registro de pairing eliminado de este dispositivo."
        refresh()
    }

    private var owningViewController: UIViewController? {
        var responder: UIResponder? = self
        while let current = responder {
            if let controller = current as? UIViewController { return controller }
            responder = current.next
        }
        return nil
    }
}

extension NixleSettingsView: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        do {
            let data = try Data(contentsOf: url)
            try NixelPairingRecordStore.shared.save(data, deviceID: "2424")
            pairingMessage.text = "Pairing file importado y guardado en Keychain."
            refresh()
        } catch {
            pairingMessage.text = "No se pudo importar el pairing file: \(error.localizedDescription)"
        }
    }
}
