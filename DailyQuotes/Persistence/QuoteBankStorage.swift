import Foundation

/// 把每个语言的库存成 Application Support 下的 JSON 文件。
/// Хранит банк каждого языка отдельным JSON-файлом в Application Support.
final class FileQuoteBankStorage: QuoteBankStoring {
    private let directory: URL
    private let lock = NSLock()

    init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                                in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.directory = base.appendingPathComponent("DailyQuotes", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: self.directory,
                                                 withIntermediateDirectories: true)
    }

    private func fileURL(_ language: QuoteLanguage) -> URL {
        directory.appendingPathComponent("bank-\(language.rawValue).json")
    }

    private struct Payload: Codable {
        let quotes: [Item]
        struct Item: Codable { let id: Int; let text: String; let author: String }
    }

    func load(language: QuoteLanguage) -> [Quote]? {
        lock.lock(); defer { lock.unlock() }
        guard let data = try? Data(contentsOf: fileURL(language)),
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            return nil
        }
        return payload.quotes.map { Quote(id: $0.id, text: $0.text, author: $0.author) }
    }

    func save(_ quotes: [Quote], language: QuoteLanguage) {
        lock.lock(); defer { lock.unlock() }
        let payload = Payload(quotes: quotes.map {
            Payload.Item(id: $0.id, text: $0.text, author: $0.author)
        })
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: fileURL(language), options: .atomic)
    }
}
