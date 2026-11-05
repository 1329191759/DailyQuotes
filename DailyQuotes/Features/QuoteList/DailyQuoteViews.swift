import SwiftUI

/// 顶部收起的今日名言条：用户开始操作后显示，可随时下拉展开。
/// Свёрнутая полоса с цитатой дня сверху: появляется после действий пользователя, разворачивается нажатием.
struct DailyQuoteBar: View {
    let quote: Quote
    let strings: L10n.Strings
    let onExpand: () -> Void

    var body: some View {
        Button(action: onExpand) {
            HStack(spacing: 10) {
                Image(systemName: "quote.opening")
                    .font(.caption)
                    .foregroundStyle(.tint)

                Text(quote.text)
                    .font(.footnote)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)

                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("dailyQuoteBar")
        .accessibilityLabel(strings.dailyQuoteShow)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

/// 今日名言的全屏展示，启动时显示。
/// Полноэкранный показ цитаты дня при запуске.
struct DailyQuoteSheet: View {
    let quote: Quote
    let dayKey: String
    let strings: L10n.Strings
    let onCollapse: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 8) {
                    Image(systemName: "sun.max.fill")
                        .foregroundStyle(.orange)
                    Text(strings.dailyQuoteShow)
                        .font(.headline)
                    Spacer()
                    Text(dayKey)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(quote.text)
                    .font(.title2)
                    .fontWeight(.medium)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("dailyQuoteText")

                Text("— \(quote.author)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 20)

            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "chevron.down")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text(strings.dailyQuoteCollapse)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
        .onTapGesture(perform: onCollapse)
        .accessibilityIdentifier("dailyQuoteSheet")
    }
}
