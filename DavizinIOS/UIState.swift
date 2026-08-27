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

enum ARIFIMode: String, CaseIterable {
    case drag = "Drag"
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
