import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case simplifiedChinese
    case english

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "跟随系统 / System"
        case .simplifiedChinese: return "简体中文"
        case .english: return "English"
        }
    }

    private var usesChinese: Bool {
        switch self {
        case .simplifiedChinese: return true
        case .english: return false
        case .system:
            return Locale.preferredLanguages.first?.lowercased().hasPrefix("zh") == true
        }
    }

    func text(_ english: String, _ chinese: String) -> String {
        usesChinese ? chinese : english
    }
}
