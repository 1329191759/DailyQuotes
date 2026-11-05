import SwiftUI
import SwiftData

/// 设置页：界面语言、名言语言、外观主题，以及完整的「还原到初始状态」操作。
/// Экран настроек: язык интерфейса, язык цитат, тема оформления и полный сброс.
struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var showResetConfirmation = false

    private var t: L10n.Strings { L10n.strings(for: settings.appLanguage) }

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            Form {
                Section(t.appLanguage) {
                    Picker(t.appLanguage, selection: $settings.appLanguage) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.nativeName).tag(language)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("appLanguagePicker")
                }

                Section {
                    Picker(t.quoteLanguage, selection: $settings.quoteLanguage) {
                        ForEach(QuoteLanguage.allCases) { language in
                            Text(language.displayName(in: settings.appLanguage)).tag(language)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("quoteLanguagePicker")
                } header: {
                    Text(t.quoteLanguage)
                } footer: {
                    if settings.quoteLanguage == .russian {
                        Text(t.russianOfflineNote)
                    } else if settings.quoteLanguage == .random {
                        Text(t.randomLanguageHint)
                    }
                }

                Section {
                    Toggle(t.dailyQuoteToggle, isOn: $settings.dailyQuoteEnabled)
                        .accessibilityIdentifier("dailyQuoteToggle")
                } header: {
                    Text(t.dailyQuoteSection)
                } footer: {
                    Text(t.dailyQuoteHint)
                }

                Section(t.appearanceSection) {
                    Picker(t.themeLabel, selection: $settings.theme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.label(for: settings.appLanguage)).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("themePicker")
                }

                Section(t.aboutSection) {
                    Button(role: .destructive) {
                        showResetConfirmation = true
                    } label: {
                        Label(t.resetAll, systemImage: "arrow.counterclockwise")
                    }
                    .accessibilityIdentifier("resetAllButton")
                }
            }
            .navigationTitle(t.settings)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(t.done) { dismiss() }
                }
            }
            .confirmationDialog(
                t.resetAllConfirmTitle,
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button(t.reset, role: .destructive) {
                    clearFavorites()
                    settings.reset()
                }
                Button(t.cancel, role: .cancel) {}
            } message: {
                Text(t.resetAllConfirmMessage)
            }
        }
    }

    private func clearFavorites() {
        do {
            try context.delete(model: SavedQuote.self)
            try context.save()
        } catch {
            // 失败时保持列表原样。
            // При ошибке список остаётся без изменений.
        }
    }
}
