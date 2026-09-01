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

struct ARIFIModeConfig: Codable {
    let id: String
    let label: String
    let enabled: Bool
}

enum ARIFIMode: String, CaseIterable {
    case drag = "Drag"
    case pecho = "Pecho"
    case body100 = "Body 100%"

    var displayName: String { ARIFIModeCatalog.label(for: self) }
}

enum ARIFIModeCatalog {
    private static let storageKey = "dz_remote_mode_config_v1"
    private static let defaults: [ARIFIModeConfig] = [
        .init(id: "drag", label: "Drag", enabled: true),
        .init(id: "pecho", label: "Pecho", enabled: true),
        .init(id: "body100", label: "Body 100%", enabled: true)
    ]

    static func all() -> [ARIFIModeConfig] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([ARIFIModeConfig].self, from: data) else { return defaults }
        let valid = saved.filter { ARIFIMode(rawValue: rawValue(for: $0.id)) != nil }
        return valid.isEmpty && !saved.isEmpty ? [] : defaults.map { base in saved.first(where: { $0.id == base.id }) ?? base }
    }

    static func enabledModes() -> [ARIFIMode] {
        all().filter { $0.enabled }.compactMap { mode(for: $0.id) }
    }

    static func label(for mode: ARIFIMode) -> String {
        guard let config = all().first(where: { $0.id == mode.id }) else { return mode.rawValue }
        let label = config.label.trimmingCharacters(in: .whitespacesAndNewlines)
        return label.isEmpty ? mode.rawValue : label
    }

    static func save(_ modes: [ARIFIModeConfig]) {
        guard let data = try? JSONEncoder().encode(modes) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private static func mode(for id: String) -> ARIFIMode? {
        switch id { case "drag": return .drag; case "pecho": return .pecho; case "body100": return .body100; default: return nil }
    }
    private static func rawValue(for id: String) -> String {
        switch id { case "drag": return "Drag"; case "pecho": return "Pecho"; case "body100": return "Body 100%"; default: return "" }
    }
}

private extension ARIFIMode {
    var id: String { switch self { case .drag: return "drag"; case .pecho: return "pecho"; case .body100: return "body100" } }
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
        case .checking, .running, .injecting, .cleaning:
            return true
        case .idle, .succeeded, .failed:
            return false
        }
    }
}
