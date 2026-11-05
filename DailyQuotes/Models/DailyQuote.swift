import Foundation

/// 今日名言：每个语言每天一条，持久化保存，重启后不变，全天固定。
/// Цитата дня: одна на язык в календарный день, сохраняется и не меняется до конца суток.
struct DailyQuote: Codable, Equatable, Sendable {
    let quote: Quote
    /// 日期键，格式 `yyyy-MM-dd`，使用本地时区。
    /// Ключ даты в формате `yyyy-MM-dd` по местному времени.
    let dayKey: String

    init(quote: Quote, dayKey: String) {
        self.quote = quote
        self.dayKey = dayKey
    }

    init(quote: Quote, date: Date, calendar: Calendar = .current) {
        self.init(quote: quote, dayKey: Self.dayKey(for: date, calendar: calendar))
    }

    /// 稳定的日期标识，用于判断是否跨天。
    /// Стабильный идентификатор дня для определения смены суток.
    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            parts.year ?? 0, parts.month ?? 0, parts.day ?? 0
        )
    }

    func isCurrent(for date: Date, calendar: Calendar = .current) -> Bool {
        dayKey == Self.dayKey(for: date, calendar: calendar)
    }
}
