import SwiftUI
import SwiftData

/// 主界面：显示今日名言，并提供换一条、历史翻页和收藏操作。
/// Главный экран: цитата дня, обновление, навигация по истории и избранное.
struct QuoteListView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context

    @State private var viewModel: QuoteListViewModel
    @State private var showFavorites = false
    @State private var showSettings = false
    @State private var errorText: String?
    @State private var lastLoadedLanguage: QuoteLanguage?
    @State private var isAnimatingRefresh = false

    /// 用于检测应用从后台回到前台，必要时更新今日名言。
    /// Нужен для обновления цитаты дня при возврате из фона.
    @Environment(\.scenePhase) private var scenePhase

    /// 在这段时间内忽略重复点击，避免连点跳过多条；只挡误触，不影响正常浏览。
    /// Игнорирует повторные нажатия, чтобы двойное нажатие не пропускало цитату.
    private static let refreshDebounce: TimeInterval = 0.3

    init(viewModel: QuoteListViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private var t: L10n.Strings { L10n.strings(for: settings.appLanguage) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                if settings.dailyQuoteEnabled, !viewModel.isDailyQuoteExpanded,
                   let daily = viewModel.dailyQuote {
                    DailyQuoteBar(quote: daily.quote, strings: t) {
                        viewModel.expandDailyQuote()
                    }
                }

                VStack(spacing: 20) {
                    content
                    Spacer(minLength: 0)
                    historyControls
                    actions
                }
                .padding()
            }
            .navigationTitle(t.appTitle)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        collapseDailyOnInteraction()
                        showSettings = true
                    } label: {
                        Label(t.settings, systemImage: "gearshape")
                    }
                    .accessibilityIdentifier("settingsButton")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        collapseDailyOnInteraction()
                        showFavorites = true
                    } label: {
                        Label(t.favorites, systemImage: "bookmark.fill")
                    }
                    .accessibilityIdentifier("favoritesButton")
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showFavorites) {
                FavoritesView()
            }
            .fullScreenCover(isPresented: Binding(
                // 关闭开关后不再展示全屏页，避免设置与实际显示不一致。
                // Если переключатель выключен, полноэкранный показ не открывается.
                get: {
                    settings.dailyQuoteEnabled
                        && viewModel.isDailyQuoteExpanded
                        && viewModel.dailyQuote != nil
                },
                set: { if !$0 { viewModel.collapseDailyQuote() } }
            )) {
                if let daily = viewModel.dailyQuote {
                    DailyQuoteSheet(
                        quote: daily.quote,
                        dayKey: daily.dayKey,
                        strings: t
                    ) {
                        viewModel.collapseDailyQuote()
                    }
                }
            }
            .task(id: settings.quoteLanguage) {
                await reloadForLanguageIfNeeded()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                Task { await checkDailyQuoteRollover() }
            }
            .alert(
                t.errorTitle,
                isPresented: Binding(
                    get: { errorText != nil },
                    set: { if !$0 { errorText = nil } }
                )
            ) {
                Button(t.done) { errorText = nil }
            } message: {
                Text(errorText ?? "")
            }
        }
    }

    private func reloadForLanguageIfNeeded() async {
        if lastLoadedLanguage != settings.quoteLanguage {
            viewModel.resetForLanguageChange()
            lastLoadedLanguage = settings.quoteLanguage
        }

        // 今日名言在启动时准备一次，并在用户操作前全屏展示。
        // Цитата дня готовится один раз при запуске и показывается на весь экран.
        if viewModel.dailyQuote == nil {
            _ = await viewModel.prepareDailyQuote(
                language: settings.quoteLanguage,
                enabled: settings.dailyQuoteEnabled
            )
            viewModel.presentDailyQuoteOnLaunch()
        }

        if case .idle = viewModel.state {
            await viewModel.loadQuote(language: settings.quoteLanguage)
        }
    }

    /// 回到前台时检查是否已跨天；跨天则换成新一天的今日名言。
    /// При возврате в активное состояние проверяем смену суток.
    private func checkDailyQuoteRollover() async {
        let changed = await viewModel.refreshDailyQuoteIfNeeded(
            language: settings.quoteLanguage,
            enabled: settings.dailyQuoteEnabled
        )
        guard changed else { return }
        // 新的一天：再次以全屏展示，和首次启动保持一致。
        // Новый день: снова показываем на весь экран, как при запуске.
        viewModel.presentDailyQuoteOnLaunch()
    }

    /// 任何主动操作都会把今日名言收起到顶部栏。
    /// Любое осознанное действие сворачивает цитату дня в верхнюю полосу.
    private func collapseDailyOnInteraction() {
        viewModel.collapseDailyQuote()
    }

    // // MARK: - 历史
    // // MARK: - История

    private var historyControls: some View {
        HStack(spacing: 12) {
            Button {
                collapseDailyOnInteraction()
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.goBack()
                }
            } label: {
                Label(t.previousQuote, systemImage: "chevron.left")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.canGoBack)
            .accessibilityIdentifier("previousQuoteButton")

            Button {
                collapseDailyOnInteraction()
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.goForward()
                }
            } label: {
                Label(t.nextQuote, systemImage: "chevron.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.canGoForward)
            .accessibilityIdentifier("nextQuoteButton")
        }
    }

    // // MARK: - 内容
    // // MARK: - Содержимое

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView(t.loading)
                .frame(maxWidth: .infinity, minHeight: 200)

        case .loaded(let quote):
            QuoteCard(quote: quote, isSaved: viewModel.isCurrentSaved, strings: t)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

        case .failed(let message):
            ContentUnavailableView {
                Label(t.errorTitle, systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button(t.retry) {
                    Task { await refresh() }
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(minHeight: 200)
        }
    }

    // // MARK: - 按钮
    // // MARK: - Кнопки

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                Task { await refresh() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .rotationEffect(.degrees(isAnimatingRefresh ? 360 : 0))
                        .animation(.easeInOut(duration: Self.refreshDebounce), value: isAnimatingRefresh)
                    Text(t.newQuote)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isAnimatingRefresh)
            .accessibilityIdentifier("refreshButton")

            Button {
                collapseDailyOnInteraction()
                if let problem = viewModel.toggleSave() {
                    errorText = t.saveFailed + problem
                }
            } label: {
                Label(
                    viewModel.isCurrentSaved ? t.unsave : t.save,
                    systemImage: viewModel.isCurrentSaved ? "bookmark.slash" : "bookmark"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(viewModel.quote == nil)
            .accessibilityIdentifier("saveButton")
        }
    }

    /// 换一条名言。库在本地，因此立即返回；旋转动画只是装饰。
    /// Загружает новую цитату. Банк локальный, ответ мгновенный; вращение — оформление.
    private func refresh() async {
        guard !isAnimatingRefresh else { return }
        collapseDailyOnInteraction()
        isAnimatingRefresh = true

        await viewModel.loadQuote(language: settings.quoteLanguage)

        // 短暂保持锁定，让快速的第二下点击被吞掉，而不是直接跳到下一条。
        // Короткая блокировка: быстрое второе нажатие поглощается, а не пропускает цитату.
        try? await Task.sleep(nanoseconds: UInt64(Self.refreshDebounce * 1_000_000_000))
        isAnimatingRefresh = false
    }
}
