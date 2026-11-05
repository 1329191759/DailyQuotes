import SwiftUI
import SwiftData

/// 收藏页：从数据库（SwiftData 查询）读取，并提供带确认的一键清空。
/// Экран избранного: читает из базы (запрос SwiftData) и предлагает очистку с подтверждением.
struct FavoritesView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \SavedQuote.savedAt, order: .reverse)
    private var savedQuotes: [SavedQuote]

    @State private var showClearConfirmation = false

    private var t: L10n.Strings { L10n.strings(for: settings.appLanguage) }

    var body: some View {
        NavigationStack {
            Group {
                if savedQuotes.isEmpty {
                    ContentUnavailableView {
                        Label(t.emptyTitle, systemImage: "bookmark")
                    } description: {
                        Text(t.emptyDescription)
                    }
                } else {
                    List {
                        ForEach(savedQuotes) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.text)
                                    .font(.body)
                                Text("— \(item.author)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete(perform: delete)
                    }
                    .listStyle(.insetGrouped)
                    .accessibilityIdentifier("favoritesList")
                }
            }
            .navigationTitle(t.favorites)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !savedQuotes.isEmpty {
                        Button(role: .destructive) {
                            showClearConfirmation = true
                        } label: {
                            Label(t.clearAll, systemImage: "trash")
                        }
                        .accessibilityIdentifier("clearAllButton")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(t.done) { dismiss() }
                }
            }
            .confirmationDialog(
                t.clearAllConfirmTitle,
                isPresented: $showClearConfirmation,
                titleVisibility: .visible
            ) {
                Button(t.clearAll, role: .destructive) {
                    clearAll()
                }
                Button(t.cancel, role: .cancel) {}
            } message: {
                Text(t.clearAllConfirmMessage)
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        // 先取出对象再删除：@Query 可能在循环中重新求值，直接按下标访问会越界。
        // Сначала материализуем объекты: @Query может пересчитаться в цикле.
        let doomed = offsets.compactMap { savedQuotes.indices.contains($0) ? savedQuotes[$0] : nil }
        for item in doomed {
            context.delete(item)
        }
        try? context.save()
    }

    /// 在一个事务里删除全部已保存的名言。
    /// Удаляет все сохранённые цитаты одной транзакцией.
    private func clearAll() {
        do {
            try context.delete(model: SavedQuote.self)
            try context.save()
        } catch {
            // 失败时不提示用户，列表保持原样。
            // При ошибке список остаётся без изменений.
        }
    }
}
