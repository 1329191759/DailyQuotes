import Foundation

/// 领域模型。不依赖网络和持久化，可被 API 层、数据库层和界面共用。
/// Доменная модель. Не зависит от сети и хранилища, используется слоями API, базы и интерфейса.
struct Quote: Identifiable, Equatable, Hashable, Codable, Sendable {
    let id: Int
    let text: String
    let author: String
}
