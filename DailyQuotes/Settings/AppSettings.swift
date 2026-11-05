import Foundation
import Observation

/// 持久化的用户设置（基于 UserDefaults）。
/// Сохранённые настройки пользователя (на основе UserDefaults).
@MainActor
@Observable
final class AppSettings {
    private enum Key {
        static let appLanguage = "settings.appLanguage"
        static let quoteLanguage = "settings.quoteLanguage"
        static let theme = "settings.theme"
        static let dailyQuoteEnabled = "settings.dailyQuoteEnabled"
        static let initialized = "settings.initialized"
    }

    private let defaults: UserDefaults
    private let dailyQuoteStore: DailyQuoteStoring
    private var isApplying = false

    var appLanguage: AppLanguage {
        didSet { persistAppLanguage() }
    }

    var quoteLanguage: QuoteLanguage {
        didSet { persistQuoteLanguage() }
    }

    var theme: AppTheme {
        didSet { persistTheme() }
    }

    /// 开启后，应用启动时先显示固定的今日名言，并可收起到下拉条。
    /// Если включено, при запуске показывается цитата дня с возможностью свернуть.
    var dailyQuoteEnabled: Bool {
        didSet { persistDailyQuoteEnabled() }
    }

    /// 首次启动时按系统语言推断默认值，俄语用户无需设置即可看到俄语界面。
    /// При первом запуске значения берутся из системного языка: русский пользователь сразу видит русский.
    init(
        defaults: UserDefaults = .standard,
        dailyQuoteStore: DailyQuoteStoring = DefaultsDailyQuoteStore()
    ) {
        self.defaults = defaults
        self.dailyQuoteStore = dailyQuoteStore

        if let saved = defaults.string(forKey: Key.appLanguage),
           let value = AppLanguage(rawValue: saved) {
            appLanguage = value
        } else {
            appLanguage = Self.systemDefaultAppLanguage()
        }

        if let saved = defaults.string(forKey: Key.quoteLanguage),
           let value = QuoteLanguage(rawValue: saved) {
            quoteLanguage = value
        } else {
            quoteLanguage = Self.systemDefaultQuoteLanguage()
        }

        if let saved = defaults.string(forKey: Key.theme),
           let value = AppTheme(rawValue: saved) {
            theme = value
        } else {
            theme = .system
        }

        // 默认开启：今日名言是预期的第一个画面。
        // Включено по умолчанию: цитата дня — первый экран.
        if defaults.object(forKey: Key.dailyQuoteEnabled) == nil {
            dailyQuoteEnabled = true
        } else {
            dailyQuoteEnabled = defaults.bool(forKey: Key.dailyQuoteEnabled)
        }

        if !defaults.bool(forKey: Key.initialized) {
            defaults.set(true, forKey: Key.initialized)
            persistAppLanguage()
            persistQuoteLanguage()
            persistTheme()
            persistDailyQuoteEnabled()
        }
    }

    /// 还原到刚安装的状态：同时清空名言库，下次启动会从内置种子重建。
    /// Сброс к состоянию после установки: банки очищаются и при следующем запуске строятся из затравки.
    func reset() {
        isApplying = true
        appLanguage = Self.systemDefaultAppLanguage()
        quoteLanguage = Self.systemDefaultQuoteLanguage()
        theme = .system
        dailyQuoteEnabled = true          // back to the shipped default
        isApplying = false
        persistAppLanguage()
        persistQuoteLanguage()
        persistTheme()
        persistDailyQuoteEnabled()
        defaults.set(true, forKey: Key.initialized)
        clearQuoteBanks()
        dailyQuoteStore.clear()
    }

    /// 删除已保存的 `bank-<lang>.json` 文件。
    /// Удаляет сохранённые файлы `bank-<lang>.json`.
    private func clearQuoteBanks() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let directory = base.appendingPathComponent("DailyQuotes", isDirectory: true)

        for language in QuoteLanguage.allCases {
            let url = directory.appendingPathComponent("bank-\(language.rawValue).json")
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func persistAppLanguage() {
        guard !isApplying else { return }
        defaults.set(appLanguage.rawValue, forKey: Key.appLanguage)
    }

    private func persistQuoteLanguage() {
        guard !isApplying else { return }
        defaults.set(quoteLanguage.rawValue, forKey: Key.quoteLanguage)
    }

    private func persistTheme() {
        guard !isApplying else { return }
        defaults.set(theme.rawValue, forKey: Key.theme)
    }

    private func persistDailyQuoteEnabled() {
        guard !isApplying else { return }
        defaults.set(dailyQuoteEnabled, forKey: Key.dailyQuoteEnabled)
    }

    // // MARK: 系统默认值
    // // MARK: Системные значения

    private static func systemDefaultAppLanguage() -> AppLanguage {
        let identifier = Locale.preferredLanguages.first ?? "en"
        if identifier.hasPrefix("zh") { return .chinese }
        if identifier.hasPrefix("ru") { return .russian }
        return .english
    }

    private static func systemDefaultQuoteLanguage() -> QuoteLanguage {
        systemDefaultAppLanguage() == .chinese ? .chinese
            : (systemDefaultAppLanguage() == .russian ? .russian : .english)
    }
}
