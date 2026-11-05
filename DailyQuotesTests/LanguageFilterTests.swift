import XCTest
@testable import DailyQuotes

final class LanguageFilterTests: XCTestCase {

    // MARK: 中文
    // MARK: Китайский

    func testAcceptsChineseQuotes() {
        XCTAssertTrue(LanguageFilter.accepts("生活不止眼前的苟且，还有诗和远方。", for: .chinese))
        XCTAssertTrue(LanguageFilter.accepts("宇宙说：你所斗争的黑暗就在你心中。", for: .chinese))
    }

    func testRejectsEnglishInsideChineseBank() {
        // // 这些正是之前混进中文库的英文条目。
        // // Именно эти строки раньше попадали в китайский банк.
        XCTAssertFalse(LanguageFilter.accepts("Decisions as I go, to anywhere I flow.", for: .chinese))
        XCTAssertFalse(LanguageFilter.accepts("Pray to become starry sky tomorrow.", for: .chinese))
        XCTAssertFalse(LanguageFilter.accepts("Do one thing at a time, and do well.", for: .chinese))
    }

    func testRejectsRussianInsideChineseBank() {
        XCTAssertFalse(LanguageFilter.accepts("Знание — сила, и это проверено временем.", for: .chinese))
    }

    // MARK: 俄语
    // MARK: Русский

    func testAcceptsRussianQuotes() {
        XCTAssertTrue(LanguageFilter.accepts("Мы в ответе за тех, кого приручили.", for: .russian))
        XCTAssertTrue(LanguageFilter.accepts("Краткость — сестра таланта.", for: .russian))
    }

    func testRejectsEnglishAndChineseInsideRussianBank() {
        XCTAssertFalse(LanguageFilter.accepts("To be or not to be, that is the question.", for: .russian))
        XCTAssertFalse(LanguageFilter.accepts("生活不止眼前的苟且，还有诗和远方。", for: .russian))
    }

    // MARK: 英文
    // MARK: Английский

    func testAcceptsEnglishQuotes() {
        XCTAssertTrue(LanguageFilter.accepts("Simplicity is the ultimate sophistication.", for: .english))
        XCTAssertTrue(LanguageFilter.accepts("Knowledge is power, and power is knowledge.", for: .english))
    }

    func testRejectsForeignScriptsInsideEnglishBank() {
        XCTAssertFalse(LanguageFilter.accepts("生活不止眼前的苟且，还有诗和远方。", for: .english))
        XCTAssertFalse(LanguageFilter.accepts("Мы в ответе за тех, кого приручили сегодня.", for: .english))
    }

    // MARK: 边界情况
    // MARK: Граничные случаи

    func testRejectsTooShortText() {
        XCTAssertFalse(LanguageFilter.accepts("Hi", for: .english))
        XCTAssertFalse(LanguageFilter.accepts("好", for: .chinese))
    }

    func testRejectsTextWithoutLetters() {
        XCTAssertFalse(LanguageFilter.accepts("12345 --- !!! 67890", for: .english))
    }

    func testMixedChineseWithEnglishAuthorStillAccepted() {
        // // 正文是中文；作者字段不参与语言判断。
        // // Текст китайский; поле автора в проверке не участвует.
        XCTAssertTrue(LanguageFilter.accepts("这句话完全是中文写的，没有问题。", for: .chinese))
    }
}
