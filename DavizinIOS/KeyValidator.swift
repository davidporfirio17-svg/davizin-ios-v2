import Foundation
import UIKit

struct KeyResponse: Codable {
    let success: Bool
    let message: String?
    let remaining_seconds: Int?
    let data: KeyData?
}

struct KeyData: Codable {
    let container_access_ready: Bool?
    let remaining_seconds: Int?
}

class KeyValidator {
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
    
    static func validate(key: String, completion: @escaping (Bool, String, Int) -> Void) {
        validateWithSeconds(key: key, completion: completion)
    }
    
    static func validateWithSeconds(key: String, completion: @escaping (Bool, String, Int) -> Void) {
        let serverURL = "https://dz.davidporfirio17.workers.dev"
        guard let url = URL(string: "\(serverURL)/check") else {
            completion(false, "URL inválida", 0)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let hwid = getDeviceHWID()
        let model = getDeviceModel()
        let ios = getIOSVersion()
        
        let body: [String: Any] = [
            "key": key.uppercased(),
            "username": key.uppercased(),
            "hwid": hwid,
            "model": model,
            "ios": ios
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, "Error: \(error.localizedDescription)", 0)
                    return
                }

                guard let data = data else {
                    completion(false, "Sin respuesta", 0)
                    return
                }

                do {
                    let resp = try JSONDecoder().decode(KeyResponse.self, from: data)
                    let rem = resp.data?.remaining_seconds ?? resp.remaining_seconds ?? 0
                    completion(resp.success, resp.message ?? "ok", rem)
                } catch {
                    completion(false, "Error parsing response", 0)
                }
            }
        }.resume()
    }
}
