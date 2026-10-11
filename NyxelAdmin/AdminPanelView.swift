import SwiftUI
import WebKit

private enum AdminPanelConfiguration {
    static let panelURL = URL(string: "https://dz.davidporfirio17.workers.dev/")!
    static let trustedHost = "dz.davidporfirio17.workers.dev"
}

struct AdminPanelView: View {
    @State private var reloadToken = 0
    @State private var isLoading = true
    @State private var loadError: String?

    var body: some View {
        VStack(spacing: 0) {
            header

            if isLoading {
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(Color(red: 0.36, green: 0.96, blue: 0.75))
                    .accessibilityLabel("Cargando el Panel Admin")
            }

            AdminPanelWebView(
                reloadToken: $reloadToken,
                isLoading: $isLoading,
                loadError: $loadError
            )
            .overlay {
                if let loadError {
                    loadFailure(message: loadError)
                }
            }
        }
        .background(Color(red: 0.025, green: 0.04, blue: 0.065))
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "key.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(red: 0.36, green: 0.96, blue: 0.75))
                .frame(width: 42, height: 42)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 13))

            VStack(alignment: .leading, spacing: 3) {
                Text("NYXEL ADMIN")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(.white)
                Text("Panel seguro · Keys y Telegram")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))
            }

            Spacer(minLength: 16)

            Button {
                loadError = nil
                reloadToken &+= 1
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 13))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Recargar panel")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color(red: 0.035, green: 0.055, blue: 0.085))
    }

    private func loadFailure(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(Color(red: 1.0, green: 0.75, blue: 0.30))
            Text("No se pudo abrir el panel")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.72))
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
            Button("Reintentar") {
                loadError = nil
                reloadToken &+= 1
            }
            .font(.system(size: 15, weight: .bold))
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.18, green: 0.70, blue: 0.55))
        }
        .padding(28)
        .frame(maxWidth: 420)
        .background(Color(red: 0.055, green: 0.08, blue: 0.12), in: RoundedRectangle(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.72))
    }
}

private struct AdminPanelWebView: UIViewRepresentable {
    @Binding var reloadToken: Int
    @Binding var isLoading: Bool
    @Binding var loadError: String?

    func makeCoordinator() -> Coordinator {
        Coordinator(
            trustedHost: AdminPanelConfiguration.trustedHost,
            isLoading: $isLoading,
            loadError: $loadError
        )
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.scrollView.keyboardDismissMode = .interactive
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 0.025, green: 0.04, blue: 0.065, alpha: 1)
        webView.scrollView.backgroundColor = webView.backgroundColor
        context.coordinator.lastReloadToken = reloadToken
        webView.load(URLRequest(url: AdminPanelConfiguration.panelURL, cachePolicy: .useProtocolCachePolicy))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastReloadToken != reloadToken else { return }
        context.coordinator.lastReloadToken = reloadToken
        loadError = nil
        webView.reload()
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        private let trustedHost: String
        private let isLoading: Binding<Bool>
        private let loadError: Binding<String?>
        var lastReloadToken = 0

        init(trustedHost: String, isLoading: Binding<Bool>, loadError: Binding<String?>) {
            self.trustedHost = trustedHost
            self.isLoading = isLoading
            self.loadError = loadError
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            updateState(isLoading: true, error: nil)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            updateState(isLoading: false, error: nil)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            report(error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            report(error)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }

            if url.scheme == "about" && url.absoluteString == "about:blank" {
                decisionHandler(.allow)
                return
            }

            let isTrustedHTTPS = url.scheme?.lowercased() == "https"
                && url.host?.lowercased() == trustedHost
            if isTrustedHTTPS {
                decisionHandler(.allow)
            } else {
                // Keep credentials and admin sessions inside the trusted Worker origin.
                decisionHandler(.cancel)
            }
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            guard let url = navigationAction.request.url,
                  url.scheme?.lowercased() == "https",
                  url.host?.lowercased() == trustedHost else { return nil }
            webView.load(navigationAction.request)
            return nil
        }

        private func report(_ error: Error) {
            let nsError = error as NSError
            guard nsError.code != NSURLErrorCancelled else { return }
            updateState(isLoading: false, error: error.localizedDescription)
        }

        private func updateState(isLoading value: Bool, error: String?) {
            DispatchQueue.main.async {
                self.isLoading.wrappedValue = value
                self.loadError.wrappedValue = error
            }
        }
    }
}
