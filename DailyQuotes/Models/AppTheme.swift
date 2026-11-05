import Foundation
import SwiftUI

/// 外观偏好。`system` 跟随系统设置，另外两个在应用内强制固定配色。
/// Настройка оформления. `system` следует системе, две другие принудительно задают схему.
enum AppTheme: String, CaseIterable, Identifiable, Codable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    /// 返回 nil 表示跟随系统，这正是 `preferredColorScheme` 对系统模式的要求。
    /// nil означает «как в системе» — именно этого ожидает `preferredColorScheme`.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// 选择器中显示的本地化名称。
    /// Локализованная подпись для выбора.
    func label(for language: AppLanguage) -> String {
        let strings = L10n.strings(for: language)
        switch self {
        case .system: return strings.themeSystem
        case .light: return strings.themeLight
        case .dark: return strings.themeDark
        }
    }
}
