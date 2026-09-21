import Foundation
import UIKit

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
    let modes: [DavizinMode]?
    let client_session: String?
}

class KeyValidator {

    /// Token efímero emitido por el Worker para las operaciones posteriores.
    /// No se persiste en UserDefaults: debe desaparecer al cerrar la app.
    private(set) static var currentSessionToken: String?

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
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let appBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"

        let body: [String: Any] = [
            "key": upperKey,
            "username": upperKey,
            "hwid": hwid,
            "model": model,
            "ios": ios,
            "app_version": appVersion,
            "app_build": appBuild
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

                    // Si el login es exitoso, EXIGIMOS una sesión efímera emitida por el Worker.
                    if resp.success {
							if let modes = resp.data?.modes {
							guard modes.count <= 64 else {
								NyxelRemoteConfigStore.recordFailure("\(NyxelErrorCode.invalidConfiguration) — Demasiados modos")
								completion(false, "Configuración inválida. Inténtalo más tarde.", 0, nil)
								return
							}
							DavizinModeCatalog.save(modes)
							}
							guard let session = resp.data?.client_session, !session.isEmpty else {
								NyxelRemoteConfigStore.recordFailure("\(NyxelErrorCode.invalidConfiguration) — Sesión ausente")
								completion(false, "Respuesta incompleta. Servidor no autorizado.", 0, nil)
								return
							}
							currentSessionToken = session
							NyxelRemoteConfigStore.recordAccepted()
						}
					else {
						currentSessionToken = nil
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
