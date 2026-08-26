import Foundation

class KeyValidator: ObservableObject {
    
    // URL de tu Google Sheet publicado como CSV
    private let sheetsURL = "https://docs.google.com/spreadsheets/d/e/2PACX-1vTLztHH7JTyj7u3dyUG3IdSx3D5L0aDJ4FRQrp-HyXr5LXeUNgPid-UE7RP4Aga8j9XdhLn5L75OUzE/pub?gid=0&single=true&output=csv"
    
    func validate(key: String, completion: @escaping (Bool, String) -> Void) {
        guard let url = URL(string: sheetsURL) else {
            completion(false, "Error de configuración")
            return
        }
        
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            if let _ = error {
                DispatchQueue.main.async {
                    completion(false, "Sin conexión a internet")
                }
                return
            }
            
            guard let data = data,
                  let csv = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async {
                    completion(false, "Error al leer keys")
                }
                return
            }
            
            let validKeys = csv
                .components(separatedBy: "\n")
                .map { $0.components(separatedBy: ",").first ?? "" }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
                .filter { !$0.isEmpty }
            
            let inputKey = key.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let isValid = validKeys.contains(inputKey)
            
            DispatchQueue.main.async {
                completion(isValid, isValid ? "Key válida" : "Key inválida o expirada")
            }
        }.resume()
    }
}
