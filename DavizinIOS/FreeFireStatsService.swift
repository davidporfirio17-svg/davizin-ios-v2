import Foundation

struct FreeFireLookupSummary {
    let text: String
}

private enum FreeFireStatsError: LocalizedError {
    case service(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .service(let message): return message
        case .invalidResponse: return "El servicio devolvió una respuesta que no se pudo leer."
        }
    }
}

final class FreeFireStatsService {
    static let shared = FreeFireStatsService()
    private let endpoint = URL(string: "https://nyxel-freefire-stats.davidporfirio17.workers.dev/lookup")!

    private init() {}

    func lookup(
        uid: String,
        region: String,
        key: String,
        hwid: String,
        completion: @escaping (Result<FreeFireLookupSummary, Error>) -> Void
    ) {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        KeyValidator.applySecurityHeaders(to: &request)

        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let body: [String: Any] = [
            "uid": uid,
            "region": region,
            "key": key.uppercased(),
            "hwid": hwid,
            "model": KeyValidator.getDeviceModel(),
            "ios": KeyValidator.getIOSVersion(),
            "app_version": appVersion,
            "app_build": KeyValidator.getAppBuild(),
            "installation_id": KeyValidator.getInstallationID()
        ]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(FreeFireStatsError.service("No se pudo preparar la solicitud.")))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error {
                    completion(.failure(FreeFireStatsError.service("Error de conexión con el Worker: \(error.localizedDescription)")))
                    return
                }
                guard let data else {
                    completion(.failure(FreeFireStatsError.invalidResponse))
                    return
                }
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
                    completion(.failure(FreeFireStatsError.invalidResponse))
                    return
                }
                guard root["success"] as? Bool == true else {
                    let message = root["message"] as? String ?? "La consulta no fue autorizada."
                    completion(.failure(FreeFireStatsError.service(message)))
                    return
                }
                guard (200..<300).contains(status), let dataObject = root["data"] as? [String: Any] else {
                    completion(.failure(FreeFireStatsError.service("El Worker respondió con HTTP \(status).")))
                    return
                }
                completion(.success(FreeFireLookupSummary(text: Self.formatSummary(uid: uid, data: dataObject))))
            }
        }.resume()
    }

    private static func formatSummary(uid: String, data: [String: Any]) -> String {
        let profileRoot = data["profile"] as? [String: Any] ?? [:]
        let profile = profileRoot["data"] as? [String: Any] ?? profileRoot
        let statsRoot = data["stats"] as? [String: Any] ?? [:]
        let stats = statsRoot["data"] as? [String: Any] ?? statsRoot
        let basicInfo = profile["basicInfo"] as? [String: Any] ?? profile
        let clanInfo = profile["clanBasicInfo"] as? [String: Any] ?? profile
        let socialInfo = profile["socialInfo"] as? [String: Any] ?? profile
        var lines = ["UID: \(text(basicInfo["accountId"]) ?? text(profile["uid"]) ?? uid)"]

        let name = text(basicInfo["nickname"]) ?? text(profile["name"])
        let level = text(basicInfo["level"]) ?? text(profile["level"])
        let rank = text(basicInfo["rank"]) ?? text(profile["rank"]) ?? text(profile["tier"])
        let region = text(basicInfo["region"]) ?? text(profile["region"])
        var identity: [String] = []
        if let name { identity.append(name) }
        if let level { identity.append("Nv. \(level)") }
        if let rank { identity.append("Rango \(rank)") }
        if let region { identity.append("Región \(region)") }
        if !identity.isEmpty { lines.append(identity.joined(separator: " • ")) }

        let clan = text(clanInfo["clanName"]) ?? text(profile["guild"])
        let clanLevel = text(clanInfo["clanLevel"])
        let memberCount = text(clanInfo["memberNum"])
        var clanDetails: [String] = []
        if let clan { clanDetails.append("Clan: \(clan)") }
        if let clanLevel { clanDetails.append("Nivel de clan: \(clanLevel)") }
        if let memberCount { clanDetails.append("Miembros: \(memberCount)") }
        if !clanDetails.isEmpty { lines.append(clanDetails.joined(separator: " • ")) }

        let signature = text(socialInfo["signature"])
        let likes = text(socialInfo["likes"]) ?? text(profile["likes"])
        let social = [signature.map { "Firma: \($0)" }, likes.map { "Me gusta: \($0)" }].compactMap { $0 }
        if !social.isEmpty { lines.append(social.joined(separator: " • ")) }

        let documentedModes = [("brCareer_solo", "Solo"), ("brCareer_duo", "Dúo"), ("brCareer_squad", "Escuadra")]
        let legacyModes = [("solo", "Solo"), ("duo", "Dúo"), ("squad", "Escuadra")]
        let modeNames = documentedModes.contains { stats[$0.0] != nil } ? documentedModes : legacyModes
        let modeSummaries = modeNames.compactMap { item -> String? in
            guard let mode = stats[item.0] as? [String: Any] else { return nil }
            let fields = mode.keys.sorted().compactMap { key -> String? in
                guard let value = text(mode[key]) else { return nil }
                return "\(displayName(key)): \(value)"
            }.prefix(4)
            guard !fields.isEmpty else { return nil }
            return "\(item.1): " + fields.joined(separator: " · ")
        }
        if !modeSummaries.isEmpty { lines.append(modeSummaries.joined(separator: "   |   ")) }

        if let warnings = data["warnings"] as? [String], !warnings.isEmpty {
            lines.append("Aviso: datos parciales (\(warnings.joined(separator: "; ")))")
        }
        if lines.count == 1 { lines.append("El proveedor no devolvió detalles de perfil o estadísticas.") }
        return lines.joined(separator: "\n")
    }

    private static func displayName(_ key: String) -> String {
        key.replacingOccurrences(of: "([a-z0-9])([A-Z])", with: "$1 $2", options: .regularExpression)
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    private static func text(_ value: Any?) -> String? {
        guard let value, !(value is NSNull) else { return nil }
        if let string = value as? String, !string.isEmpty { return string }
        if let number = value as? NSNumber { return number.stringValue }
        return nil
    }
}
