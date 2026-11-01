import Foundation

final class NyxelGameVersionChecker {

    static let shared = NyxelGameVersionChecker()
    private init() {}

    private let versionKeyPrefix = "nyxel.game.version."
    private let lastCheckKey = "nyxel.game.version.lastCheck"
    private let cooldown: TimeInterval = 3600

    struct VersionResult {
        let game: DavizinGame
        let previousVersion: String?
        let currentVersion: String
        let updated: Bool
    }

    private static func bundleID(for game: DavizinGame) -> String {
        switch game {
        case .freeFireMax: return "com.dts.freefiremax"
        case .freeFire:    return "com.dts.freefireth"
        }
    }

    func checkForUpdates(completion: @escaping ([VersionResult]) -> Void) {
        let lastCheck = UserDefaults.standard.double(forKey: lastCheckKey)
        if lastCheck > 0, Date().timeIntervalSince1970 - lastCheck < cooldown {
            completion([])
            return
        }

        let games: [DavizinGame] = [.freeFireMax, .freeFire]
        let group = DispatchGroup()
        var results: [VersionResult] = []
        let lock = NSLock()

        for game in games {
            group.enter()
            fetchStoreVersion(for: game) { result in
                if let result {
                    lock.lock()
                    results.append(result)
                    lock.unlock()
                }
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: self?.lastCheckKey ?? "")
            completion(results)
        }
    }

    private func fetchStoreVersion(for game: DavizinGame, completion: @escaping (VersionResult?) -> Void) {
        let bid = Self.bundleID(for: game)
        guard let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bid)&country=MX") else {
            completion(nil)
            return
        }

        let task = URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self, error == nil, let data else {
                completion(nil)
                return
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let count = json["resultCount"] as? Int, count > 0,
                  let resultArray = json["results"] as? [[String: Any]],
                  let first = resultArray.first,
                  let version = first["version"] as? String else {
                completion(nil)
                return
            }

            let storageKey = self.versionKeyPrefix + bid
            let previous = UserDefaults.standard.string(forKey: storageKey)
            let updated = previous != nil && previous != version

            UserDefaults.standard.set(version, forKey: storageKey)

            completion(VersionResult(
                game: game,
                previousVersion: previous,
                currentVersion: version,
                updated: updated
            ))
        }
        task.resume()
    }

    func savedVersion(for game: DavizinGame) -> String? {
        let bid = Self.bundleID(for: game)
        return UserDefaults.standard.string(forKey: versionKeyPrefix + bid)
    }

    func resetCooldown() {
        UserDefaults.standard.removeObject(forKey: lastCheckKey)
    }
}
