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
    var onFetchPlayerInfo: ((String, String, @escaping ([String: Any]?) -> Void) -> Void)?
    var onFetchItemImage: ((String, @escaping (UIImage?) -> Void) -> Void)?
    private let webView: WKWebView
    private var pendingModes: [DavizinMode] = []
    private var loaded = false

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
        guard let fetcher = onFetchItemImage else { return }
        fetcher(itemId) { [weak self] image in
            guard let self, let image, let data = image.pngData() else { return }
            let b64 = data.base64EncodedString()
            let safeId = itemId.filter { $0.isNumber || $0.isLetter }
            DispatchQueue.main.async {
                self.webView.evaluateJavaScript(
                    "window.NYXEL_onItemImage && window.NYXEL_onItemImage('\(safeId)', 'data:image/png;base64,\(b64)');",
                    completionHandler: nil
                )
            }
        }
    }

    private func fetchPlayerInfo(uid: String, region: String) {
        guard let fetcher = onFetchPlayerInfo else {
            DispatchQueue.main.async { [weak self] in
                self?.webView.evaluateJavaScript(
                    "window.NYXEL_onInfoError && window.NYXEL_onInfoError('Bridge no conectado');",
                    completionHandler: nil
                )
            }
            return
        }
        fetcher(uid, region) { [weak self] info in
            DispatchQueue.main.async {
                guard let self else { return }
                if let info,
                   let data = try? JSONSerialization.data(withJSONObject: info),
                   let json = String(data: data, encoding: .utf8) {
                    self.webView.evaluateJavaScript(
                        "window.NYXEL_onInfoData && window.NYXEL_onInfoData(\(json));",
                        completionHandler: nil
                    )
                } else {
                    self.webView.evaluateJavaScript(
                        "window.NYXEL_onInfoError && window.NYXEL_onInfoError('No se pudo consultar el perfil');",
                        completionHandler: nil
                    )
                }
            }
        }
    }

    deinit {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "nyxel")
    }
}
