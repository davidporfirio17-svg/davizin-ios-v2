import Foundation

enum ARIFIScreenStage: Equatable {
    case login
    case gameSelection
    case modeSelection
    case operation
}

enum ARIFIGame: String, CaseIterable {
    case freeFire = "Free Fire"
    case freeFireMax = "Free Fire MAX"
}

struct ARIFIMode: Hashable, Codable, Identifiable {
    let id: String
    let label: String
    let enabled: Bool

    var rawValue: String { id }
    var displayName: String { label }

    static let drag = ARIFIMode(id: "drag", label: "Drag", enabled: true)
    static let pecho = ARIFIMode(id: "pecho", label: "Pecho", enabled: true)
    static let body100 = ARIFIMode(id: "body100", label: "Body 100%", enabled: true)
}

enum ARIFIModeCatalog {
    private static let storageKey = "dz_remote_mode_config_v2"
    private static let defaults: [ARIFIMode] = [.drag, .pecho, .body100]

    static func all() -> [ARIFIMode] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([ARIFIMode].self, from: data) else { return defaults }
        let known = Set(defaults.map(\.id))
        return saved.filter { known.contains($0.id) || isSafeDynamicID($0.id) }
    }

    static func enabledModes() -> [ARIFIMode] { all().filter(\.enabled) }

    static func mode(id: String) -> ARIFIMode? { all().first { $0.id == id } }

    static func save(_ modes: [ARIFIMode]) {
        let clean = modes.filter { isSafeDynamicID($0.id) && !$0.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard let data = try? JSONEncoder().encode(clean) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private static func isSafeDynamicID(_ id: String) -> Bool {
        guard id.count >= 1, id.count <= 32 else { return false }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-" )
        return id.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}

enum ARIFIOperationKind: String, CaseIterable {
    case runExploit = "Run Exploit"
    case inject = "Inject"
    case clean = "Clean"
}

enum ARIFIOperationState: Equatable {
    case idle
    case checking
    case running
    case injecting
    case cleaning
    case succeeded(String)
    case failed(String)

    var isBusy: Bool {
        switch self {
        case .checking, .running, .injecting, .cleaning: return true
        case .idle, .succeeded, .failed: return false
        }
    }
}
