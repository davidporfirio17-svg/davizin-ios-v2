import Foundation
import UIKit

struct FreeFireMetric {
    let title: String
    let value: String
}

struct FreeFireModeStats {
    let key: String
    let title: String
    let metrics: [FreeFireMetric]
}

struct FreeFireBanCheck {
    let isBanned: Bool
    let period: String?
}

struct FreeFireLookupSummary {
    let uid: String
    let nickname: String?
    let level: String?
    let region: String?
    let season: String?
    let brRankCode: String?
    let brPoints: String?
    let csRankCode: String?
    let csPoints: String?
    let likes: String?
    let signature: String?
    let clanName: String?
    let clanLevel: String?
    let clanMembers: String?
    let avatarID: String?
    let headPicID: String?
    let bannerID: String?
    let profileBadgeID: String?
    let clothesIDs: [String]
    let petID: String?
    let weaponSkinIDs: [String]
    let modes: [FreeFireModeStats]
    let warnings: [String]
}

struct FreeFireClothingItem: Decodable {
    let id: String
    let name: String
    let category: String
}

struct RecentFreeFirePlayer: Codable, Equatable {
    let uid: String
    let region: String
}

enum FreeFirePlayerHistory {
    private static let storageKey = "nyxel.freefire.playerHistory.v1"
    private static let maximumEntries = 8

    static var entries: [RecentFreeFirePlayer] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([RecentFreeFirePlayer].self, from: data) else { return [] }
        return saved
    }

    static func record(uid: String, region: String) {
        guard uid.range(of: "^\\d{5,15}$", options: .regularExpression) != nil,
              ["br", "sg", "ind"].contains(region.lowercased()) else { return }
        let entry = RecentFreeFirePlayer(uid: uid, region: region.lowercased())
        var updated = entries.filter { $0 != entry }
        updated.insert(entry, at: 0)
        updated = Array(updated.prefix(maximumEntries))
        guard let data = try? JSONEncoder().encode(updated) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        UserDefaults.standard.removeObject(forKey: "nyxel.last_player_uid")
        UserDefaults.standard.removeObject(forKey: "nyxel.last_player_region")
    }
}

enum FreeFireClothingCatalog {
    // Metadata: https://github.com/0xMe/ItemID2 (MIT); game content remains Garena property.
    private static let itemsByID: [String: FreeFireClothingItem] = {
        guard let url = Bundle.main.url(forResource: "FreeFireClothingCatalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let items = try? JSONDecoder().decode([FreeFireClothingItem].self, from: data) else {
            return [:]
        }
        return Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }()

    static func item(for id: String) -> FreeFireClothingItem? {
        itemsByID[id]
    }
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

    private let baseURL = URL(string: "https://nyxel-freefire-stats.davidporfirio17.workers.dev")!
    private let imageCache = NSCache<NSString, UIImage>()
    private let imageLock = NSLock()
    private var imageRequestsInFlight: [String: [(UIImage?) -> Void]] = [:]

    private init() {
        imageCache.countLimit = 96
    }

