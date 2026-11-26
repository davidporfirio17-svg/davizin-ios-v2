import UIKit
import WebKit

protocol GameSelectionViewDelegate: AnyObject {
    func gameSelectionView(_ view: GameSelectionView, didSelect game: DavizinGame)
}

/// Envoltura débil para el handler de mensajes (evita ciclo de retención).
private final class GameSelectionWeakHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ t: WKScriptMessageHandler) { target = t }
    func userContentController(_ u: WKUserContentController, didReceive m: WKScriptMessage) {
        target?.userContentController(u, didReceive: m)
    }
}

/// Pantalla "Elige tu entorno" (Free Fire vs Free Fire MAX) estilo Liquid Glass
/// renderizada con un WKWebView que carga `entorno.html`. Mantiene la misma
/// interfaz pública que usa el ViewController para no cambiar el flujo.
final class GameSelectionView: UIView, WKScriptMessageHandler, WKNavigationDelegate {
    weak var delegate: GameSelectionViewDelegate?

    // Compatibilidad con el ViewController: estos callbacks ya no se disparan
    // porque la nueva pantalla quitó los shortcuts, pero mantenemos las propiedades
    // para no romper call sites existentes.
    var onOpenPlayer: (() -> Void)?
    var onOpenProfile: (() -> Void)?
    var onOpenHelp: (() -> Void)?

    private(set) var selectedGame: DavizinGame?

    private var webView: WKWebView!
    private var ready = false
    private var pendingJS: [String] = []

    override init(frame: CGRect) { super.init(frame: frame); configure() }
    required init?(coder: NSCoder) { super.init(coder: coder); configure() }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = UIColor(red: 0.023, green: 0.027, blue: 0.039, alpha: 1)

        let cfg = WKWebViewConfiguration()
        let ucc = WKUserContentController()
        ucc.add(GameSelectionWeakHandler(self), name: "nyxel")
        cfg.userContentController = ucc

        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.navigationDelegate = self
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.scrollView.backgroundColor = .clear
        wv.scrollView.contentInsetAdjustmentBehavior = .never
        wv.scrollView.isScrollEnabled = false
        wv.translatesAutoresizingMaskIntoConstraints = false
        addSubview(wv)
        wv.davizinPinEdges(to: self)
        webView = wv

        if let url = Bundle.main.url(forResource: "entorno", withExtension: "html") {
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

    // MARK: - API pública (igual que la versión UIKit anterior)

    /// Pre-selecciona visualmente un juego sin disparar el delegate.
    func setSelectedGame(_ game: DavizinGame?) {
        selectedGame = game
        guard let game else { return }
        let key = (game == .freeFireMax) ? "max" : "ff"
        run("window.NYXEL_setGame && window.NYXEL_setGame('\(key)');")
    }

    /// Mantenido por compatibilidad. La nueva pantalla ya no muestra el panel
    /// de estado de sesión/conexión, así que este método es un no-op.
    func setSessionStatus(keyAuthorized: Bool, remainingSeconds: Int) {
        // intencionalmente vacío
    }

    // MARK: - Mensajes del WebView

    func userContentController(_ u: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "nyxel", let body = message.body as? [String: Any] else { return }
        let kind = (body["t"] as? String) ?? ""
        let g = (body["g"] as? String) ?? ""
        let game: DavizinGame = (g == "max") ? .freeFireMax : .freeFire
        switch kind {
        case "pick":
            selectedGame = game
            delegate?.gameSelectionView(self, didSelect: game)
        case "preview":
            selectedGame = game
        default: break
        }
    }
}
