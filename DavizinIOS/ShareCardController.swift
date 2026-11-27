import UIKit
import WebKit

private final class ShareCardWeakHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ t: WKScriptMessageHandler) { target = t }
    func userContentController(_ u: WKUserContentController, didReceive m: WKScriptMessage) {
        target?.userContentController(u, didReceive: m)
    }
}

/// Modal "Compartir perfil" — renderiza una tarjeta premium del jugador
/// en WKWebView y permite compartirla como imagen HD (toma snapshot y
/// presenta UIActivityViewController).
final class ShareCardController: UIViewController, WKScriptMessageHandler, WKNavigationDelegate {
    struct Data {
        let nickname: String
        let uid: String
        let level: String
        let likes: String
        let region: String
        let br: String
        let cs: String
        let season: String
        let avatarURL: URL?
        let bannerURL: URL?
    }

    private var webView: WKWebView!
    private var pendingData: Data?
    private var ready = false

    convenience init(data: Data) {
        self.init(nibName: nil, bundle: nil)
        self.pendingData = data
        self.modalPresentationStyle = .fullScreen
        self.modalTransitionStyle = .coverVertical
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.008, green: 0.016, blue: 0.039, alpha: 1)

        let cfg = WKWebViewConfiguration()
        let ucc = WKUserContentController()
        ucc.add(ShareCardWeakHandler(self), name: "nyxel")
        cfg.userContentController = ucc

        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.navigationDelegate = self
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.scrollView.backgroundColor = .clear
        wv.scrollView.contentInsetAdjustmentBehavior = .never
        wv.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(wv)
        wv.davizinPinEdges(to: view)
        webView = wv

        if let url = Bundle.main.url(forResource: "nyxel_share", withExtension: "html") {
            wv.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        ready = true
        pushDataIfReady()
    }

    private func pushDataIfReady() {
        guard ready, let d = pendingData else { return }
        let payload: [String: Any] = [
            "nickname": d.nickname,
            "uid": d.uid,
            "level": d.level,
            "likes": d.likes,
            "region": d.region,
            "br": d.br,
            "cs": d.cs,
            "season": d.season,
            "avatarURL": d.avatarURL?.absoluteString ?? "",
            "bannerURL": d.bannerURL?.absoluteString ?? ""
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let json = String(data: data, encoding: .utf8) {
            webView.evaluateJavaScript("window.NYXEL_setShareData && window.NYXEL_setShareData(\(json));", completionHandler: nil)
        }
    }

    // MARK: - Mensajes del WebView

    func userContentController(_ u: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "nyxel", let body = message.body as? [String: Any] else { return }
        let t = (body["t"] as? String) ?? ""
        switch t {
        case "close":
            dismiss(animated: true)
        case "share":
            captureAndShare()
        default: break
        }
    }

    // MARK: - Capture + share

    private func captureAndShare() {
        // Pequeño retraso para que el JS termine de aplicar el style "busy" en el botón
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self else { return }
            // Toma snapshot SOLO de la tarjeta (el elemento #card dentro del HTML).
            // Como WKWebView.takeSnapshot captura toda la vista, usamos la posición
            // del elemento #card vía JS y recortamos.
            let js = """
            (function(){ var c = document.getElementById('card'); if(!c) return null;
              var r = c.getBoundingClientRect();
              return {x:Math.round(r.left), y:Math.round(r.top), w:Math.round(r.width), h:Math.round(r.height)};
            })();
            """
            self.webView.evaluateJavaScript(js) { result, _ in
                let cfg = WKSnapshotConfiguration()
                cfg.afterScreenUpdates = true
                if let rect = result as? [String: Any],
                   let x = rect["x"] as? CGFloat, let y = rect["y"] as? CGFloat,
                   let w = rect["w"] as? CGFloat, let h = rect["h"] as? CGFloat, w > 10, h > 10 {
                    cfg.rect = CGRect(x: x, y: y, width: w, height: h)
                }
                self.webView.takeSnapshot(with: cfg) { [weak self] image, _ in
                    guard let self, let image else { return }
                    let activity = UIActivityViewController(
                        activityItems: [image, "Nyxel · Player Card"],
                        applicationActivities: nil
                    )
                    if let pop = activity.popoverPresentationController {
                        pop.sourceView = self.view
                        pop.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.maxY - 80, width: 1, height: 1)
                    }
                    self.present(activity, animated: true)
                }
            }
        }
    }
}
