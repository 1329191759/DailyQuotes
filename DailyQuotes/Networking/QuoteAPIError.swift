import Foundation

/// 会显示给用户的错误。网络失败在内部消化（库可离线提供名言），只有「完全没有可用的名言」才会到用户面前。
/// Ошибки для пользователя. Сетевые сбои обрабатываются внутри, до интерфейса доходит только отсутствие цитат.
enum QuoteAPIError: LocalizedError, Equatable {
    case libraryMissing

    var errorDescription: String? {
        switch self {
        case .libraryMissing: return "Нет доступных цитат"
        }
    }
}
