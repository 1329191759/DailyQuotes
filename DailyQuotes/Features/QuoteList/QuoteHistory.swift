import Foundation

/// 名言浏览历史。
/// История просмотра цитат.
struct QuoteHistory: Equatable {
    /// 每条方向最多保留的条数。
    /// Сколько записей хранится в каждом направлении.
    static let window = 20

    private(set) var entries: [Quote] = []
    private(set) var index: Int = -1

    var isEmpty: Bool { entries.isEmpty }

    var current: Quote? {
        guard entries.indices.contains(index) else { return nil }
        return entries[index]
    }

    var canGoBack: Bool { index > 0 }

    var canGoForward: Bool { index >= 0 && index < entries.count - 1 }

    /// 追加新获取的名言；光标之后的记录会被丢弃，因为重新获取会替换「未来」分支。
    /// Добавляет новую цитату; записи после курсора отбрасываются.
    mutating func append(_ quote: Quote) {
        if entries.indices.contains(index), index < entries.count - 1 {
            entries.removeSubrange((index + 1)...)
        }
        entries.append(quote)
        index = entries.count - 1
        trimAroundCurrent()
    }

    /// 向前退一条，返回当前展示的名言。
    /// Шаг назад; возвращает текущую цитату.
    @discardableResult
    mutating func goBack() -> Quote? {
        guard canGoBack else { return current }
        index -= 1
        return current
    }

    /// 向后进一条，返回当前展示的名言。
    /// Шаг вперёд; возвращает текущую цитату.
    @discardableResult
    mutating func goForward() -> Quote? {
        guard canGoForward else { return current }
        index += 1
        return current
    }

    /// 裁剪掉距光标超过 `window` 的条目；前后各保留至多 `window` 条，两个方向都可导航。
    /// Обрезает записи дальше `window` от курсора; в обе стороны остаётся до `window` записей.
    private mutating func trimAroundCurrent() {
        let lower = max(0, index - Self.window)
        let upper = min(entries.count, index + Self.window + 1)
        guard lower > 0 || upper < entries.count else { return }

        entries = Array(entries[lower..<upper])
        index -= lower
    }

    mutating func reset() {
        entries.removeAll()
        index = -1
    }
}
