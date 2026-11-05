import XCTest
@testable import DailyQuotes

// MARK: - 解码
// MARK: - Декодирование

final class QuoteDecodingTests: XCTestCase {

    func testDecodesDummyJSONSingleQuote() throws {
        let json = """
        {"id":223,"quote":"When you advise any person you should be guided by the fear of God.","author":"Abu Bakr (R.A)"}
        """.data(using: .utf8)!

        let domain = try JSONDecoder().decode(QuoteDTO.self, from: json).toDomain()

        XCTAssertEqual(domain.id, 223)
        XCTAssertEqual(domain.author, "Abu Bakr (R.A)")
    }

    func testDecodesDummyJSONList() throws {
        let json = """
        {"quotes":[{"id":1,"quote":"A","author":"X"},{"id":2,"quote":"B","author":"Y"}],"total":2}
        """.data(using: .utf8)!

        let list = try JSONDecoder().decode(QuoteListDTO.self, from: json)

        XCTAssertEqual(list.quotes.count, 2)
        XCTAssertEqual(list.quotes[1].toDomain().author, "Y")
    }

    func testDecodesHitokotoAndPrefersPerson() throws {
        let json = """
        {"id":6071,"hitokoto":"宇宙说：你所斗争的黑暗就在你心中。","from":"Minecraft","from_who":"终末之诗"}
        """.data(using: .utf8)!

        let domain = try JSONDecoder().decode(HitokotoDTO.self, from: json).toDomain()

        XCTAssertEqual(domain.id, 6071)
        XCTAssertEqual(domain.author, "终末之诗")
    }

    func testHitokotoFallsBackToWorkWhenNoPerson() throws {
        let json = """
        {"id":1,"hitokoto":"测试","from":"某作品","from_who":null}
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(HitokotoDTO.self, from: json)

        XCTAssertEqual(dto.toDomain().author, "某作品")
    }

    func testDecodesRussianLibraryFile() throws {
        let json = """
        {"quotes":[{"quote":"Знание — сила.","author":"Фрэнсис Бэкон"}]}
        """.data(using: .utf8)!

        let file = try JSONDecoder().decode(QuoteFileDTO.self, from: json)

        XCTAssertEqual(file.quotes.first?.quote, "Знание — сила.")
    }

    func testDecodingFailsOnUnexpectedShape() {
        let json = #"{"unexpected":true}"#.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(QuoteDTO.self, from: json))
    }
}

// MARK: - 俄语源解析
// MARK: - Разбор русского источника

final class RussianQuoteParsingTests: XCTestCase {

    func testKeepsSentenceLikeLines() {
        let extract = """
        Альберт Эйнштейн — физик.
        Воображение важнее знания.
        Категория:Физики
        https://example.com
        См. также
        """

        let lines = RussianQuoteFetcher.usableLines(from: extract)

        XCTAssertTrue(lines.contains("Воображение важнее знания."))
        XCTAssertFalse(lines.contains { $0.hasPrefix("Категория:") })
        XCTAssertFalse(lines.contains { $0.contains("http") })
    }

    func testDropsShortAndOverlongLines() {
        let short = "Коротко."
        let long = String(repeating: "а", count: 300)
        let extract = "\(short)\n\(long)\nЭто достаточно длинная строка для цитаты."

        let lines = RussianQuoteFetcher.usableLines(from: extract)

        XCTAssertFalse(lines.contains(short))
        XCTAssertFalse(lines.contains(long))
        XCTAssertEqual(lines.count, 1)
    }

    func testStableIDIsDeterministic() {
        let a = RussianQuoteFetcher.stableID(for: "Знание — сила.")
        let b = RussianQuoteFetcher.stableID(for: "Знание — сила.")
        let c = RussianQuoteFetcher.stableID(for: "Другая цитата.")

        XCTAssertEqual(a, b, "Один и тот же текст должен давать один id")
        XCTAssertNotEqual(a, c)
    }

    func testStableIDIsPositive() {
        for text in ["a", "", "Очень длинная строка текста для проверки"] {
            XCTAssertGreaterThan(RussianQuoteFetcher.stableID(for: text), 0)
        }
    }
}

