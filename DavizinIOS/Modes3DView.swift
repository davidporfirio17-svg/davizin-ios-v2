import UIKit
import WebKit

protocol Modes3DViewDelegate: AnyObject {
    func modes3DView(_ view: Modes3DView, didRequestInjectModeId id: String, name: String, holo: String)
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
    private var pendingHolos: [[String: Any]] = []
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

    func setHolos(_ holos: [DavizinMode]) {
        pendingHolos = holos.map { ["id": $0.id, "name": $0.displayName] }
        if loaded { pushHolos() }
    }

    private func pushModes() {
        let arr: [[String: Any]] = pendingModes.map { ["id": $0.id, "name": $0.displayName, "sub": ""] }
        guard let data = try? JSONSerialization.data(withJSONObject: arr),
              let json = String(data: data, encoding: .utf8) else { return }
        webView.evaluateJavaScript("window.NYXEL_setModes && window.NYXEL_setModes(\(json));", completionHandler: nil)
    }

    private func pushHolos() {
        guard let data = try? JSONSerialization.data(withJSONObject: pendingHolos),
              let json = String(data: data, encoding: .utf8) else { return }
        webView.evaluateJavaScript("window.NYXEL_setHolos && window.NYXEL_setHolos(\(json));", completionHandler: nil)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loaded = true
        pushModes()
        pushHolos()
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
            let holo = body["holo"] as? String ?? ""
            delegate?.modes3DView(self, didRequestInjectModeId: id, name: name, holo: holo)
        }
        if t == "loadModel" {
            let name = body["name"] as? String ?? "rouk"
            loadModel(name: name)
        }
    }

    private func loadModel(name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "glb"),
              let data = try? Data(contentsOf: url) else { return }
        let b64 = data.base64EncodedString()
        DispatchQueue.main.async { [weak self] in
            self?.webView.evaluateJavaScript(
                "window.NYXEL_onModelData && window.NYXEL_onModelData('\(b64)');",
                completionHandler: nil
            )
        }
    }

    deinit {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "nyxel")
    }
}
