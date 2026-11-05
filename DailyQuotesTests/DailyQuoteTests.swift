import XCTest
@testable import DailyQuotes

// MARK: - DailyQuote 模型
// MARK: - Модель DailyQuote

final class DailyQuoteTests: XCTestCase {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    func testDayKeyFormat() {
        let date = DateComponents(calendar: calendar, year: 2026, month: 3, day: 7)
            .date!
        XCTAssertEqual(DailyQuote.dayKey(for: date, calendar: calendar), "2026-03-07")
    }

    func testIsCurrentForSameDay() {
        let morning = DateComponents(calendar: calendar, year: 2026, month: 3, day: 7, hour: 6).date!
        let evening = DateComponents(calendar: calendar, year: 2026, month: 3, day: 7, hour: 23).date!
        let daily = DailyQuote(
            quote: Quote(id: 1, text: "Длинная цитата для теста", author: "A"),
            date: morning,
            calendar: calendar
        )

        XCTAssertTrue(daily.isCurrent(for: evening, calendar: calendar))
    }

    func testIsNotCurrentNextDay() {
        let day1 = DateComponents(calendar: calendar, year: 2026, month: 3, day: 7).date!
        let day2 = DateComponents(calendar: calendar, year: 2026, month: 3, day: 8).date!
        let daily = DailyQuote(
            quote: Quote(id: 1, text: "Длинная цитата для теста", author: "A"),
            date: day1,
            calendar: calendar
        )

        XCTAssertFalse(daily.isCurrent(for: day2, calendar: calendar))
    }

    func testCodableRoundTrip() throws {
        let daily = DailyQuote(
            quote: Quote(id: 42, text: "Текст цитаты", author: "Автор"),
            dayKey: "2026-03-07"
        )

        let data = try JSONEncoder().encode(daily)
        let decoded = try JSONDecoder().decode(DailyQuote.self, from: data)

        XCTAssertEqual(decoded, daily)
    }
}

// MARK: - DailyQuoteStore 存储
// MARK: - Хранилище DailyQuoteStore

final class DailyQuoteStoreTests: XCTestCase {

    private func makeStore() -> (DefaultsDailyQuoteStore, UserDefaults, String) {
        let suite = "test.daily.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return (DefaultsDailyQuoteStore(defaults: defaults), defaults, suite)
    }

    func testSaveAndLoad() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }

        let daily = DailyQuote(
            quote: Quote(id: 7, text: "Цитата", author: "Автор"),
            dayKey: "2026-03-07"
        )
        store.save(daily)

        XCTAssertEqual(store.load(), daily)
    }

    func testLoadNilWhenEmpty() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }

        XCTAssertNil(store.load())
    }

    func testClear() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }

        store.save(DailyQuote(
            quote: Quote(id: 1, text: "Цитата", author: "A"),
            dayKey: "2026-03-07"
        ))
        store.clear()

        XCTAssertNil(store.load())
    }
}

// MARK: - 随机语言
// MARK: - Случайный язык

final class RandomLanguageTests: XCTestCase {

    func testConcreteExcludesRandom() {
        XCTAssertFalse(QuoteLanguage.concrete.contains(.random))
        XCTAssertEqual(QuoteLanguage.concrete.count, 3)
    }

    func testResolvedNeverReturnsRandom() {
        for _ in 0..<50 {
            let resolved = QuoteLanguage.random.resolved()
            XCTAssertNotEqual(resolved, .random)
            XCTAssertTrue(QuoteLanguage.concrete.contains(resolved))
        }
    }

    func testResolvedKeepsConcreteLanguage() {
        XCTAssertEqual(QuoteLanguage.chinese.resolved(), .chinese)
        XCTAssertEqual(QuoteLanguage.english.resolved(), .english)
        XCTAssertEqual(QuoteLanguage.russian.resolved(), .russian)
    }

    func testAllCasesIncludeRandom() {
        XCTAssertTrue(QuoteLanguage.allCases.contains(.random))
    }

    func testFilterAcceptsAnyConcreteLanguageInRandomMode() {
        XCTAssertTrue(LanguageFilter.accepts("生活不止眼前的苟且，还有诗和远方。", for: .random))
        XCTAssertTrue(LanguageFilter.accepts("Мы в ответе за тех, кого приручили.", for: .random))
        XCTAssertTrue(LanguageFilter.accepts("Simplicity is the ultimate sophistication.", for: .random))
        XCTAssertFalse(LanguageFilter.accepts("12345 !!! ---", for: .random))
    }
}

// MARK: - 视图模型中的今日名言
// MARK: - Цитата дня в модели представления

@MainActor
final class DailyQuoteViewModelTests: XCTestCase {

    private final class Clock {
        var now = Date(timeIntervalSince1970: 1_780_000_000)
        func advance(days: Int) { now = now.addingTimeInterval(Double(days) * 86_400) }
    }

    private final class MemoryDailyStore: DailyQuoteStoring, @unchecked Sendable {
        var stored: DailyQuote?
        func load() -> DailyQuote? { stored }
        func save(_ daily: DailyQuote) { stored = daily }
        func clear() { stored = nil }
    }

