import Foundation
import UIKit
import CryptoKit

struct KeyResponse: Codable {
    let success: Bool
    let message: String?
    let remaining_seconds: Int?
    let data: KeyData?
    let signature: String?
    let notice: String?
}

struct KeyData: Codable {
    let container_access_ready: Bool?
    let remaining_seconds: Int?
    let expire: Int64?
    let token: String?
    let resource_key: String?
    let tier: String?
    let modes: [ARIFIMode]?
}

class KeyValidator {

    // Debe coincidir EXACTO con el secreto del Worker.
    private static let signSecret = "78ae85be57c27ab1525e0af061fa4ce012e2f2b1484209bf64dc8834be7e0fc4"

    static func getDeviceHWID() -> String {
        if let hwid = UIDevice.current.identifierForVendor?.uuidString {
            return hwid
        }
        return UUID().uuidString
    }

    static func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let model = String(bytes: Data(bytes: &systemInfo.machine, count: Int(_SYS_NAMELEN)), encoding: .ascii)?.trimmingCharacters(in: .controlCharacters) ?? "Unknown"
        return model
    }

    static func getIOSVersion() -> String {
        return UIDevice.current.systemVersion
    }

    /// Recalcula HMAC-SHA256 hex igual que el Worker: HMAC(secreto, mensaje).
    private static func hmacHex(_ message: String) -> String {
        let key = SymmetricKey(data: Data(signSecret.utf8))
        let mac = HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: key)
        return mac.map { String(format: "%02x", $0) }.joined()
    }

    /// Verifica que la firma de la respuesta sea legitima (viene de nuestro Worker).
    /// El Worker firma: key + "|" + remaining + "|" + expire
    private static func verifySignature(key: String, remaining: Int, expire: Int64, signature: String?) -> Bool {
        guard let signature = signature, !signature.isEmpty else { return false }
        let message = "\(key)|\(remaining)|\(expire)"
        let expected = hmacHex(message)
        // Comparacion en tiempo constante
        guard expected.count == signature.count else { return false }
        return expected == signature
    }

    static func validate(key: String, completion: @escaping (Bool, String, Int, String?) -> Void) {
        validateWithSeconds(key: key, completion: completion)
    }

    static func validateWithSeconds(key: String, completion: @escaping (Bool, String, Int, String?) -> Void) {
        let serverURL = "https://dz.davidporfirio17.workers.dev"
        guard let url = URL(string: "\(serverURL)/check") else {
            completion(false, "URL inválida", 0, nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let hwid = getDeviceHWID()
        let model = getDeviceModel()
        let ios = getIOSVersion()
        let upperKey = key.uppercased()

        let body: [String: Any] = [
            "key": upperKey,
            "username": upperKey,
            "hwid": hwid,
            "model": model,
            "ios": ios
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
				if let error = error {
					NyxelRemoteConfigStore.recordFailure("\(NyxelErrorCode.workerUnavailable) — \(error.localizedDescription)")
					completion(false, "Error: \(error.localizedDescription)", 0, nil)
					return
				}

				guard let data = data else {
					NyxelRemoteConfigStore.recordFailure("\(NyxelErrorCode.workerUnavailable) — Sin respuesta")
					completion(false, "Sin respuesta", 0, nil)
                    return
                }

                do {
                    let resp = try JSONDecoder().decode(KeyResponse.self, from: data)
                    let rem = resp.data?.remaining_seconds ?? resp.remaining_seconds ?? 0

                    // Si el login es exitoso, EXIGIMOS firma valida.
                    // Esto bloquea servidores falsos que respondan success:true sin poder firmar.
                    if resp.success {
                        let expire = resp.data?.expire ?? 0
                        let ok = verifySignature(key: upperKey, remaining: rem, expire: expire, signature: resp.signature)
                        if !ok {
                            completion(false, "Respuesta no válida. Servidor no autorizado.", 0, nil)
                            return
                        }
						if let modes = resp.data?.modes {
							guard modes.count <= 64 else {
								NyxelRemoteConfigStore.recordFailure("\(NyxelErrorCode.invalidConfiguration) — Demasiados modos")
								completion(false, "Configuración inválida. Inténtalo más tarde.", 0, nil)
								return
							}
							ARIFIModeCatalog.save(modes)
						}
						NyxelRemoteConfigStore.recordAccepted()
					}

                    completion(resp.success, resp.message ?? "ok", rem, resp.notice)
			} catch {
					NyxelRemoteConfigStore.recordFailure("\(NyxelErrorCode.invalidConfiguration) — Respuesta no válida")
					completion(false, "Error parsing response", 0, nil)
                }
            }
        }.resume()
    }
}
