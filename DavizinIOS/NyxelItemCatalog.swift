import Foundation

/// Catálogo de items de Free Fire — mapea `itemID` numérico (de `clothesIDs[]`,
/// `bannerID`, `headPicID`, `weaponSkinIDs[]`, etc.) a la URL de imagen y
/// metadata pública. Se alimenta del repo
/// `davidporfirio17-svg/nyxel-ff-assets` (que a su vez fusiona el dataset
/// MIT de `0xMe/ItemID2` con nuestras texturas propias extraídas de los
/// AssetBundles).
///
/// Uso: `NyxelItemCatalog.shared.imageURL(for: "203012044")`
/// La primera llamada baja `items.json` una sola vez y lo cachea en `Caches/`.
/// Todas las llamadas subsecuentes son en memoria (síncronas).
final class NyxelItemCatalog {
    static let shared = NyxelItemCatalog()

    private static let remoteURL = URL(string: "https://raw.githubusercontent.com/davidporfirio17-svg/nyxel-ff-assets/main/items.json")!
    private static let cacheFileName = "nyxel_items.json"
    /// Cachea por hasta 7 días. Si el archivo local tiene más, se re-descarga.
    private static let maxCacheAge: TimeInterval = 60 * 60 * 24 * 7

    struct ItemInfo {
        let icon: String?
        let type: String
        let rare: String
        let imageURL: URL?
        let desc: String?
        let collection: String?
    }

    private var items: [String: ItemInfo] = [:]
    private var isLoading = false
    private var loadCallbacks: [(Bool) -> Void] = []
    private let queue = DispatchQueue(label: "nyxel.catalog", qos: .userInitiated)

    private init() {}

    /// Precarga el catálogo (descarga o lee de caché). Llamar en AppDelegate o al abrir la pantalla Jugador.
    func preload(_ completion: @escaping (Bool) -> Void = { _ in }) {
        queue.async { [weak self] in
            guard let self else { return }
            if !self.items.isEmpty { completion(true); return }
            self.loadCallbacks.append(completion)
            if self.isLoading { return }
            self.isLoading = true

            if let data = self.readCacheIfFresh() {
                self.parse(data: data)
                self.finishLoad(success: !self.items.isEmpty)
                return
            }
            self.downloadAndParse()
        }
    }

    /// Lookup inmediato (sincrónico). Si el catálogo no está cargado, devuelve nil
    /// y dispara precarga en background.
    func imageURL(for itemID: String) -> URL? {
        if items.isEmpty { preload() }
        return items[itemID]?.imageURL
    }

    func info(for itemID: String) -> ItemInfo? {
        if items.isEmpty { preload() }
        return items[itemID]
    }

    // MARK: - Internals

    private var cacheURL: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return caches.appendingPathComponent(Self.cacheFileName)
    }

    private func readCacheIfFresh() -> Data? {
        let url = cacheURL
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let date = attrs[.modificationDate] as? Date,
           Date().timeIntervalSince(date) < Self.maxCacheAge {
            return try? Data(contentsOf: url)
        }
        return nil
    }

    private func downloadAndParse() {
        var req = URLRequest(url: Self.remoteURL)
        req.timeoutInterval = 30
        let task = URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            guard let self else { return }
            self.queue.async {
                if let data, !data.isEmpty {
                    try? data.write(to: self.cacheURL, options: .atomic)
                    self.parse(data: data)
                } else if let fallback = try? Data(contentsOf: self.cacheURL) {
                    // Si la descarga falla pero hay caché viejo, usarlo
                    self.parse(data: fallback)
                }
                self.finishLoad(success: !self.items.isEmpty)
            }
        }
        task.resume()
    }

    private func parse(data: Data) {
        guard let raw = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else { return }
        var out: [String: ItemInfo] = [:]
        out.reserveCapacity(raw.count)
        for (id, dict) in raw {
            let imgStr = dict["img"] as? String
            out[id] = ItemInfo(
                icon: dict["icon"] as? String,
                type: (dict["type"] as? String) ?? "",
                rare: (dict["rare"] as? String) ?? "NONE",
                imageURL: imgStr.flatMap(URL.init(string:)),
                desc: dict["desc"] as? String,
                collection: dict["collection"] as? String
            )
        }
        self.items = out
    }

    private func finishLoad(success: Bool) {
        isLoading = false
        let cbs = loadCallbacks
        loadCallbacks.removeAll()
        DispatchQueue.main.async { cbs.forEach { $0(success) } }
    }
}
