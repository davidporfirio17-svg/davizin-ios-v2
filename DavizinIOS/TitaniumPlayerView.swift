import UIKit
import WebKit

// Envoltura débil para el handler de mensajes (evita ciclo de retención).
private final class TitaniumWeakHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ t: WKScriptMessageHandler) { target = t }
    func userContentController(_ u: WKUserContentController, didReceive m: WKScriptMessage) {
        target?.userContentController(u, didReceive: m)
    }
}

/// Pantalla Jugador estilo "titanio" (keynote plateado) renderizada en un WKWebView,
/// con los datos reales del jugador inyectados por JS. Expone la misma interfaz que
/// PlayerView usa el ViewController para no cambiar el flujo de búsqueda.
final class TitaniumPlayerView: UIView, WKScriptMessageHandler, WKNavigationDelegate {
    var onLookupRequested: ((String, String) -> Void)?
    var onAssetRequested: ((String, @escaping (UIImage?) -> Void) -> Void)?
    var onBanCheckRequested: ((String, @escaping (Result<FreeFireBanCheck, Error>) -> Void) -> Void)?

    private var webView: WKWebView!
    private var ready = false
    private var pendingJS: [String] = []

    override init(frame: CGRect) { super.init(frame: frame); configure() }
    required init?(coder: NSCoder) { super.init(coder: coder); configure() }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = UIColor(red: 0.89, green: 0.91, blue: 0.94, alpha: 1)

        let cfg = WKWebViewConfiguration()
        let ucc = WKUserContentController()
        ucc.add(TitaniumWeakHandler(self), name: "nyxel")
        cfg.userContentController = ucc

        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.navigationDelegate = self
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.scrollView.backgroundColor = .clear
        wv.scrollView.contentInsetAdjustmentBehavior = .never
        wv.translatesAutoresizingMaskIntoConstraints = false
        addSubview(wv)
        wv.davizinPinEdges(to: self)
        webView = wv

        if let url = Bundle.main.url(forResource: "nyxel_profile", withExtension: "html") {
            wv.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        ready = true
        for js in pendingJS { webView.evaluateJavaScript(js, completionHandler: nil) }
        pendingJS.removeAll()
    }

    private func run(_ js: String) {
        if ready { webView.evaluateJavaScript(js, completionHandler: nil) }
        else { pendingJS.append(js) }
    }

    // MARK: - API que usa el ViewController (misma que PlayerView)

    func showSummary(_ summary: FreeFireLookupSummary) {
        var dict: [String: Any] = [
            "uid": summary.uid,
            "nickname": summary.nickname ?? "",
            "level": summary.level ?? "",
            "likes": summary.likes ?? "",
            "region": (summary.region ?? "").uppercased(),
            "season": summary.season ?? "",
            "brPoints": summary.brPoints ?? "",
            "brRank": summary.brRankCode ?? "",
            "csPoints": summary.csPoints ?? "",
            "csRank": summary.csRankCode ?? ""
        ]
        if let clan = summary.clanName, !clan.isEmpty { dict["clan"] = clan }
        if let data = try? JSONSerialization.data(withJSONObject: dict),
           let json = String(data: data, encoding: .utf8) {
            run("window.NYXEL_setProfile && window.NYXEL_setProfile(\(json));")
        }
        // Precarga el catálogo si no está (asegura URLs frescas para esta búsqueda)
        NyxelItemCatalog.shared.preload { [weak self] _ in
            guard let self else { return }
            self.loadBanner(summary.bannerID)
            self.loadArsenal(summary.weaponSkinIDs)
            self.loadOutfit(summary.clothesIDs)
        }
    }

    /// Resuelve un itemID al URL público de su imagen vía NyxelItemCatalog.
    /// Fallback: si no está en el catálogo, usa el callback legado `onAssetRequested`
    /// (que intenta descargar la imagen via la lógica propia de la app).
    private func pushImage(id: String, jsSetter: String, index: Int? = nil) {
        if let url = NyxelItemCatalog.shared.imageURL(for: id) {
            let safe = url.absoluteString
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
            let indexArg = index.map { "\($0)," } ?? ""
            run("\(jsSetter) && \(jsSetter)(\(indexArg)'\(safe)');")
            return
        }
        // fallback legado (por si algún itemID no está en el catálogo)
        guard let onAssetRequested else { return }
        onAssetRequested(id) { [weak self] image in
            guard let self, let image, let png = image.pngData() else { return }
            let uri = "data:image/png;base64," + png.base64EncodedString()
            let indexArg = index.map { "\($0)," } ?? ""
            DispatchQueue.main.async {
                self.run("\(jsSetter) && \(jsSetter)(\(indexArg)'\(uri)');")
            }
        }
    }

    private func loadBanner(_ id: String?) {
        guard let id, !id.isEmpty else { return }
        pushImage(id: id, jsSetter: "window.NYXEL_setBanner")
    }

    private func loadArsenal(_ ids: [String]) {
        let items = Array(ids.prefix(12))
        run("window.NYXEL_setArsenalCount && window.NYXEL_setArsenalCount(\(items.count));")
        for (index, id) in items.enumerated() {
            pushImage(id: id, jsSetter: "window.NYXEL_setArsenalItem", index: index)
        }
    }

    private func loadOutfit(_ ids: [String]) {
        let items = Array(ids.prefix(12))
        run("window.NYXEL_setOutfitCount && window.NYXEL_setOutfitCount(\(items.count));")
        for (index, id) in items.enumerated() {
            pushImage(id: id, jsSetter: "window.NYXEL_setOutfitItem", index: index)
        }
    }

    func setLookupLoading(_ loading: Bool, message: String) {
        run("window.NYXEL_setState && window.NYXEL_setState(\(loading ? "'loading'" : "'idle'"));")
    }

    func setLookupError(_ message: String) {
        let safe = (try? JSONSerialization.data(withJSONObject: ["m": message]))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{\"m\":\"\"}"
        run("window.NYXEL_setState && window.NYXEL_setState('error:'+\(safe).m);")
    }

    // MARK: - Mensajes del WebView

    func userContentController(_ u: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "nyxel", let body = message.body as? [String: Any] else { return }
        if (body["t"] as? String) == "lookup" {
            let uid = (body["uid"] as? String) ?? ""
            let region = (body["region"] as? String) ?? "br"
            onLookupRequested?(uid, region)
        }
    }
}
