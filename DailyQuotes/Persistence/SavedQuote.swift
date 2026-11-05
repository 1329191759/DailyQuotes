import Foundation
import SwiftData

/// 数据库层。SwiftData 模型，用于本地保存的收藏，重启后仍然保留。
/// Слой базы данных. SwiftData-модель для сохранённых цитат, переживает перезапуск.
@Model
final class SavedQuote {
    @Attribute(.unique) var quoteID: Int
    var text: String
    var author: String
    var savedAt: Date

    init(quoteID: Int, text: String, author: String, savedAt: Date = .now) {
        self.quoteID = quoteID
        self.text = text
        self.author = author
        self.savedAt = savedAt
    }
}

extension SavedQuote {
    convenience init(domain quote: Quote) {
        self.init(quoteID: quote.id, text: quote.text, author: quote.author)
    }
}

/// SwiftData 的轻量封装，使视图模型不直接接触 ModelContext，便于单元测试替身。
/// Тонкая обёртка над SwiftData: модель представления не трогает ModelContext, легко подменяется в тестах.
protocol QuoteStoring {
    func isSaved(_ quote: Quote) throws -> Bool
    func save(_ quote: Quote) throws
    func remove(_ quote: Quote) throws
}

final class SwiftDataQuoteStore: QuoteStoring {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func isSaved(_ quote: Quote) throws -> Bool {
        let id = quote.id
        var descriptor = FetchDescriptor<SavedQuote>(
            predicate: #Predicate { $0.quoteID == id }
        )
        descriptor.fetchLimit = 1
        return try !context.fetch(descriptor).isEmpty
    }

    func save(_ quote: Quote) throws {
        guard try !isSaved(quote) else { return }
        context.insert(SavedQuote(domain: quote))
        try context.save()
    }

    func remove(_ quote: Quote) throws {
        let id = quote.id
        let descriptor = FetchDescriptor<SavedQuote>(
            predicate: #Predicate { $0.quoteID == id }
        )
        for item in try context.fetch(descriptor) {
            context.delete(item)
        }
        try context.save()
    }
}
