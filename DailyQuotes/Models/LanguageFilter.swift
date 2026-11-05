import Foundation

/// 按文字系统判断语言，保证每个语言的库只含该语言内容。
/// Определение языка по письменности: банк каждого языка остаётся одноязычным.
enum LanguageFilter {

    /// 判断 `text` 是否属于指定语言。
    /// Проверяет, относится ли `text` к указанному языку.
    static func accepts(_ text: String, for language: QuoteLanguage) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 8 else { return false }

        let cjk = count(of: \.isCJK, in: trimmed)
        let cyrillic = count(of: \.isCyrillic, in: trimmed)
        let latin = count(of: \.isLatinLetter, in: trimmed)

        // 参与比较的有效字母数。
        // Значимые буквы для сравнения.
        let letters = cjk + cyrillic + latin
        guard letters > 0 else { return false }

        switch language {
        case .chinese:
            // 要求汉字占主导，可过滤掉纯英文条目。
            // Требует преобладания иероглифов — отсекает английские строки.
            return Double(cjk) / Double(letters) >= 0.5 && cjk >= 4
        case .russian:
            return Double(cyrillic) / Double(letters) >= 0.5 && cyrillic >= 8
        case .english:
            // 拉丁字母占主导，且不含中文和西里尔字母。
            // Преобладает латиница, без иероглифов и кириллицы.
            return Double(latin) / Double(letters) >= 0.8 && cjk == 0 && cyrillic == 0
        case .random:
            // 随机模式：只要文本明显属于三种语言之一就接受，调用方随后再解析具体语言。
            // Случайный режим: принимает текст, явно относящийся к одному из трёх языков.
            let cjkShare = Double(cjk) / Double(letters)
            let cyrillicShare = Double(cyrillic) / Double(letters)
            let latinShare = Double(latin) / Double(letters)

            if cjkShare >= 0.5 && cjk >= 4 { return true }
            if cyrillicShare >= 0.5 && cyrillic >= 8 { return true }
            if latinShare >= 0.8 && cjk == 0 && cyrillic == 0 { return true }
            return false
        }
    }

    private static func count(
        of predicate: (Character) -> Bool,
        in text: String
    ) -> Int {
        text.reduce(into: 0) { total, character in
            if predicate(character) { total += 1 }
        }
    }
}

private extension Character {
    var isCJK: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        switch scalar.value {
        case 0x4E00...0x9FFF,   // CJK Unified Ideographs
             0x3400...0x4DBF,   // Extension A
             0xF900...0xFAFF:   // Compatibility Ideographs
            return true
        default:
            return false
        }
    }

    var isCyrillic: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return (0x0400...0x04FF).contains(scalar.value)
    }

    var isLatinLetter: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        switch scalar.value {
        case 0x41...0x5A, 0x61...0x7A:
            return true
        case 0xC0...0x24F:              // Latin-1 Supplement / Extended
            return true
        default:
            return false
        }
    }
}
