import SwiftUI
import SwiftData

@main
struct DailyQuotesApp: App {
    private let container: ModelContainer
    @State private var settings: AppSettings

    init() {
        do {
            container = try ModelContainer(for: SavedQuote.self)
        } catch {
            fatalError("Не удалось создать хранилище: \(error)")
        }
        _settings = State(initialValue: AppSettings())
    }

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
                .environment(settings)
                .environment(\.locale, Locale(identifier: localeIdentifier))
                .preferredColorScheme(settings.theme.colorScheme)
        }
        .modelContainer(container)
    }

    private var localeIdentifier: String {
        switch settings.appLanguage {
        case .chinese: return "zh_Hans"
        case .english: return "en"
        case .russian: return "ru"
        }
    }
}

/// 组装根：把远程源、持久化名言库和数据库接入视图模型。
/// Корень композиции: связывает удалённый источник, банк и базу данных с моделью представления.
struct RootView: View {
    let container: ModelContainer

    private static let bankStorage = FileQuoteBankStorage()
    private static let seeds = QuoteSeedProvider()

    var body: some View {
        QuoteListView(
            viewModel: QuoteListViewModel(
                remote: BulkQuoteSource(),
                store: SwiftDataQuoteStore(context: container.mainContext),
                bankStorage: Self.bankStorage,
                seedProvider: { Self.seeds.quotes(for: $0) }
            )
        )
    }
}

/// 读取内置的初始名言，用作语言库的种子。
/// Загружает встроенные стартовые цитаты — затравку для банка языка.
struct QuoteSeedProvider {
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func quotes(for language: QuoteLanguage) -> [Quote] {
        // `random` 会合并三个库的种子，因此联网前也能拿到混合内容。
        // `random` берёт затравку из всех трёх банков, поэтому смешанный набор доступен ещё до ответа сети.
        if language == .random {
            return QuoteLanguage.concrete.flatMap { quotes(for: $0) }
        }

        let name: String
        let base: Int
        switch language {
        case .chinese: name = "zh_quotes"; base = 800_000
        case .english: name = "en_quotes"; base = 700_000
        case .russian: name = "russian_quotes"; base = 900_000
        case .random: name = ""; base = 0   // handled above
        }

        guard let url = bundle.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(QuoteFileDTO.self, from: data) else {
            return []
        }

        return file.quotes.enumerated().map { index, item in
            Quote(id: base + index, text: item.quote, author: item.author)
        }
    }
}
