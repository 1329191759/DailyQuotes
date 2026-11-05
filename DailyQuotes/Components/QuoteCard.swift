import SwiftUI

/// 可复用的名言卡片组件（标签 + 文本元素）。
/// Переиспользуемый компонент карточки цитаты (метка + текстовые элементы).
struct QuoteCard: View {
    let quote: Quote
    let isSaved: Bool
    let strings: L10n.Strings

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "quote.opening")
                .font(.title)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text(quote.text)
                .font(.title3)
                .fontWeight(.medium)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("quoteText")

            HStack {
                Text("— \(quote.author)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if isSaved {
                    Label(strings.inFavorites, systemImage: "bookmark.fill")
                        .font(.caption)
                        .foregroundStyle(.tint)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }
}
