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

    func showOutfit(for summary: FreeFireLookupSummary) {
        var avatarURL: String? = nil
        var bannerURL: String? = nil
        if let a = summary.avatarID, !a.isEmpty {
            avatarURL = NyxelItemCatalog.shared.imageURL(for: a)?.absoluteString
        }
        if let b = summary.bannerID, !b.isEmpty {
            bannerURL = NyxelItemCatalog.shared.imageURL(for: b)?.absoluteString
        }

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
