import Foundation

/// 按语言批量获取名言；有多少返回多少，允许部分结果。
/// Пакетная загрузка цитат по языкам; возвращается сколько удалось, частичный результат допустим.
protocol RemoteQuoteSource: Sendable {
    func fetchBatch(language: QuoteLanguage, limit: Int) async -> [Quote]
}

/// 批量源：一次请求下载整包句子，冷启动几秒就能填满库，而不是逐条请求几十次。
/// Пакетный источник: одна загрузка целой пачки, банк наполняется за секунды вместо десятков запросов.
final class BulkQuoteSource: RemoteQuoteSource {
    private let session: URLSession
    private let russian: RussianQuoteFetcher

    /// hitokoto 分类文件，按内容量从多到少排列。
    /// Файлы категорий hitokoto, от самых объёмных.
    private let hitokotoCategories = ["d", "g", "f", "e", "a", "c", "i", "k"]
    private let hitokotoBase = "https://raw.githubusercontent.com/hitokoto-osc/sentences-bundle/master/sentences"

    init(session: URLSession = .shared) {
        self.session = session
        self.russian = RussianQuoteFetcher(session: session)
    }

    func fetchBatch(language: QuoteLanguage, limit: Int) async -> [Quote] {
        switch language {
        case .chinese:
            return await fetchChinese(limit: limit)
        case .english:
            return await fetchEnglish(limit: limit)
        case .russian:
            // 维基语录是逐页的，单次调用只能拿到几条。
            // Викицитатник отдаётся постранично, один вызов даёт несколько цитат.
            return await russian.fetch(limit: min(limit, 20))
        case .random:
            // 把这一批分摊到三个来源，让内容混合。
            // Распределяем пачку по трём источникам для смешанного набора.
            let share = max(1, limit / QuoteLanguage.concrete.count)
            var results: [Quote] = []
            for concrete in QuoteLanguage.concrete {
                results.append(contentsOf: await fetchBatch(language: concrete, limit: share))
            }
            return Array(results.prefix(limit))
        }
    }

    // // MARK: - 中文批量
    // // MARK: - Пакет (китайский)

    private func fetchChinese(limit: Int) async -> [Quote] {
        var results: [Quote] = []
        var seen = Set<Int>()

        // 从随机分类、随机位置开始取，否则每次都拿到同一个包的开头，库就不再有增长（全是重复）。
        // Стартуем со случайной категории и позиции, иначе каждый раз одно и то же начало пачки (сплошные дубли).
        let categories = hitokotoCategories.shuffled()

        for category in categories {
            guard results.count < limit else { break }
            guard let url = URL(string: "\(hitokotoBase)/\(category).json"),
                  let pack: [HitokotoDTO] = await get(url),
                  !pack.isEmpty else { continue }

            let start = Int.random(in: 0..<pack.count)
            let rotated = Array(pack[start...]) + Array(pack[..<start])

            for item in rotated {
                guard results.count < limit else { break }
                guard !seen.contains(item.id) else { continue }
                // hitokoto 包里混有少量英文条目，这里保证库只含中文。
                // В пачках hitokoto есть английские строки — здесь банк остаётся китайским.
                guard LanguageFilter.accepts(item.hitokoto, for: .chinese) else { continue }
                seen.insert(item.id)
                results.append(item.toDomain())
            }
        }
        return results
    }

    // // MARK: - 英文批量
    // // MARK: - Пакет (английский)

    private func fetchEnglish(limit: Int) async -> [Quote] {
        var results: [Quote] = []
        var seen = Set<Int>()
        var skip = Int.random(in: 0..<1200)

        // dummyjson 每次请求上限 100 条。
        // dummyjson ограничивает запрос 100 цитатами.
        while results.count < limit {
            let pageSize = min(100, limit - results.count)
            guard let url = URL(string: "https://dummyjson.com/quotes?limit=\(pageSize)&skip=\(skip)"),
                  let payload: QuoteListDTO = await get(url),
                  !payload.quotes.isEmpty else { break }

            for dto in payload.quotes where !seen.contains(dto.id) {
                guard LanguageFilter.accepts(dto.quote, for: .english) else { continue }
                seen.insert(dto.id)
                results.append(dto.toDomain())
            }
            skip += pageSize
            if skip > 1400 { skip = 0 }
        }
        return results
    }

    // // MARK: - 辅助方法
    // // MARK: - Вспомогательное

    private func get<T: Decodable>(_ url: URL) async -> T? {
        await HTTPJSON.get(T.self, from: url, session: session, timeout: 20)
    }
}

