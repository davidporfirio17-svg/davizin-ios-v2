import UIKit

enum NyxelAppearanceStore {
    enum Theme: Int { case cyan = 0, ember = 1, violet = 2 }
    private static let key = "nyxel.appearance.theme"
    static var theme: Theme { Theme(rawValue: UserDefaults.standard.integer(forKey: key)) ?? .cyan }
    static var accent: UIColor {
        switch theme {
        case .cyan: return UIColor(red: 0.0, green: 1.0, blue: 0.761, alpha: 1)
        case .ember: return UIColor(red: 1.0, green: 0.42, blue: 0.16, alpha: 1)
        case .violet: return UIColor(red: 0.68, green: 0.42, blue: 1.0, alpha: 1)
        }
    }
    static var accentHot: UIColor { accent.withAlphaComponent(0.82) }
    static var accentDim: UIColor { accent.withAlphaComponent(0.14) }
    static func setTheme(_ theme: Theme) { UserDefaults.standard.set(theme.rawValue, forKey: key) }
}
