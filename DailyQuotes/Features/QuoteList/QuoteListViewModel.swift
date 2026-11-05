import Foundation
import Observation
import SwiftUI   // withAnimation for the daily-quote fold

/// 主界面的视图模型。
/// Модель представления главного экрана.
@MainActor
@Observable
final class QuoteListViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded(Quote)
        case failed(String)
    }

    private(set) var state: LoadState = .idle
    private(set) var isCurrentSaved = false
    private(set) var history = QuoteHistory()
    private(set) var isRefreshing = false
    /// 当前库中的名言数量（首次加载前为 0）。
    /// Количество цитат в банке (0 до первой загрузки).
    private(set) var bankCount = 0

    private let remote: RemoteQuoteSource
    private let store: QuoteStoring
    private let bankStorage: QuoteBankStoring
    private let seedProvider: (QuoteLanguage) -> [Quote]
    private let clock: () -> Date
    private let dailyStore: DailyQuoteStoring

    private var bank: QuoteBank?
    private var isRefilling = false

    // // MARK: - 今日名言
    // // MARK: - Цитата дня

    /// 今日名言，全天保持不变。
    /// Цитата дня, не меняется в течение суток.
    private(set) var dailyQuote: DailyQuote?
    /// 今日名言处于全屏展示状态时为真。
    /// Истина, пока цитата дня на весь экран.
    private(set) var isDailyQuoteExpanded = false

    init(
        remote: RemoteQuoteSource,
        store: QuoteStoring,
        bankStorage: QuoteBankStoring,
        seedProvider: @escaping (QuoteLanguage) -> [Quote],
        dailyStore: DailyQuoteStoring = DefaultsDailyQuoteStore(),
        clock: @escaping () -> Date = Date.init
    ) {
        self.remote = remote
        self.store = store
        self.bankStorage = bankStorage
        self.seedProvider = seedProvider
        self.dailyStore = dailyStore
        self.clock = clock
    }

    var quote: Quote? {
        if case .loaded(let quote) = state { return quote }
        return nil
    }

    var canGoBack: Bool { history.canGoBack }
    var canGoForward: Bool { history.canGoForward }

    // // MARK: - 今日名言
    // // MARK: - Цитата дня

    /// 准备今日名言：已存的是今天的就复用，否则从库里挑新的，保证每天只换一次；功能关闭时返回 nil。
    /// Готовит цитату дня: сохранённая за сегодня переиспользуется, иначе берётся новая; при выключенной функции nil.
    func prepareDailyQuote(language: QuoteLanguage, enabled: Bool) async -> Quote? {
        guard enabled else {
            dailyQuote = nil
            isDailyQuoteExpanded = false
            return nil
        }

        let today = clock()

        if let stored = dailyStore.load(), stored.isCurrent(for: today) {
            dailyQuote = stored
            return stored.quote
        }

        // 新的一天（或首次启动）：从当天的库里挑一条。
        // Новый день (или первый запуск): выбираем из банка за сегодня.
        let resolved = language.resolved()
        let bank = ensureBank(language: resolved)

        // 首屏绝不等网络：内置种子足够立刻显示，补充放到后台。
        // Первый экран не ждёт сеть: затравки хватает, пополнение идёт в фоне.
        if bank.count < 40 {
            Task { [weak self] in
                await self?.refillToCapacity(language: resolved)
            }
        }

        let picked: Quote?
        if let chosen = bank.pick(excluding: nil) {
            picked = chosen
            bank.recordShown(chosen)
            bankCount = bank.count
        } else {
            picked = seedProvider(resolved).first
        }

        guard let quote = picked else { return nil }
        let daily = DailyQuote(quote: quote, date: today)
        dailyStore.save(daily)
        dailyQuote = daily
        return quote
    }

    /// 检查日期是否已跨天，必要时换成新一天的今日名言。
    /// Проверяет смену суток и при необходимости готовит новую цитату дня.
    ///
    /// 应用长时间驻留后台后回到前台时调用，避免显示昨天的名言。
    /// Вызывается при возврате в активное состояние.
    @discardableResult
    func refreshDailyQuoteIfNeeded(language: QuoteLanguage, enabled: Bool) async -> Bool {
        guard enabled else { return false }

        let today = clock()
        if let current = dailyQuote, current.isCurrent(for: today) {
            return false
        }
        // 没有今日名言或已跨天，重新准备。
        // Нет цитаты дня или сутки сменились — готовим заново.
        _ = await prepareDailyQuote(language: language, enabled: enabled)
        return true
    }

    /// 用户执行任意操作时调用：把今日名言收起到顶部栏。
    /// Вызывается при любом действии: сворачивает цитату дня в верхнюю полосу.
    func collapseDailyQuote() {
        guard isDailyQuoteExpanded else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            isDailyQuoteExpanded = false
        }
    }

    /// 从收起状态把今日名言重新展开。
    /// Разворачивает цитату дня из свёрнутой полосы.
    func expandDailyQuote() {
        guard dailyQuote != nil else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            isDailyQuoteExpanded = true
        }
    }

    /// 把今日名言标记为启动后的首个画面。
    /// Помечает цитату дня как первый экран после запуска.
    func presentDailyQuoteOnLaunch() {
        guard dailyQuote != nil else { return }
        isDailyQuoteExpanded = true
    }

    // // MARK: - 加载
    // // MARK: - Загрузка

    /// 从库中取一条名言，必要时在后台从网络补充。
    /// Берёт цитату из банка и при необходимости пополняет его из сети.
    func loadQuote(language: QuoteLanguage) async {
        // 不做节流：名言来自本地库，重复点击开销很小，应当即点即应；`random` 会为这一条挑具体语言。
        // Без ограничения частоты: цитата из локального банка, ответ мгновенный; `random` выбирает конкретный язык.
        let resolved = language.resolved()
        let bank = ensureBank(language: resolved)
        bankCount = bank.count

        // 在后台补足到容量上限，界面不等待。
        // Фоновое пополнение до ёмкости; интерфейс не ждёт.
        if bank.count < QuoteBank.capacity && !isRefilling {
            Task { [weak self] in
                await self?.refillToCapacity(language: language)
            }
        }

        guard let picked = bank.pick(excluding: history.current?.id) else {
            state = .failed(QuoteAPIError.libraryMissing.errorDescription ?? "Нет доступных цитат")
            return
        }

        history.append(picked)
        state = .loaded(picked)
        isCurrentSaved = (try? store.isSaved(picked)) ?? false

        // 轮换：显示满 30 条后库开始周转。
        // Ротация: после 30 показанных цитат банк обновляется.
        if bank.recordShown(picked) {
            bankCount = bank.count
            Task { [weak self] in
                await self?.refillToCapacity(language: language)
            }
        } else {
            bankCount = bank.count
        }
    }

    /// 向前回看已显示过的名言（最多 20 条）。
    /// Шаг назад по ранее показанным цитатам (до 20).
    func goBack() {
        guard let quote = history.goBack() else { return }
        state = .loaded(quote)
        isCurrentSaved = (try? store.isSaved(quote)) ?? false
    }

    /// 向后翻回已显示过的名言（最多 20 条）。
    /// Шаг вперёд по ранее показанным цитатам (до 20).
    func goForward() {
        guard let quote = history.goForward() else { return }
        state = .loaded(quote)
        isCurrentSaved = (try? store.isSaved(quote)) ?? false
    }

    /// 切换语言时清空当前名言和历史。
    /// Сбрасывает текущую цитату и историю при смене языка.
    func resetForLanguageChange() {
        state = .idle
        isCurrentSaved = false
        history.reset()
        bank = nil
        bankCount = 0
    }

    /// 切换当前名言的收藏状态（与库无关）。
    /// Переключает избранное для текущей цитаты (не зависит от банка).
    func toggleSave() -> String? {
        guard let quote else { return nil }
        do {
            if isCurrentSaved {
                try store.remove(quote)
                isCurrentSaved = false
            } else {
                try store.save(quote)
                isCurrentSaved = true
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    // // MARK: - 私有
    // // MARK: - Приватное

    private func ensureBank(language: QuoteLanguage) -> QuoteBank {
        if let bank, bank.language == language { return bank }
        let created = QuoteBank(
            language: language,
            seed: seedProvider(language),
            storage: bankStorage
        )
        bank = created
        return created
    }

    /// 持续请求直到库达到容量上限；连续两批空数据就停止，避免失败的源无限空转。
    /// Запрашивает до ёмкости; после двух пустых пачек подряд останавливается.
    private func refillToCapacity(language: QuoteLanguage) async {
        guard !isRefilling else { return }
        isRefilling = true
        defer { isRefilling = false }

        // `random` 表示任意语言：从每个具体库各取一部分，让内容真正混合。
        // `random` — любой язык: берём долю из каждого банка для смешанного набора.
        if language == .random {
            for concrete in QuoteLanguage.concrete {
                await refillOne(concrete)
            }
            return
        }
        await refillOne(language)
    }

    private func refillOne(_ language: QuoteLanguage) async {
        let bank = ensureBank(language: language)
        var emptyStreak = 0

        while bank.count < QuoteBank.capacity && emptyStreak < 2 {
            let missing = QuoteBank.capacity - bank.count
            let batchSize = min(missing, 40)
            let fetched = await remote.fetchBatch(language: language, limit: batchSize)

            if fetched.isEmpty {
                emptyStreak += 1
                continue
            }

            let before = bank.count
            bank.absorb(fetched)
            bankCount = bank.count

            // 没有增长说明返回的内容都已在库里。
            // Нет прироста — всё полученное уже есть в банке.
            if bank.count == before {
                emptyStreak += 1
            } else {
                emptyStreak = 0
            }
        }
    }
}
