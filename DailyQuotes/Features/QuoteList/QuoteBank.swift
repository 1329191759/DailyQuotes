import Foundation

/// 每个语言固定容量的候选名言池。
/// Пул кандидатов-цитат фиксированного размера для каждого языка.
@MainActor
final class QuoteBank {
    static let capacity = 300
    static let recycleEvery = 30

    private(set) var language: QuoteLanguage
    private(set) var entries: [Quote]
    /// 上一次轮换之后已显示过的 ID。
    /// ID, показанные с момента последней ротации.
    private(set) var shownSinceRecycle: Set<Int> = []
    /// 已显示并移除的 ID，本次会话内不再加入。
    /// ID, показанные и удалённые; в этой сессии заново не добавляются.
    private(set) var retiredIDs: Set<Int> = []

    private var shownOrder: [Int] = []

    private let storage: QuoteBankStoring
    private var seed: [Quote]

    init(language: QuoteLanguage, seed: [Quote], storage: QuoteBankStoring) {
        self.language = language
        // 种子也要过滤：内置文件虽经人工检查，这一步可防止混入的外语条目进入界面。
        // Затравка тоже фильтруется: это не даёт иноязычной строке попасть в интерфейс.
        self.seed = seed.filter { LanguageFilter.accepts($0.text, for: language) }
        self.storage = storage
        let stored = storage.load(language: language) ?? []
        let usable = stored.filter { LanguageFilter.accepts($0.text, for: language) }
        self.entries = usable.isEmpty ? self.seed : usable
    }

    var count: Int { entries.count }

    /// 随机挑一条本轮尚未显示过的名言。
    /// Случайно выбирает цитату, ещё не показанную в этом цикле.
    func pick(excluding lastID: Int?) -> Quote? {
        let fresh = entries.filter { !shownSinceRecycle.contains($0.id) }
        let pool = fresh.isEmpty ? entries : fresh
        let candidates = pool.count > 1 ? pool.filter { $0.id != lastID } : pool
        return candidates.randomElement() ?? pool.first
    }

    /// 标记一条名言为已显示；本轮满 30 条时执行轮换，并返回是否发生了轮换。
    /// Помечает цитату как показанную; при 30 показах выполняет ротацию и сообщает, была ли она.
    @discardableResult
    func recordShown(_ quote: Quote) -> Bool {
        shownSinceRecycle.insert(quote.id)
        shownOrder.append(quote.id)

        guard shownOrder.count >= Self.recycleEvery else {
            persist()
            return false
        }

        // 移除本轮显示过的全部条目，避免重复出现。
        // Удаляет все показанные в этом цикле записи, чтобы они не повторялись.
        let shown = Set(shownOrder)
        entries.removeAll { shown.contains($0.id) }
        retiredIDs.formUnion(shown)
        shownOrder.removeAll()
        shownSinceRecycle.removeAll()

        refillFromSeed()
        persist()
        return true
    }

    /// 网络层应避免重复加入的 ID。
    /// ID, которые сетевому слою не нужно добавлять повторно.
    var knownIDs: Set<Int> { Set(entries.map(\.id)) }

    /// 加入新抓取的名言，保持在容量上限内；每条都会做文字系统校验，作为最后一道防线。
    /// Добавляет новые цитаты в пределах ёмкости; каждая проверяется по письменности как последний рубеж.
    func absorb(_ quotes: [Quote]) {
        var seen = knownIDs
        for quote in quotes where !seen.contains(quote.id) && !retiredIDs.contains(quote.id) {
            guard LanguageFilter.accepts(quote.text, for: language) else { continue }
            guard entries.count < Self.capacity else { break }
            entries.append(quote)
            seen.insert(quote.id)
        }
        persist()
    }

    // // MARK: - 私有
    // // MARK: - Приватное

    /// 用内置种子补足池子，跳过已移除的条目；当几乎全部显示过时开启新周期，保证应用不会枯竭。
    /// Пополняет пул из затравки, пропуская удалённые; когда показано почти всё, начинается новый цикл.
    private func refillFromSeed() {
        if entries.count < Self.recycleEvery {
            // 新周期：允许再次出现之前显示过的名言。
            // Новый цикл: ранее показанные цитаты снова разрешены.
            retiredIDs.removeAll()
            shownSinceRecycle.removeAll()
            shownOrder.removeAll()
        }

        var seen = knownIDs
        for quote in seed where entries.count < Self.capacity {
            guard !seen.contains(quote.id), !retiredIDs.contains(quote.id) else { continue }
            entries.append(quote)
            seen.insert(quote.id)
        }
    }

    private func persist() {
        storage.save(entries, language: language)
    }
}

/// 语言库的持久化接口。
/// Интерфейс хранения банка языка.
protocol QuoteBankStoring: Sendable {
    func load(language: QuoteLanguage) -> [Quote]?
    func save(_ quotes: [Quote], language: QuoteLanguage)
}
