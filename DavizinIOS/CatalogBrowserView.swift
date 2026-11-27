import UIKit
import WebKit

/// Pantalla "Catálogo" — grid navegable de los 32,199 items del juego.
/// Carga `items.json` desde el repo nyxel-ff-assets y los renderiza con
/// filtros, buscador y preview fullscreen. Todo en WKWebView para mantener
/// la estética Liquid Glass consistente con el resto de la app.
final class CatalogBrowserView: UIView, WKNavigationDelegate {
    private var webView: WKWebView!

    override init(frame: CGRect) { super.init(frame: frame); configure() }
    required init?(coder: NSCoder) { super.init(coder: coder); configure() }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = UIColor(red: 0.051, green: 0.063, blue: 0.082, alpha: 1)

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

        if let url = Bundle.main.url(forResource: "nyxel_catalog", withExtension: "html") {
            wv.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
    }
}
