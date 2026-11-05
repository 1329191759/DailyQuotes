import Foundation

/// 应用界面语言。
/// Язык интерфейса приложения.
enum AppLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    case chinese = "zh"
    case english = "en"
    case russian = "ru"

    var id: String { rawValue }

    /// 用该语言自身书写的名称。
    /// Название на самом этом языке.
    var nativeName: String {
        switch self {
        case .chinese: return "中文"
        case .english: return "English"
        case .russian: return "Русский"
        }
    }
}

/// 名言内容语言。
/// Язык загружаемых цитат.
enum QuoteLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    case chinese = "zh"
    case english = "en"
    case russian = "ru"
    /// 每条名言随机选择一种语言。
    /// Выбирает язык случайно для каждой цитаты.
    case random = "random"

    var id: String { rawValue }

    /// 选择器中显示的名称，使用当前界面语言。
    /// Название в выборе, на текущем языке интерфейса.
    func displayName(in interfaceLanguage: AppLanguage) -> String {
        switch self {
        case .chinese: return "中文"
        case .english: return "English"
        case .russian: return "Русский"
        case .random: return L10n.strings(for: interfaceLanguage).randomLanguage
        }
    }

    /// 真正能提供名言的语言（随机模式会展开成这些）。
    /// Языки, которые реально выдают цитаты (случайный режим раскрывается в них).
    static var concrete: [QuoteLanguage] {
        [.chinese, .english, .russian]
    }

    /// 把 `random` 解析成具体语言，其他值原样返回。
    /// Превращает `random` в конкретный язык, остальные не меняет.
    func resolved() -> QuoteLanguage {
        self == .random ? (Self.concrete.randomElement() ?? .english) : self
    }
}
