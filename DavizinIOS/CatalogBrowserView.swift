import UIKit
import WebKit

/// Pantalla "Outfit Showcase" — muestra al jugador con todas sus prendas
/// reales desplegadas como grid de loot. Avatar grande arriba, grid con
/// cada pieza del clothesIDs/weaponSkinIDs/bannerID/petID resuelta al PNG
/// real vía `items.json` del repo nyxel-ff-assets.
///
/// (El nombre de la clase queda por compatibilidad con el call-site anterior;
///  el contenido es el Outfit Showcase, no el catálogo global.)
final class CatalogBrowserView: UIView, WKNavigationDelegate {
    private var webView: WKWebView!
    private var ready = false
    private var pendingPayload: [String: Any]?

    override init(frame: CGRect) { super.init(frame: frame); configure() }
    required init?(coder: NSCoder) { super.init(coder: coder); configure() }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = UIColor(red: 0.008, green: 0.016, blue: 0.039, alpha: 1)

        let wv = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        wv.navigationDelegate = self
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.scrollView.backgroundColor = .clear
        wv.scrollView.contentInsetAdjustmentBehavior = .never
        wv.translatesAutoresizingMaskIntoConstraints = false
        addSubview(wv)
        wv.davizinPinEdges(to: self)
        webView = wv

        if let url = Bundle.main.url(forResource: "nyxel_outfit", withExtension: "html") {
            wv.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
    }

    /// API key para los endpoints de siambhau69.eu.cc (plan Premium).
    /// Expira 2027-01-27. Se puede sobreescribir en UserDefaults bajo
    /// "nyxel.siambhau.apikey" sin recompilar.
    private static var siamApiKey: String {
        if let k = UserDefaults.standard.string(forKey: "nyxel.siambhau.apikey"), !k.isEmpty {
            return k
        }
        return "FFAPI-PREM-60-sjdonsl-X28"
    }

    /// Mapea el código de región del lookup a los códigos aceptados por la API
    /// de SiamBhau (BD, IND, BR, SG, SAC, NA, EU, ME, ...).
    private static func siamRegion(from region: String?) -> String {
        guard let r = region?.lowercased(), !r.isEmpty else { return "BD" }
        switch r {
        case "br": return "BR"
        case "sg": return "SG"
        case "ind", "in": return "IND"
        case "us", "na": return "NA"
        case "eu": return "EU"
        case "sac": return "SAC"
        case "me": return "ME"
        case "bd": return "BD"
        default: return r.uppercased()
        }
    }

    /// Carga el perfil del jugador en la pantalla de Outfit.
    /// Puede llamarse antes o después de que el WebView termine de cargar;
    /// se encola si aún no está listo.
    func showOutfit(for summary: FreeFireLookupSummary) {
        var avatarURL: String? = nil
        var bannerURL: String? = nil
        if let a = summary.avatarID, !a.isEmpty {
            avatarURL = NyxelItemCatalog.shared.imageURL(for: a)?.absoluteString
        }
        if let b = summary.bannerID, !b.isEmpty {
            bannerURL = NyxelItemCatalog.shared.imageURL(for: b)?.absoluteString
        }
        // URLs oficiales de la API SiamBhau (premium) — SIN cache-buster para que
        // WKWebView cachee las respuestas y evitemos pegarle rate-limit al server.
        let siamRegion = Self.siamRegion(from: summary.region)
        let base = "https://siambhau69.eu.cc"
        let keyParams = "uid=\(summary.uid)&region=\(siamRegion)&key=\(Self.siamApiKey)"
        let renderURL = "\(base)/outfits/outfit?\(keyParams)"
        let bannerSiamURL = "\(base)/banner/profile?\(keyParams)"
        let banCheckURL = "\(base)/bancheck/bancheck?\(keyParams)"
        let loginHistoryURL = "\(base)/loginhistory/history?\(keyParams)"
        let infoURL = "\(base)/freefireinfo/bhau?\(keyParams)"
        let guildURL = "\(base)/guild/info?\(keyParams)"
        let friendsURL = "\(base)/friends/list?\(keyParams)"
        let dynamicDuoURL = "\(base)/dynamicduo/dynamicduo?\(keyParams)"
        let wishURL = "\(base)/wish/wishlist?\(keyParams)"
        let walletURL = "\(base)/walletinfo/wallet?\(keyParams)"
        let craftlandsURL = "\(base)/craftlands/info?\(keyParams)"

        let payload: [String: Any] = [
            "nickname": summary.nickname ?? "Jugador",
            "uid": summary.uid,
            "level": summary.level ?? "",
            "likes": summary.likes ?? "",
            "region": (summary.region ?? "").uppercased(),
            "br": summary.brRankCode ?? "",
            "cs": summary.csRankCode ?? "",
            "season": summary.season ?? "",
            "avatarURL": avatarURL ?? "",
            "bannerURL": bannerURL ?? "",
            "renderURL": renderURL,
            "bannerSiamURL": bannerSiamURL,
            "banCheckURL": banCheckURL,
            "loginHistoryURL": loginHistoryURL,
            "infoURL": infoURL,
            "guildURL": guildURL,
            "friendsURL": friendsURL,
            "dynamicDuoURL": dynamicDuoURL,
            "wishURL": wishURL,
            "walletURL": walletURL,
            "craftlandsURL": craftlandsURL,
            "clothesIDs": summary.clothesIDs,
            "weaponSkinIDs": summary.weaponSkinIDs,
            "bannerID": summary.bannerID ?? "",
            "headPicID": summary.headPicID ?? "",
            "petID": summary.petID ?? ""
        ]
        pendingPayload = payload
        if ready { flushPayload() }
    }

    private func flushPayload() {
        guard let p = pendingPayload,
              let data = try? JSONSerialization.data(withJSONObject: p),
              let json = String(data: data, encoding: .utf8) else { return }
        webView.evaluateJavaScript("window.NYXEL_setOutfitData && window.NYXEL_setOutfitData(\(json));", completionHandler: nil)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        ready = true
        flushPayload()
    }
}
