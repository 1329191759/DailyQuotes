import Foundation

/// 俄语名言来自维基语录（随机作者页，解析纯文本）；失败时退回 GitHub 上的 JSON 数据集。
/// Русские цитаты берутся из Викицитатника (случайные страницы авторов), при сбое — JSON-набор с GitHub.
final class RussianQuoteFetcher: @unchecked Sendable {
    private let session: URLSession
    private let wikiEndpoint = "https://ru.wikiquote.org/w/api.php"
    private let fallbackURL = URL(string:
        "https://raw.githubusercontent.com/VaultDweller13/quotes-ru-json/master/quotesRU.json")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetch(limit: Int) async -> [Quote] {
        var collected = await fetchFromWikiquote(limit: limit)
        if collected.count < limit {
            let extra = await fetchFromFallback(limit: limit - collected.count)
            let existing = Set(collected.map(\.id))
            collected.append(contentsOf: extra.filter { !existing.contains($0.id) })
        }
        return collected
    }

    // // MARK: - 维基语录
    // // MARK: - Викицитатник

    private func fetchFromWikiquote(limit: Int) async -> [Quote] {
        var results: [Quote] = []
        var seenTexts = Set<String>()
        var rounds = 0

        // 同时抓取多个随机页面并发解析；逐页串行是之前冷启动慢的原因。
        // Загружаем несколько случайных страниц одновременно; последовательная загрузка была узким местом.
        while results.count < limit && rounds < 4 {
            rounds += 1
            guard let titles = await randomTitles(count: 10) else { continue }

            let extracts = await withTaskGroup(of: (String, String?).self) { group in
                for title in titles {
                    group.addTask { [self] in
                        (title, await extract(for: title))
                    }
                }
                var collected: [(String, String?)] = []
                for await item in group { collected.append(item) }
                return collected
            }

            for (title, extract) in extracts {
                guard let extract, results.count < limit else { continue }
                for line in Self.usableLines(from: extract) {
                    guard results.count < limit else { break }
                    guard !seenTexts.contains(line) else { continue }
                    guard LanguageFilter.accepts(line, for: .russian) else { continue }
                    seenTexts.insert(line)
                    results.append(Quote(
                        id: Self.stableID(for: line),
                        text: line,
                        author: title
                    ))
                }
            }
        }
        return results
    }

    private func randomTitles(count: Int) async -> [String]? {
        guard var components = URLComponents(string: wikiEndpoint) else { return nil }
        components.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "list", value: "random"),
            URLQueryItem(name: "rnnamespace", value: "0"),
            URLQueryItem(name: "rnlimit", value: "\(count)"),
            URLQueryItem(name: "format", value: "json"),
        ]
        guard let url = components.url,
              let payload = await get(RandomPagesDTO.self, url: url) else { return nil }
        return payload.query.random.map(\.title)
    }

    private func extract(for title: String) async -> String? {
        guard var components = URLComponents(string: wikiEndpoint) else { return nil }
        components.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "prop", value: "extracts"),
            URLQueryItem(name: "explaintext", value: "1"),
            URLQueryItem(name: "exsectionformat", value: "plain"),
            URLQueryItem(name: "titles", value: title),
            URLQueryItem(name: "format", value: "json"),
        ]
        guard let url = components.url,
              let payload = await get(PagesDTO.self, url: url) else { return nil }
        return payload.query.pages.values.first?.extract
    }

    /// 过滤维基语录的噪音（导航、引用标记、分类），只保留长度合适、像句子的行。
    /// Отсеивает шум Викицитатника (навигация, ссылки, категории), оставляя строки-предложения.
    static func usableLines(from extract: String) -> [String] {
        extract
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { line in
                guard line.count >= 25, line.count <= 220 else { return false }
                if line.hasPrefix("Категория:") { return false }
                if line.contains("http") || line.contains("см.") { return false }
                if line.contains("↑") || line.contains("↓") { return false }
                if line.hasSuffix(":") { return false }
                return true
            }
    }

    // // MARK: - 备用数据集
    // // MARK: - Резервный набор

    private func fetchFromFallback(limit: Int) async -> [Quote] {
        var request = URLRequest(url: fallbackURL)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData

        guard let (data, _) = try? await session.data(for: request),
              let payload = try? JSONDecoder().decode(QuoteFileDTO.self, from: data) else {
            return []
        }

        return payload.quotes.prefix(limit).enumerated().compactMap { index, item in
            guard LanguageFilter.accepts(item.quote, for: .russian) else { return nil }
            return Quote(id: 950_000 + index, text: item.quote, author: item.author)
        }
    }

    // // MARK: - 辅助方法
    // // MARK: - Вспомогательное

    /// 根据文本生成稳定 ID，同一句话在不同次抓取中保持同一 ID，便于去重。
    /// Стабильный ID из текста: одна и та же цитата сохраняет ID между загрузками.
    static func stableID(for text: String) -> Int {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return Int(hash % 900_000_000) + 1_000_000
    }

    private func get<T: Decodable>(_ type: T.Type, url: URL) async -> T? {
        await HTTPJSON.get(type, from: url, session: session)
    }

    // // MARK: - 数据结构
    // // MARK: - Структуры данных

    struct RandomPagesDTO: Decodable {
        struct Query: Decodable {
            struct Page: Decodable { let title: String }
            let random: [Page]
        }
        let query: Query
    }

    struct PagesDTO: Decodable {
        struct Query: Decodable {
            struct Page: Decodable { let extract: String? }
            let pages: [String: Page]
        }
        let query: Query
    }
}
