import UIKit

/// Prototipo de consulta de perfil Free Fire.
/// La consulta remota es solo para pruebas; en producción debe pasar por un Worker propio.
final class FreeFireTestViewController: UIViewController {
    private let uidField = UITextField()
    private let regionField = UITextField()
    private let demoSwitch = UISwitch()
    private let resultLabel = UILabel()
    private let queryButton = UIButton(type: .system)
    private let scrollView = UIScrollView()
    private let content = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Free Fire API — Prueba"
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(closeTapped))
        configureUI()
    }

    private func configureUI() {
        let heading = UILabel()
        heading.text = "CONSULTA DE PERFIL"
        heading.font = .systemFont(ofSize: 22, weight: .bold)
        heading.textColor = .label
        heading.textAlignment = .center

        let description = UILabel()
        description.text = "Prueba de lectura por UID. No modifica la cuenta ni ejecuta ninguna acción del juego."
        description.font = .preferredFont(forTextStyle: .body)
        description.textColor = .secondaryLabel
        description.numberOfLines = 0
        description.textAlignment = .center

        configureField(uidField, placeholder: "UID del jugador", keyboard: .numberPad)
        configureField(regionField, placeholder: "Región (BR, US, SG...)", keyboard: .asciiCapable)
        regionField.text = "BR"

        let demoRow = UIStackView()
        demoRow.axis = .horizontal
        demoRow.alignment = .center
        demoRow.spacing = 10
        let demoLabel = UILabel()
        demoLabel.text = "Usar datos demo"
        demoLabel.textColor = .label
        demoLabel.font = .preferredFont(forTextStyle: .body)
        demoRow.addArrangedSubview(demoLabel)
        demoRow.addArrangedSubview(UIView())
        demoRow.addArrangedSubview(demoSwitch)
        demoSwitch.isOn = true

        queryButton.setTitle("CONSULTAR PERFIL", for: .normal)
        queryButton.setTitleColor(.white, for: .normal)
        queryButton.backgroundColor = .systemBlue
        queryButton.layer.cornerRadius = 10
        queryButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .bold)
        queryButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
        queryButton.addTarget(self, action: #selector(queryTapped), for: .touchUpInside)

        resultLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        resultLabel.textColor = .secondaryLabel
        resultLabel.numberOfLines = 0
        resultLabel.text = "Selecciona datos demo para ver el formato de respuesta."

        content.axis = .vertical
        content.spacing = 14
        content.translatesAutoresizingMaskIntoConstraints = false
        [heading, description, uidField, regionField, demoRow, queryButton, resultLabel].forEach { content.addArrangedSubview($0) }

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(content)
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 22),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -22),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 18),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            content.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            content.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }

    private func configureField(_ field: UITextField, placeholder: String, keyboard: UIKeyboardType) {
        field.placeholder = placeholder
        field.keyboardType = keyboard
        field.textColor = .label
        field.font = .preferredFont(forTextStyle: .body)
        field.backgroundColor = .secondarySystemBackground
        field.layer.cornerRadius = 10
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.secondaryLabel.withAlphaComponent(0.25).cgColor
        field.heightAnchor.constraint(equalToConstant: 48).isActive = true
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
        field.leftViewMode = .always
        field.autocorrectionType = .no
        field.autocapitalizationType = .allCharacters
    }

    @objc private func queryTapped() {
        view.endEditing(true)
        let uid = uidField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let region = (regionField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? regionField.text! : "BR").uppercased()
        guard demoSwitch.isOn || (uid.allSatisfy(\.isNumber) && uid.count >= 6) else {
            resultLabel.textColor = .systemRed
            resultLabel.text = "NYX-FF-001\nUID inválido. Usa solamente números."
            return
        }

        queryButton.isEnabled = false
        resultLabel.textColor = .systemOrange
        resultLabel.text = "Consultando perfil…"

        if demoSwitch.isOn {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.queryButton.isEnabled = true
                self?.renderDemo(uid: uid.isEmpty ? "1234567890" : uid, region: region)
            }
        } else {
            FreeFireTestAPI.fetchProfile(uid: uid, region: region) { [weak self] result in
                DispatchQueue.main.async {
                    self?.queryButton.isEnabled = true
                    switch result {
                    case .success(let profile): self?.render(profile)
                    case .failure(let error):
                        self?.resultLabel.textColor = .systemRed
                        self?.resultLabel.text = "NYX-FF-002\nNo se pudo consultar: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    private func renderDemo(uid: String, region: String) {
        render(FreeFireTestProfile(uid: uid, nickname: "NyxelDemo", region: region, level: 67, likes: 2303, brRank: 321, csRank: 309, guild: "Nyxel Test Guild", clothes: [205000051, 211000579, 214000022, 203001159, 204000581]))
    }

    private func render(_ profile: FreeFireTestProfile) {
        resultLabel.textColor = .secondaryLabel
        let clothes = profile.clothes.map(String.init).joined(separator: ", ")
        resultLabel.text = "UID: \(profile.uid)\nNombre: \(profile.nickname)\nRegión: \(profile.region)\nNivel: \(profile.level)\nLikes: \(profile.likes)\nRango BR: \(profile.brRank)\nRango CS: \(profile.csRank)\nGuild: \(profile.guild)\n\nROPA / EQUIPAMIENTO (IDs)\n\(clothes)\n\nNota: los IDs son los que entrega el perfil. Para mostrar imágenes o nombres de cada prenda hace falta un catálogo de assets compatible."
    }

    @objc private func closeTapped() { dismiss(animated: true) }
}

private struct FreeFireTestProfile {
    let uid: String
    let nickname: String
    let region: String
    let level: Int
    let likes: Int
    let brRank: Int
    let csRank: Int
    let guild: String
    let clothes: [Int]
}

private enum FreeFireTestAPI {
    static func fetchProfile(uid: String, region: String, completion: @escaping (Result<FreeFireTestProfile, Error>) -> Void) {
        var components = URLComponents(string: "https://freefireinfo-zy9l.onrender.com/api/v1/player-profile")!
        components.queryItems = [
            URLQueryItem(name: "uid", value: uid),
            URLQueryItem(name: "server", value: region),
            URLQueryItem(name: "need_gallery_info", value: "false")
        ]
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error { completion(.failure(error)); return }
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), let data else {
                completion(.failure(NSError(domain: "FreeFireTestAPI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Servidor devolvió una respuesta no válida"])))
                return
            }
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let basic = json?["basicinfo"] as? [String: Any] ?? json?["basicInfo"] as? [String: Any] ?? [:]
                let profile = json?["profileinfo"] as? [String: Any] ?? json?["profileInfo"] as? [String: Any] ?? [:]
                let clothes = (profile["clothes"] as? [Any] ?? []).compactMap { ($0 as? NSNumber)?.intValue }
                let result = FreeFireTestProfile(
                    uid: (basic["accountid"] as? String) ?? uid,
                    nickname: (basic["nickname"] as? String) ?? "—",
                    region: (basic["region"] as? String) ?? region,
                    level: (basic["level"] as? NSNumber)?.intValue ?? 0,
                    likes: (basic["liked"] as? NSNumber)?.intValue ?? 0,
                    brRank: (basic["rank"] as? NSNumber)?.intValue ?? 0,
                    csRank: (basic["csrank"] as? NSNumber)?.intValue ?? 0,
                    guild: "Perfil remoto",
                    clothes: clothes
                )
                completion(.success(result))
            } catch { completion(.failure(error)) }
        }.resume()
    }
}
