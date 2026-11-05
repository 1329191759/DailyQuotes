import XCTest
@testable import DailyQuotes

// MARK: - 远程源替身
// MARK: - Заглушка удалённого источника

final class MockRemoteSource: RemoteQuoteSource, @unchecked Sendable {
    var batches: [QuoteLanguage: [Quote]] = [:]
    private(set) var fetchCount = 0
    private(set) var requestedLimits: [Int] = []

    func fetchBatch(language: QuoteLanguage, limit: Int) async -> [Quote] {
        fetchCount += 1
        requestedLimits.append(limit)
        let available = batches[language] ?? []
        return Array(available.prefix(limit))
    }
}

// MARK: - 库存储替身
// MARK: - Заглушка хранилища банка

final class MockBankStorage: QuoteBankStoring, @unchecked Sendable {
    private(set) var saved: [QuoteLanguage: [Quote]] = [:]

    func load(language: QuoteLanguage) -> [Quote]? { saved[language] }
    func save(_ quotes: [Quote], language: QuoteLanguage) { saved[language] = quotes }
}

// MARK: - 数据库替身
// MARK: - Заглушка базы данных

final class MockQuoteStore: QuoteStoring, @unchecked Sendable {
    private(set) var items: [Quote] = []
    var saveError: Error?

    func isSaved(_ quote: Quote) throws -> Bool { items.contains(quote) }
    func save(_ quote: Quote) throws {
        if let saveError { throw saveError }
        items.append(quote)
    }
    func remove(_ quote: Quote) throws { items.removeAll { $0 == quote } }
}

// MARK: - 辅助方法
// MARK: - Вспомогательное

func makeQuotes(from base: Int, count: Int) -> [Quote] {
    // // 文本必须满足 LanguageFilter 的最小长度要求，并以拉丁字母为主，
    // // Текст должен проходить LanguageFilter: минимальная длина и преобладание латиницы,
    // // 否则库（及其种子）会拒绝它。
    // // иначе банк (и его затравка) его отклонит.
    (0..<count).map { offset in
        let id = base + offset
        return Quote(id: id,
                     text: "Sample quotation number \(id) for testing purposes",
                     author: "Author \(id)")
    }
}
