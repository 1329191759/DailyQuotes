import Foundation

/// 持久化今日名言，保证全天不变，并在重启后保留。
/// Сохраняет цитату дня, чтобы она не менялась в течение суток и переживала перезапуск.
protocol DailyQuoteStoring: Sendable {
    func load() -> DailyQuote?
    func save(_ daily: DailyQuote)
    func clear()
}

final class DefaultsDailyQuoteStore: DailyQuoteStoring, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "dailyQuote.current"
    private let lock = NSLock()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> DailyQuote? {
        lock.lock(); defer { lock.unlock() }
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(DailyQuote.self, from: data)
    }

    func save(_ daily: DailyQuote) {
        lock.lock(); defer { lock.unlock() }
        guard let data = try? JSONEncoder().encode(daily) else { return }
        defaults.set(data, forKey: key)
    }

    func clear() {
        lock.lock(); defer { lock.unlock() }
        defaults.removeObject(forKey: key)
    }
}
