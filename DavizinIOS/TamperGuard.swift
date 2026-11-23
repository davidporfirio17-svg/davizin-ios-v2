import UIKit
import CommonCrypto

final class TamperGuard {
    static let shared = TamperGuard()

    private var result: Bool?
    private var failReason: String?

    func verify() -> Bool {
        if let r = result { return r }
        let ok = performChecks()
        result = ok
        if !ok { showAlert() }
        return ok
    }

    private func performChecks() -> Bool {
        let bid = Bundle.main.bundleIdentifier ?? "(nil)"
        guard bid == "com.apple.mobile.MobileHouseArrest" else {
            failReason = "BID: \(bid)"
            NyxelActivityLog.record("TamperGuard: bundleID mismatch — got \(bid)")
            return false
        }

        guard let exec = Bundle.main.object(forInfoDictionaryKey: "CFBundleExecutable") as? String,
              exec == "DavizinIOS" else {
            failReason = "EXEC: \(Bundle.main.object(forInfoDictionaryKey: "CFBundleExecutable") ?? "(nil)")"
            NyxelActivityLog.record("TamperGuard: exec mismatch")
            return false
        }

        guard let token = Bundle.main.object(forInfoDictionaryKey: "_sys") as? String,
              token.count == 16 else {
            let raw = Bundle.main.object(forInfoDictionaryKey: "_sys")
            failReason = "TOKEN: \(raw ?? "(nil)") len=\((raw as? String)?.count ?? -1)"
            NyxelActivityLog.record("TamperGuard: token missing or wrong length")
            return false
        }

        guard let assetsURL = Bundle.main.url(forResource: "Assets", withExtension: "car"),
              let stream = InputStream(url: assetsURL) else {
            failReason = "ASSETS: not found"
            NyxelActivityLog.record("TamperGuard: Assets.car not found")
            return false
        }

        var ctx = CC_SHA256_CTX()
        CC_SHA256_Init(&ctx)
        stream.open()
        defer { stream.close() }
        let bufferSize = 65_536
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: bufferSize)
            guard read > 0 else { break }
            CC_SHA256_Update(&ctx, buffer, CC_LONG(read))
        }
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        CC_SHA256_Final(&digest, &ctx)
        let hash = digest.prefix(8).map { String(format: "%02x", $0) }.joined()

        guard hash == token else {
            failReason = "HASH: \(hash) vs \(token)"
            NyxelActivityLog.record("TamperGuard: hash mismatch — computed=\(hash) token=\(token)")
            return false
        }
        return true
    }

    private func showAlert() {
        let reason = failReason ?? "unknown"
        DispatchQueue.main.async {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = scene.windows.first,
                  let vc = window.rootViewController else { return }
            let alert = UIAlertController(
                title: "Modificaci\u{00f3}n detectada",
                message: "Esta aplicaci\u{00f3}n ha sido modificada y no funcionar\u{00e1}.\n\n[\(reason)]",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            vc.present(alert, animated: true)
        }
    }
}
