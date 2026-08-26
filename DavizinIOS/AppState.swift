import SwiftUI
import Combine

class AppState: ObservableObject {
    
    // MARK: - Auth
    @Published var isAuthenticated: Bool = false
    @Published var currentKey: String = ""
    
    // MARK: - Patch state
    @Published var isInjected: Bool = false
    @Published var statusMessage: String = "Listo"
    @Published var isWorking: Bool = false
    
    // MARK: - Config
    let appVersion = "2.0"
    let freeFireBundleID = "com.dts.freefiremax"
    let freeFireName = "Free Fire MAX"
    
    init() {
        // Cargar key guardada
        if let saved = UserDefaults.standard.string(forKey: "dz_key") {
            currentKey = saved
        }
        // Verificar estado de inyección
        checkInjectionStatus()
    }
    
    func checkInjectionStatus() {
        guard let container = InjectorService.findContainer(bundleID: freeFireBundleID) else {
            isInjected = false
            return
        }
        let backupPath = container + "/Documents/contentcache/Compulsory/ios/gameassetbundles/cache_res.original"
        isInjected = FileManager.default.fileExists(atPath: backupPath)
    }
    
    func saveKey(_ key: String) {
        currentKey = key
        UserDefaults.standard.set(key, forKey: "dz_key")
        isAuthenticated = true
    }
    
    func logout() {
        isAuthenticated = false
        currentKey = ""
        UserDefaults.standard.removeObject(forKey: "dz_key")
    }
}
