import UIKit

enum NyxelAppearanceStore {
    enum Theme: Int { case cyan = 0, ember = 1, violet = 2 }
    enum ColorMode: Int { case automatic = 0, light = 1, dark = 2 }
    private static let key = "nyxel.appearance.theme"
    private static let colorModeKey = "nyxel.appearance.colorMode"
    static var theme: Theme { Theme(rawValue: UserDefaults.standard.integer(forKey: key)) ?? .cyan }
    static var colorMode: ColorMode { ColorMode(rawValue: UserDefaults.standard.integer(forKey: colorModeKey)) ?? .automatic }
    static var uiStyle: UIUserInterfaceStyle {
        switch colorMode {
        case .automatic: return .unspecified
        case .light: return .light
        case .dark: return .dark
        }
    }
    static var accent: UIColor {
        switch theme {
        case .cyan: return UIColor(red: 0.0, green: 1.0, blue: 0.761, alpha: 1)
        case .ember: return UIColor(red: 1.0, green: 0.42, blue: 0.16, alpha: 1)
        case .violet: return UIColor(red: 0.68, green: 0.42, blue: 1.0, alpha: 1)
        }
    }
    static var accentHot: UIColor { accent.withAlphaComponent(0.82) }
    static var accentDim: UIColor { accent.withAlphaComponent(0.14) }
    private static let animationsKey = "nyxel.animations.enabled"
    static var animationsEnabled: Bool {
        if UserDefaults.standard.object(forKey: animationsKey) == nil { return true }
        return UserDefaults.standard.bool(forKey: animationsKey)
    }
    static func setAnimationsEnabled(_ enabled: Bool) { UserDefaults.standard.set(enabled, forKey: animationsKey) }
    static func setTheme(_ theme: Theme) { UserDefaults.standard.set(theme.rawValue, forKey: key) }
    static func setColorMode(_ mode: ColorMode) { UserDefaults.standard.set(mode.rawValue, forKey: colorModeKey) }
}
