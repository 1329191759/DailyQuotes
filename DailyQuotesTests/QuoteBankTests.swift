import XCTest
@testable import DailyQuotes

@MainActor
final class QuoteBankTests: XCTestCase {

    private func makeBank(seedCount: Int = 40) -> QuoteBank {
        QuoteBank(
            language: .english,
            seed: makeQuotes(from: 1, count: seedCount),
            storage: MockBankStorage()
        )
    }

    func testStartsWithSeedQuotes() {
        let bank = makeBank(seedCount: 25)
        XCTAssertEqual(bank.count, 25)
    }

    func testPickNeverRepeatsWithinCycle() {
        let bank = makeBank(seedCount: 10)
        var seen: Set<Int> = []
        var lastID: Int?

        for _ in 0..<10 {
            guard let quote = bank.pick(excluding: lastID) else {
                return XCTFail("Банк должен возвращать цитаты")
            }
            XCTAssertFalse(seen.contains(quote.id), "Повтор внутри цикла недопустим")
            seen.insert(quote.id)
            lastID = quote.id
            bank.recordShown(quote)
        }
    }

    func testRecycleTriggersAfterThirtyShown() {
        let bank = makeBank(seedCount: 60)
        var recycles = 0

        for _ in 0..<30 {
            guard let quote = bank.pick(excluding: nil) else { break }
            if bank.recordShown(quote) { recycles += 1 }
        }

        XCTAssertEqual(recycles, 1, "Переработка должна срабатывать каждые 30 показов")
    }

    func testRecycleRemovesShownEntries() {
        let bank = makeBank(seedCount: 60)
        var shown: [Int] = []

        for _ in 0..<30 {
            guard let quote = bank.pick(excluding: nil) else { break }
            shown.append(quote.id)
            bank.recordShown(quote)
        }

        let remaining = Set(bank.entries.map(\.id))
        for id in shown {
            XCTAssertFalse(remaining.contains(id), "Показанная цитата должна покинуть банк")
        }
    }

    func testAbsorbRespectsCapacity() {
        let bank = makeBank(seedCount: 5)
        bank.absorb(makeQuotes(from: 1000, count: 400))

        XCTAssertLessThanOrEqual(bank.count, QuoteBank.capacity)
    }

    func testAbsorbDeduplicates() {
        let bank = makeBank(seedCount: 10)
        let duplicate = bank.entries[0]

        bank.absorb([duplicate])

        XCTAssertEqual(bank.entries.filter { $0.id == duplicate.id }.count, 1)
    }

    func testPickExcludesRequestedID() {
        let bank = makeBank(seedCount: 2)
        let all = Set(bank.entries.map(\.id))

        for _ in 0..<20 {
            let picked = bank.pick(excluding: bank.entries[0].id)
            XCTAssertNotEqual(picked?.id, bank.entries[0].id)
            XCTAssertTrue(all.contains(picked?.id ?? -1))
        }
    }

    func testRecycleRetiresShownQuotesAndKeepsBankUsable() {
        let bank = makeBank(seedCount: 60)
        var shown: [Int] = []

        for _ in 0..<30 {
            guard let quote = bank.pick(excluding: nil) else { break }
            shown.append(quote.id)
            bank.recordShown(quote)
        }

        // // 已移除的名言离开池子，其余仍可使用。
        // // Удалённые цитаты покидают пул, остальные остаются доступными.
        let afterRecycle = Set(bank.entries.map(\.id))
        XCTAssertFalse(shown.contains { afterRecycle.contains($0) })
        XCTAssertEqual(bank.count, 30, "Остаётся ровно непоказанная половина")
        XCTAssertNotNil(bank.pick(excluding: nil), "Банк должен оставаться рабочим")
    }

    func testBankStartsNewEpochInsteadOfRunningDry() {
        let bank = makeBank(seedCount: 40)

        // // 一直取到超过种子数量；新周期必须持续供得上名言。
        // // Забираем заметно больше размера затравки: новый цикл должен продолжать выдавать цитаты.
        for _ in 0..<200 {
            guard let quote = bank.pick(excluding: nil) else {
                return XCTFail("Банк иссяк — должен начинаться новый цикл")
            }
            bank.recordShown(quote)
        }

        XCTAssertNotNil(bank.pick(excluding: nil))
    }
}

@MainActor
final class QuoteBankStorageTests: XCTestCase {

    func testSaveAndLoadRoundTrip() {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("banktest-\(UUID().uuidString)")
        let storage = FileQuoteBankStorage(directory: dir)
        let quotes = makeQuotes(from: 1, count: 3)

        storage.save(quotes, language: .english)
        let loaded = storage.load(language: .english)

        XCTAssertEqual(loaded, quotes)
        try? FileManager.default.removeItem(at: dir)
    }

    func testLoadReturnsNilForUnknownLanguage() {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("banktest-\(UUID().uuidString)")
        let storage = FileQuoteBankStorage(directory: dir)

        XCTAssertNil(storage.load(language: .russian))
        try? FileManager.default.removeItem(at: dir)
    }
}
