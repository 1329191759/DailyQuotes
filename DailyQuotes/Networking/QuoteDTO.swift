import Foundation

// MARK: - 所有内置库共用的文件格式
// MARK: - Формат файлов банков

/// 所有内置名言文件共用的结构（zh_quotes.json / en_quotes.json / russian_quotes.json）。
/// Общая структура файлов цитат (zh_quotes.json / en_quotes.json / russian_quotes.json).
struct QuoteFileDTO: Decodable, Sendable {
    struct Item: Decodable, Sendable {
        let quote: String
        let author: String
    }

    let quotes: [Item]
}

// MARK: - dummyjson

/// dummyjson 返回的单条名言。
/// Одна цитата из dummyjson.
struct QuoteDTO: Decodable, Sendable {
    let id: Int
    let quote: String
    let author: String
}

extension QuoteDTO {
    func toDomain() -> Quote {
        Quote(id: id, text: quote, author: author)
    }
}

/// dummyjson 的分页响应。
/// Постраничный ответ dummyjson.
struct QuoteListDTO: Decodable, Sendable {
    let quotes: [QuoteDTO]
}

// MARK: - hitokoto

/// hitokoto 的条目格式：实时接口和批量句包结构相同。
/// Формат записи hitokoto: живой API и пакет предложений совпадают.
struct HitokotoDTO: Decodable, Sendable {
    let id: Int
    let hitokoto: String
    let from: String?
    let fromWho: String?

    enum CodingKeys: String, CodingKey {
        case id, hitokoto, from
        case fromWho = "from_who"
    }

    func toDomain() -> Quote {
        // 优先用标注的人名，没有则退回出处；不再强制解包，空的 from_who 视为缺失。
        // Сначала автор, иначе источник; без принудительного развёртывания, пустой from_who считается отсутствующим.
        let attributed = fromWho?.trimmingCharacters(in: .whitespaces)
        let author = (attributed?.isEmpty == false ? attributed : nil)
            ?? from
            ?? "佚名"
        return Quote(id: id, text: hitokoto, author: author)
    }
}