    private func makeViewModel(
        clock: Clock = Clock(),
        dailyStore: MemoryDailyStore = MemoryDailyStore(),
        remote: MockRemoteSource = MockRemoteSource()
    ) -> QuoteListViewModel {
        QuoteListViewModel(
            remote: remote,
            store: MockQuoteStore(),
            bankStorage: MockBankStorage(),
            seedProvider: { _ in makeQuotes(from: 1, count: 60) },
            dailyStore: dailyStore,
            clock: { clock.now }
        )
    }

    func testDisabledReturnsNoDailyQuote() async {
        let viewModel = makeViewModel()

        let quote = await viewModel.prepareDailyQuote(language: .english, enabled: false)

        XCTAssertNil(quote)
        XCTAssertNil(viewModel.dailyQuote)
        XCTAssertFalse(viewModel.isDailyQuoteExpanded)
    }

    func testCreatesDailyQuoteWhenEnabled() async {
        let viewModel = makeViewModel()

        let quote = await viewModel.prepareDailyQuote(language: .english, enabled: true)

        XCTAssertNotNil(quote)
        XCTAssertNotNil(viewModel.dailyQuote)
    }

    func testSameDayReusesStoredQuote() async {
        let clock = Clock()
        let store = MemoryDailyStore()
        let viewModel = makeViewModel(clock: clock, dailyStore: store)

        let first = await viewModel.prepareDailyQuote(language: .english, enabled: true)
        clock.advance(days: 0)
        let second = await viewModel.prepareDailyQuote(language: .english, enabled: true)

        XCTAssertEqual(first, second, "В течение дня цитата не должна меняться")
    }

    func testNextDayProducesNewQuote() async {
        let clock = Clock()
        let store = MemoryDailyStore()
        let viewModel = makeViewModel(clock: clock, dailyStore: store)

        _ = await viewModel.prepareDailyQuote(language: .english, enabled: true)
        let firstDayKey = viewModel.dailyQuote?.dayKey

        clock.advance(days: 1)
        _ = await viewModel.prepareDailyQuote(language: .english, enabled: true)
        let secondDayKey = viewModel.dailyQuote?.dayKey

        XCTAssertNotEqual(firstDayKey, secondDayKey, "На следующий день цитата обновляется")
    }

    func testRolloverCheckReturnsFalseOnSameDay() async {
        let clock = Clock()
        let viewModel = makeViewModel(clock: clock, dailyStore: MemoryDailyStore())
        _ = await viewModel.prepareDailyQuote(language: .english, enabled: true)

        let changed = await viewModel.refreshDailyQuoteIfNeeded(
            language: .english,
            enabled: true
        )

        XCTAssertFalse(changed, "В тот же день обновления быть не должно")
    }

    func testRolloverCheckPicksNewQuoteNextDay() async {
        let clock = Clock()
        let viewModel = makeViewModel(clock: clock, dailyStore: MemoryDailyStore())
        _ = await viewModel.prepareDailyQuote(language: .english, enabled: true)
        let firstKey = viewModel.dailyQuote?.dayKey

        clock.advance(days: 1)
        let changed = await viewModel.refreshDailyQuoteIfNeeded(
            language: .english,
            enabled: true
        )

        XCTAssertTrue(changed, "На следующий день цитата должна обновиться")
        XCTAssertNotEqual(viewModel.dailyQuote?.dayKey, firstKey)
    }

    func testRolloverCheckDoesNothingWhenDisabled() async {
        let clock = Clock()
        let viewModel = makeViewModel(clock: clock, dailyStore: MemoryDailyStore())
        _ = await viewModel.prepareDailyQuote(language: .english, enabled: true)

        clock.advance(days: 1)
        let changed = await viewModel.refreshDailyQuoteIfNeeded(
            language: .english,
            enabled: false
        )

        XCTAssertFalse(changed, "При выключенной функции ничего не меняется")
    }

    func testLaunchPresentsExpanded() async {
        let viewModel = makeViewModel()
        _ = await viewModel.prepareDailyQuote(language: .chinese, enabled: true)

        viewModel.presentDailyQuoteOnLaunch()

        XCTAssertTrue(viewModel.isDailyQuoteExpanded)
    }

    func testCollapseAndExpand() async {
        let viewModel = makeViewModel()
        _ = await viewModel.prepareDailyQuote(language: .chinese, enabled: true)
        viewModel.presentDailyQuoteOnLaunch()
        XCTAssertTrue(viewModel.isDailyQuoteExpanded)

        viewModel.collapseDailyQuote()
        XCTAssertFalse(viewModel.isDailyQuoteExpanded)

        viewModel.expandDailyQuote()
        XCTAssertTrue(viewModel.isDailyQuoteExpanded)
    }

    func testExpandDoesNothingWithoutQuote() {
        let viewModel = makeViewModel()

        viewModel.expandDailyQuote()

        XCTAssertFalse(viewModel.isDailyQuoteExpanded)
    }
}
