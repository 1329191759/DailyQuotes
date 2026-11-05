import XCTest
@testable import DailyQuotes

@MainActor
final class QuoteListViewModelTests: XCTestCase {

    private func makeViewModel(
        seed: [Quote] = makeQuotes(from: 1, count: 60),
        remote: MockRemoteSource = MockRemoteSource(),
        store: MockQuoteStore = MockQuoteStore(),
        clock: @escaping () -> Date = Date.init
    ) -> QuoteListViewModel {
        QuoteListViewModel(
            remote: remote,
            store: store,
            bankStorage: MockBankStorage(),
            seedProvider: { _ in seed },
            clock: clock
        )
    }

    func testFirstLoadShowsQuoteFromSeedBank() async {
        let viewModel = makeViewModel()

        await viewModel.loadQuote(language: .english)

        XCTAssertNotNil(viewModel.quote)
        if case .loaded = viewModel.state {
            // // 期望值
            // // Ожидаемое значение
        } else {
            XCTFail("После загрузки состояние должно быть .loaded")
        }
    }

    func testColdStartRefillsBankFromNetwork() async {
        let remote = MockRemoteSource()
        remote.batches[.english] = makeQuotes(from: 5000, count: 40)
        // // 种子很少：库必须向网络请求补充。
        // // Мало затравки: банк должен запросить пополнение из сети.
        let viewModel = makeViewModel(seed: makeQuotes(from: 1, count: 5), remote: remote)

        await viewModel.loadQuote(language: .english)

        // // 补充在后台进行，首条名言立即显示。
        // // Пополнение идёт в фоне, первая цитата показывается сразу.
        let deadline = Date().addingTimeInterval(5)
        while viewModel.bankCount <= 5 && Date() < deadline {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        XCTAssertGreaterThan(remote.fetchCount, 0, "Холодный старт должен запросить сеть")
        XCTAssertGreaterThan(viewModel.bankCount, 5, "Банк должен пополниться из сети")
    }

    func testToggleSaveAddsAndRemovesFromDatabase() async {
        let store = MockQuoteStore()
        let viewModel = makeViewModel(store: store)
        await viewModel.loadQuote(language: .english)
        let quote = viewModel.quote!

        XCTAssertNil(viewModel.toggleSave())
        XCTAssertTrue(viewModel.isCurrentSaved)
        XCTAssertEqual(store.items, [quote])

        XCTAssertNil(viewModel.toggleSave())
        XCTAssertFalse(viewModel.isCurrentSaved)
        XCTAssertTrue(store.items.isEmpty)
    }

    func testToggleSaveWithoutQuoteDoesNothing() {
        let store = MockQuoteStore()
        let viewModel = makeViewModel(store: store)

        XCTAssertNil(viewModel.toggleSave())
        XCTAssertTrue(store.items.isEmpty)
    }

    func testFavouritesAreIndependentOfBankRecycling() async {
        let store = MockQuoteStore()
        let viewModel = makeViewModel(store: store)
        await viewModel.loadQuote(language: .english)
        let saved = viewModel.quote!

        viewModel.toggleSave()

        // // 模拟切换语言，此时整个库会被丢弃。
        // // Имитируем смену языка: банк полностью сбрасывается.
        viewModel.resetForLanguageChange()

        XCTAssertEqual(store.items, [saved], "Избранное должно переживать смену языка и банка")
    }

    func testHistoryIsFilledByRefreshes() async {
        var now = Date(timeIntervalSince1970: 1000)
        let viewModel = makeViewModel(clock: { now })

        await viewModel.loadQuote(language: .english)
        now = now.addingTimeInterval(2)
        await viewModel.loadQuote(language: .english)

        XCTAssertEqual(viewModel.history.entries.count, 2)
        XCTAssertTrue(viewModel.canGoBack)
        XCTAssertFalse(viewModel.canGoForward)
    }

    func testRapidRefreshIsNotThrottled() async {
        // // 名言来自本地库，因此连续刷新每次都必须
        // // Цитаты берутся из локального банка, поэтому каждое обновление
        // // 生成新记录，而不是被静默吞掉。
        // // должно создавать новую запись, а не теряться.
        let viewModel = makeViewModel()

        await viewModel.loadQuote(language: .english)
        await viewModel.loadQuote(language: .english)
        await viewModel.loadQuote(language: .english)

        XCTAssertEqual(viewModel.history.entries.count, 3, "Каждый тап должен добавлять цитату")
    }

    func testLanguageChangeResetsBankAndHistory() async {
        let viewModel = makeViewModel()
        await viewModel.loadQuote(language: .english)
        XCTAssertTrue(viewModel.canGoBack == false)

        viewModel.resetForLanguageChange()

        XCTAssertTrue(viewModel.history.isEmpty)
        XCTAssertEqual(viewModel.bankCount, 0)
        XCTAssertEqual(viewModel.state, .idle)
    }

    func testGoBackAndForwardRestoreQuotes() async {
        var now = Date(timeIntervalSince1970: 2000)
        let viewModel = makeViewModel(clock: { now })

        await viewModel.loadQuote(language: .chinese)
        let first = viewModel.quote
        now = now.addingTimeInterval(2)
        await viewModel.loadQuote(language: .chinese)
        let second = viewModel.quote

        viewModel.goBack()
        XCTAssertEqual(viewModel.quote, first)

        viewModel.goForward()
        XCTAssertEqual(viewModel.quote, second)
    }
}