    func lookup(
        uid: String,
        region: String,
        key: String,
        hwid: String,
        completion: @escaping (Result<FreeFireLookupSummary, Error>) -> Void
    ) {
        let body = securityPayload(key: key, hwid: hwid).merging([
            "uid": uid,
            "region": region
        ]) { _, newValue in newValue }

        let request: URLRequest
        do {
            request = try makeRequest(path: "/lookup", body: body)
        } catch {
            DispatchQueue.main.async { completion(.failure(FreeFireStatsError.service("No se pudo preparar la consulta."))) }
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error {
                    completion(.failure(FreeFireStatsError.service("No se pudo conectar con el servicio de jugadores: \(error.localizedDescription)")))
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
                    let message = root["message"] as? String ?? "No se pudo consultar el perfil."
                    completion(.failure(FreeFireStatsError.service(message)))
                    return
                }
                guard (200..<300).contains(status), let dataObject = root["data"] as? [String: Any] else {
                    completion(.failure(FreeFireStatsError.service("El Worker respondió con HTTP \(status).")))
                    return
                }
                completion(.success(Self.makeSummary(uid: uid, data: dataObject)))
            }
        }.resume()
    }

    func checkBanStatus(
        uid: String,
        key: String,
        hwid: String,
        completion: @escaping (Result<FreeFireBanCheck, Error>) -> Void
    ) {
        let body = securityPayload(key: key, hwid: hwid).merging(["uid": uid]) { _, newValue in newValue }
        let request: URLRequest
        do {
            request = try makeRequest(path: "/bancheck", body: body)
        } catch {
            DispatchQueue.main.async { completion(.failure(FreeFireStatsError.service("No se pudo preparar la consulta de Ban Check."))) }
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error {
                    completion(.failure(FreeFireStatsError.service("No se pudo conectar para consultar el estado: \(error.localizedDescription)")))
                    return
                }
                guard let data,
                      let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
                    completion(.failure(FreeFireStatsError.invalidResponse))
                    return
                }
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                guard (200..<300).contains(status), root["success"] as? Bool == true else {
                    completion(.failure(FreeFireStatsError.service(root["message"] as? String ?? "El proveedor no pudo consultar el estado de la cuenta.")))
                    return
                }
                let wrapper = root["data"] as? [String: Any] ?? [:]
                let result = wrapper["data"] as? [String: Any] ?? wrapper
                let rawFlag = result["is_banned"]
                let flag: Int?
                if let value = rawFlag as? Int {
                    flag = value
                } else if let value = rawFlag as? String {
                    flag = Int(value)
                } else {
                    flag = nil
                }
                guard let flag, flag == 0 || flag == 1 else {
                    completion(.failure(FreeFireStatsError.service("La respuesta de Ban Check no incluyó un estado válido.")))
                    return
                }
                let periodValue = result["period"]
                let period: String?
                if let value = periodValue as? String {
                    period = value
                } else if let value = periodValue as? NSNumber {
                    period = value.stringValue
                } else {
                    period = nil
                }
                completion(.success(FreeFireBanCheck(isBanned: flag == 1, period: period)))
            }
        }.resume()
    }

    func loadAsset(
        itemID: String,
        key: String,
        hwid: String,
        completion: @escaping (UIImage?) -> Void
    ) {
        let id = itemID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard id.range(of: "^\\d{5,15}$", options: .regularExpression) != nil else {
            DispatchQueue.main.async { completion(nil) }
            return
        }

        if let cached = imageCache.object(forKey: id as NSString) {
            DispatchQueue.main.async { completion(cached) }
            return
        }

        imageLock.lock()
        if imageRequestsInFlight[id] != nil {
            imageRequestsInFlight[id]?.append(completion)
            imageLock.unlock()
            return
        }
        imageRequestsInFlight[id] = [completion]
        imageLock.unlock()

        var body = securityPayload(key: key, hwid: hwid)
        body["item_id"] = id
        let request: URLRequest
        do {
            request = try makeRequest(path: "/asset", body: body)
        } catch {
            finishAssetRequest(id: id, image: nil)
            return
        }

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let image: UIImage?
            if error == nil, (200..<300).contains(status), let data {
                image = UIImage(data: data)
            } else {
                image = nil
            }
            self.finishAssetRequest(id: id, image: image)
        }.resume()
    }

    private func finishAssetRequest(id: String, image: UIImage?) {
        if let image { imageCache.setObject(image, forKey: id as NSString) }
        imageLock.lock()
        let callbacks = imageRequestsInFlight.removeValue(forKey: id) ?? []
        imageLock.unlock()
        DispatchQueue.main.async {
            callbacks.forEach { $0(image) }
        }
    }

    private func makeRequest(path: String, body: [String: Any]) throws -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))))
        request.httpMethod = "POST"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        KeyValidator.applySecurityHeaders(to: &request)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func securityPayload(key: String, hwid: String) -> [String: Any] {
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        return [
            "key": key.uppercased(),
            "hwid": hwid,
            "model": KeyValidator.getDeviceModel(),
            "ios": KeyValidator.getIOSVersion(),
            "app_version": appVersion,
            "app_build": KeyValidator.getAppBuild(),
            "installation_id": KeyValidator.getInstallationID()
        ]
    }

    private static func makeSummary(uid: String, data: [String: Any]) -> FreeFireLookupSummary {
        let profileRoot = dictionary(data["profile"])
        let profile = dictionary(profileRoot["data"]).isEmpty ? profileRoot : dictionary(profileRoot["data"])
        let statsRoot = dictionary(data["stats"])
        let stats = dictionary(statsRoot["data"]).isEmpty ? statsRoot : dictionary(statsRoot["data"])
        let basic = dictionary(profile["basicInfo"])
        let profileInfo = dictionary(profile["profileInfo"])
        let social = dictionary(profile["socialInfo"])
        let clan = dictionary(profile["clanBasicInfo"])
        let pet = dictionary(profile["petInfo"])

        let documentedModeDefinitions = [
            ("brCareer_solo", "Solo"),
            ("brCareer_duo", "Dúo"),
            ("brCareer_squad", "Escuadra")
        ]
        let legacyModeDefinitions = [("solo", "Solo"), ("duo", "Dúo"), ("squad", "Escuadra")]
        let modeDefinitions = documentedModeDefinitions.contains { stats[$0.0] != nil } ? documentedModeDefinitions : legacyModeDefinitions
        let modes = modeDefinitions.compactMap { key, title -> FreeFireModeStats? in
            guard let raw = stats[key] else { return nil }
            let values = dictionary(raw)
            guard !values.isEmpty else { return FreeFireModeStats(key: key, title: title, metrics: []) }
            return FreeFireModeStats(key: key, title: title, metrics: metrics(from: values))
        }

        let warnings = data["warnings"] as? [String] ?? []
        let clothes = stringArray(profileInfo["clothes"] ?? profile["clothes"])
        let weaponSkins = stringArray(profileInfo["weaponSkinShows"] ?? profile["weaponSkinShows"])
        let avatarID = scalar(profileInfo, keys: ["avatarId", "avatarID"])
        let headPicID = scalar(basic, keys: ["headPic", "avatarId", "avatarID"])

        return FreeFireLookupSummary(
            uid: scalar(basic, keys: ["accountId", "uid"]) ?? scalar(profile, keys: ["uid", "accountId"]) ?? uid,
            nickname: scalar(basic, keys: ["nickname", "name"]) ?? scalar(profile, keys: ["name", "nickname"]),
            level: scalar(basic, keys: ["level"]) ?? scalar(profile, keys: ["level"]),
            region: scalar(basic, keys: ["region"]) ?? scalar(profile, keys: ["region"]),
            season: scalar(basic, keys: ["seasonId", "season"]),
            brRankCode: scalar(basic, keys: ["rank"]),
            brPoints: scalar(basic, keys: ["rankingPoints", "rankPoints"]),
            csRankCode: scalar(basic, keys: ["csRank"]),
            csPoints: scalar(basic, keys: ["csRankingPoints", "csRankPoints"]),
            likes: scalar(social, keys: ["likes"]) ?? scalar(basic, keys: ["liked", "likes"]),
            signature: scalar(social, keys: ["signature"]),
            clanName: scalar(clan, keys: ["clanName", "name"]),
            clanLevel: scalar(clan, keys: ["clanLevel", "level"]),
            clanMembers: scalar(clan, keys: ["memberNum", "members"]),
            avatarID: avatarID ?? headPicID,
            headPicID: headPicID,
            bannerID: scalar(basic, keys: ["bannerId", "bannerID"]),
            profileBadgeID: scalar(basic, keys: ["badgeId", "badgeID"]),
            clothesIDs: clothes,
            petID: scalar(pet, keys: ["id", "petId"]),
            weaponSkinIDs: weaponSkins,
            modes: modes,
            warnings: warnings
        )
    }

    private static func metrics(from mode: [String: Any]) -> [FreeFireMetric] {
        let prioritized: [(String, [String])] = [
            ("Partidas", ["matchPlayed", "matchesPlayed", "totalMatches", "matches", "gamesPlayed"]),
            ("Victorias", ["matchWon", "matchesWon", "totalWins", "wins", "booyahs"]),
            ("Eliminaciones", ["killCount", "totalKills", "kills", "eliminations"]),
            ("Máx. eliminaciones", ["maxKill", "maxKills", "highestKills", "maxEliminations"]),
            ("Headshots", ["headshotKills", "headshots", "headshotCount"]),
            ("Top 10", ["top10", "topTen", "top10Count"]),
            ("KD", ["kdRatio", "kd"])
        ]
        var result: [FreeFireMetric] = []
        var used = Set<String>()
        for (title, aliases) in prioritized {
            guard let key = aliases.first(where: { mode[$0] != nil }),
                  let value = text(mode[key]) else { continue }
            result.append(FreeFireMetric(title: title, value: value))
            used.insert(key)
        }
        if result.isEmpty {
            for key in mode.keys.sorted() where !used.contains(key) {
                guard let value = text(mode[key]) else { continue }
                result.append(FreeFireMetric(title: displayName(key), value: value))
                if result.count == 4 { break }
            }
        }
        return Array(result.prefix(4))
    }

    private static func dictionary(_ value: Any?) -> [String: Any] {
        value as? [String: Any] ?? [:]
    }

    private static func scalar(_ dictionary: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = text(dictionary[key]) { return value }
        }
        return nil
    }

    private static func stringArray(_ value: Any?) -> [String] {
        guard let values = value as? [Any] else { return [] }
        return values.compactMap { text($0) }
    }

    private static func displayName(_ key: String) -> String {
        key.replacingOccurrences(of: "([a-z0-9])([A-Z])", with: "$1 $2", options: .regularExpression)
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    private static func text(_ value: Any?) -> String? {
        guard let value, !(value is NSNull) else { return nil }
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let number = value as? NSNumber { return number.stringValue }
        return nil
    }
}
