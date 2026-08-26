import SwiftUI
import Combine

class AppState: ObservableObject {
    
    @Published var isAuthenticated: Bool = false
    @Published var currentKey: String = ""
    @Published var isInjected: Bool = false
    @Published var statusMessage: String = "Listo"
    @Published var isWorking: Bool = false
    
    let appVersion = "2.0"
    let freeFireBundleID = "com.dts.freefiremax"
    let freeFireName = "Free Fire MAX"
    
    init() {
        if let saved = UserDefaults.standard.string(forKey: "dz_key") {
            currentKey = saved
        }
        checkInjectionStatus()
    }
    
    func checkInjectionStatus() {
        isInjected = InjectorService.checkIsInjected(bundleID: freeFireBundleID)
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
