import XCTest
@testable import DailyQuotes

/// /// 历史窗口的纯逻辑测试。视图模型层面的导航由
/// /// Чистые тесты окна истории. Навигация на уровне модели представления —
/// /// `QuoteListViewModelTests` 覆盖。
/// /// в `QuoteListViewModelTests`.
final class QuoteHistoryTests: XCTestCase {

    private func makeQuote(_ id: Int) -> Quote {
        Quote(id: id, text: "Q\(id)", author: "A\(id)")
    }

    func testAppendKeepsLastAsCurrent() {
        var history = QuoteHistory()

        history.append(makeQuote(1))
        history.append(makeQuote(2))

        XCTAssertEqual(history.current?.id, 2)
        XCTAssertTrue(history.canGoBack)
        XCTAssertFalse(history.canGoForward)
    }

    func testGoBackAndForwardWalkTheWindow() {
        var history = QuoteHistory()
        for id in 1...3 { history.append(makeQuote(id)) }

        XCTAssertEqual(history.goBack()?.id, 2)
        XCTAssertEqual(history.goBack()?.id, 1)
        XCTAssertFalse(history.canGoBack)

        XCTAssertEqual(history.goForward()?.id, 2)
        XCTAssertEqual(history.goForward()?.id, 3)
        XCTAssertFalse(history.canGoForward)
    }

    func testAppendAfterGoBackDropsForwardBranch() {
        var history = QuoteHistory()
        for id in 1...3 { history.append(makeQuote(id)) }
        _ = history.goBack()          // now at 2

        history.append(makeQuote(99))

        XCTAssertEqual(history.current?.id, 99)
        XCTAssertEqual(history.entries.map(\.id), [1, 2, 99])
        XCTAssertFalse(history.canGoForward)
    }

    func testWindowKeepsTwentyBehindAndAhead() {
        var history = QuoteHistory()
        for id in 1...60 { history.append(makeQuote(id)) }

        // // 光标在最新一条上，因此只保留前 20 条加当前条。
        // // Курсор на самой новой записи, поэтому остаётся 20 предыдущих и текущая.
        XCTAssertEqual(history.entries.count, QuoteHistory.window + 1)
        XCTAssertEqual(history.current?.id, 60)
        XCTAssertNil(history.entries.first(where: { $0.id == 1 }), "Старые записи вытесняются")
        XCTAssertNotNil(history.entries.first(where: { $0.id == 60 }))
    }

    func testTwentyBackStepsAreAvailable() {
        var history = QuoteHistory()
        for id in 1...60 { history.append(makeQuote(id)) }

        var steps = 0
        while history.canGoBack {
            history.goBack()
            steps += 1
        }

        XCTAssertEqual(steps, QuoteHistory.window, "Должно быть доступно ровно 20 шагов назад")
    }

    func testStartsWithNoHistory() {
        let history = QuoteHistory()

        XCTAssertTrue(history.isEmpty)
        XCTAssertNil(history.current)
        XCTAssertFalse(history.canGoBack)
        XCTAssertFalse(history.canGoForward)
    }

    func testResetClearsEverything() {
        var history = QuoteHistory()
        history.append(makeQuote(1))
        history.append(makeQuote(2))

        history.reset()

        XCTAssertTrue(history.isEmpty)
        XCTAssertNil(history.current)
        XCTAssertFalse(history.canGoBack)
    }
}
