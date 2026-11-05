import Foundation

/// 运行时本地化。应用内切换语言不能要求重启，因此文本从这些表里查，而不用 `.strings`。
/// Локализация во время работы. Смена языка не требует перезапуска: строки берутся из таблиц, а не из `.strings`.
enum L10n {
    struct Strings {
        let appTitle: String
        let newQuote: String
        let save: String
        let unsave: String
        let favorites: String
        let settings: String
        let done: String
        let loading: String
        let errorTitle: String
        let retry: String
        let inFavorites: String
        let emptyTitle: String
        let emptyDescription: String
        let clearAll: String
        let clearAllConfirmTitle: String
        let clearAllConfirmMessage: String
        let cancel: String
        let delete: String
        let appLanguage: String
        let quoteLanguage: String
        let aboutSection: String
        let resetAll: String
        let resetAllConfirmTitle: String
        let resetAllConfirmMessage: String
        let reset: String
        let saveFailed: String
        let russianOfflineNote: String
        let previousQuote: String
        let nextQuote: String
        let appearanceSection: String
        let themeLabel: String
        let themeSystem: String
        let themeLight: String
        let themeDark: String
        let dailyQuoteSection: String
        let dailyQuoteToggle: String
        let dailyQuoteHint: String
        let dailyQuoteCollapse: String
        let dailyQuoteShow: String
        let randomLanguage: String
        let randomLanguageHint: String
    }

    static func strings(for language: AppLanguage) -> Strings {
        switch language {
        case .chinese: return zh
        case .english: return en
        case .russian: return ru
        }
    }

    // // MARK: 中文
    // // MARK: Китайский

    static let zh = Strings(
        appTitle: "每日名言",
        newQuote: "换一条",
        save: "收藏",
        unsave: "取消收藏",
        favorites: "收藏夹",
        settings: "设置",
        done: "完成",
        loading: "加载中…",
        errorTitle: "出错了",
        retry: "重试",
        inFavorites: "已收藏",
        emptyTitle: "还没有收藏",
        emptyDescription: "在首页把喜欢的名言收藏起来吧。",
        clearAll: "清空收藏",
        clearAllConfirmTitle: "清空收藏夹？",
        clearAllConfirmMessage: "将删除全部收藏，此操作无法撤销。",
        cancel: "取消",
        delete: "删除",
        appLanguage: "界面语言",
        quoteLanguage: "名言语言",
        aboutSection: "其他",
        resetAll: "一键还原",
        resetAllConfirmTitle: "还原到初始状态？",
        resetAllConfirmMessage: "将清空全部收藏并恢复默认设置，等同于刚安装的状态。",
        reset: "还原",
        saveFailed: "保存失败：",
        russianOfflineNote: "俄语名言使用内置库",
        previousQuote: "上一条",
        nextQuote: "下一条",
        appearanceSection: "外观",
        themeLabel: "主题",
        themeSystem: "跟随系统",
        themeLight: "浅色",
        themeDark: "深色",
        dailyQuoteSection: "今日名言",
        dailyQuoteToggle: "显示今日名言",
        dailyQuoteHint: "打开 App 时先显示当天名言，下滑可收起。",
        dailyQuoteCollapse: "收起",
        dailyQuoteShow: "今日名言",
        randomLanguage: "随机",
        randomLanguageHint: "每次出现的名言会从中、英、俄三种语言里随机选择。"
    )

    // // MARK: 英文
    // // MARK: Английский

    static let en = Strings(
        appTitle: "Quote of the Day",
        newQuote: "Another quote",
        save: "Save",
        unsave: "Remove from favorites",
        favorites: "Favorites",
        settings: "Settings",
        done: "Done",
        loading: "Loading…",
        errorTitle: "Something went wrong",
        retry: "Try again",
        inFavorites: "Saved",
        emptyTitle: "Nothing saved yet",
        emptyDescription: "Save quotes you like from the main screen.",
        clearAll: "Clear favorites",
        clearAllConfirmTitle: "Clear all favorites?",
        clearAllConfirmMessage: "This deletes every saved quote and cannot be undone.",
        cancel: "Cancel",
        delete: "Delete",
        appLanguage: "Interface language",
        quoteLanguage: "Quote language",
        aboutSection: "Other",
        resetAll: "Reset app",
        resetAllConfirmTitle: "Reset to initial state?",
        resetAllConfirmMessage: "Clears all favorites and restores default settings, as if freshly installed.",
        reset: "Reset",
        saveFailed: "Could not save: ",
        russianOfflineNote: "Russian quotes use the bundled library",
        previousQuote: "Previous",
        nextQuote: "Next",
        appearanceSection: "Appearance",
        themeLabel: "Theme",
        themeSystem: "System",
        themeLight: "Light",
        themeDark: "Dark",
        dailyQuoteSection: "Quote of the day",
        dailyQuoteToggle: "Show quote of the day",
        dailyQuoteHint: "Opens on today's quote; swipe down to collapse it.",
        dailyQuoteCollapse: "Collapse",
        dailyQuoteShow: "Quote of the day",
        randomLanguage: "Random",
        randomLanguageHint: "Each quote is picked from Chinese, English or Russian at random."
    )

    // // MARK: 俄语
    // // MARK: Русский

    static let ru = Strings(
        appTitle: "Цитата дня",
        newQuote: "Другая цитата",
        save: "Сохранить",
        unsave: "Убрать из избранного",
        favorites: "Избранное",
        settings: "Настройки",
        done: "Готово",
        loading: "Загрузка…",
        errorTitle: "Ошибка",
        retry: "Повторить",
        inFavorites: "В избранном",
        emptyTitle: "Пока пусто",
        emptyDescription: "Сохраняйте понравившиеся цитаты на главном экране.",
        clearAll: "Очистить избранное",
        clearAllConfirmTitle: "Очистить избранное?",
        clearAllConfirmMessage: "Все сохранённые цитаты будут удалены. Отменить нельзя.",
        cancel: "Отмена",
        delete: "Удалить",
        appLanguage: "Язык интерфейса",
        quoteLanguage: "Язык цитат",
        aboutSection: "Прочее",
        resetAll: "Сбросить приложение",
        resetAllConfirmTitle: "Сбросить к начальному состоянию?",
        resetAllConfirmMessage: "Избранное будет очищено, настройки вернутся к значениям по умолчанию.",
        reset: "Сбросить",
        saveFailed: "Не удалось сохранить: ",
        russianOfflineNote: "Русские цитаты берутся из встроенной библиотеки",
        previousQuote: "Предыдущая",
        nextQuote: "Следующая",
        appearanceSection: "Оформление",
        themeLabel: "Тема",
        themeSystem: "Как в системе",
        themeLight: "Светлая",
        themeDark: "Тёмная",
        dailyQuoteSection: "Цитата дня",
        dailyQuoteToggle: "Показывать цитату дня",
        dailyQuoteHint: "При запуске открывается цитата дня; смахните вниз, чтобы свернуть.",
        dailyQuoteCollapse: "Свернуть",
        dailyQuoteShow: "Цитата дня",
        randomLanguage: "Случайный",
        randomLanguageHint: "Каждая цитата выбирается случайно из китайского, английского или русского набора."
    )
}
