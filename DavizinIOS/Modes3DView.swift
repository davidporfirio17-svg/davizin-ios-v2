import UIKit
import WebKit

protocol Modes3DViewDelegate: AnyObject {
    /// El usuario mantuvo el botón de inyectar sobre un modo real.
    func modes3DView(_ view: Modes3DView, didRequestInjectModeId id: String, name: String)
}

/// Evita el ciclo de retención: WKUserContentController retiene al handler.
private final class WeakScriptHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ t: WKScriptMessageHandler) { target = t }
    func userContentController(_ u: WKUserContentController, didReceive m: WKScriptMessage) {
        target?.userContentController(u, didReceive: m)
    }
}

/// Pantalla de Modos basada en el visor 3D (rouk3d.html). Recibe los modos reales
/// y, al mantener presionado el botón, pide a la app que inyecte ese modo.
final class Modes3DView: UIView, WKNavigationDelegate, WKScriptMessageHandler {

    weak var delegate: Modes3DViewDelegate?
    private let webView: WKWebView
    private var pendingModes: [DavizinMode] = []
    private var loaded = false

    private static var siamApiKey: String {
        if let k = UserDefaults.standard.string(forKey: "nyxel.siambhau.apikey"), !k.isEmpty { return k }
        return "FFAPI-PREM-60-sjdonsl-X28"
    }

    private static var ffApiHubKey: String? {
        if let k = UserDefaults.standard.string(forKey: "nyxel.ffapihub.apikey"), !k.isEmpty { return k }
        return nil
    }

    override init(frame: CGRect) {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        webView = WKWebView(frame: .zero, configuration: cfg)
        super.init(frame: frame)
        configure()
    }
    required init?(coder: NSCoder) {
        webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.navigationDelegate = self
        webView.configuration.userContentController.add(WeakScriptHandler(self), name: "nyxel")
        webView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(webView)
        webView.davizinPinEdges(to: self)

        if let html = Bundle.main.url(forResource: "rouk3d", withExtension: "html") {
            webView.loadFileURL(html, allowingReadAccessTo: html.deletingLastPathComponent())
        }
    }

    func setModes(_ modes: [DavizinMode]) {
        pendingModes = modes
        if loaded { pushModes() }
    }

    private func pushModes() {
        let arr: [[String: Any]] = pendingModes.map { ["id": $0.id, "name": $0.displayName, "sub": ""] }
        guard let data = try? JSONSerialization.data(withJSONObject: arr),
              let json = String(data: data, encoding: .utf8) else { return }
        webView.evaluateJavaScript("window.NYXEL_setModes && window.NYXEL_setModes(\(json));", completionHandler: nil)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loaded = true
        pushModes()
    }

    func userContentController(_ u: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "nyxel", let body = message.body as? [String: Any] else { return }
        let t = body["t"] as? String ?? ""
        if t == "haptic" {
            let s = body["s"] as? String ?? "light"
            let style: UIImpactFeedbackGenerator.FeedbackStyle = (s == "heavy") ? .heavy : (s == "medium" ? .medium : .light)
            UIImpactFeedbackGenerator(style: style).impactOccurred()
            return
        }
        if t == "inject" {
            let id = body["id"] as? String ?? ""
            let name = body["name"] as? String ?? ""
            delegate?.modes3DView(self, didRequestInjectModeId: id, name: name)
        }
        if t == "fetchInfo" {
            let uid = body["uid"] as? String ?? ""
            let region = body["region"] as? String ?? "BR"
            fetchPlayerInfo(uid: uid, region: region)
        }
        if t == "fetchItemImage" {
            let itemId = body["itemId"] as? String ?? ""
            if !itemId.isEmpty { fetchItemImage(itemId: itemId) }
        }
    }

    private func fetchItemImage(itemId: String) {
        guard let key = Self.ffApiHubKey,
              itemId.allSatisfy({ $0.isNumber }),
              let url = URL(string: "https://developers.freefirecommunity.com/api/v1/image?itemID=\(itemId)") else { return }
        var req = URLRequest(url: url)
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("FreeFireAPILab/1.0", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            guard let self = self, let data = data, error == nil,
                  let http = response as? HTTPURLResponse, http.statusCode == 200,
                  !data.isEmpty else { return }
            let mime = http.mimeType ?? "image/png"
            let b64 = data.base64EncodedString()
            let dataUrl = "data:\(mime);base64,\(b64)"
            DispatchQueue.main.async {
                self.webView.evaluateJavaScript(
                    "window.NYXEL_onItemImage && window.NYXEL_onItemImage('\(itemId)','\(dataUrl)');",
                    completionHandler: nil
                )
            }
        }.resume()
    }

    private func fetchPlayerInfo(uid: String, region: String) {
        let base = "https://siambhau69.eu.cc"
        let key = Self.siamApiKey
        let urlStr = "\(base)/freefireinfo/bhau?uid=\(uid)&region=\(region)&key=\(key)"
        guard let url = URL(string: urlStr) else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self, let data = data, error == nil,
                  let json = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                self.webView.evaluateJavaScript(
                    "window.NYXEL_onInfoData && window.NYXEL_onInfoData(\(json));",
                    completionHandler: nil
                )
            }
        }.resume()
    }

    deinit {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "nyxel")
    }
}
