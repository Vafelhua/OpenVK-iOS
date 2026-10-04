import UIKit

extension Notification.Name {
    static let openVKThemeDidChange = Notification.Name("OpenVKThemeDidChange")
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}

/// Тема приложения.
///
/// Поддерживаются два независимых измерения:
/// * `Style` — набор цветов и метрик (классический VK 6.56 или современный);
/// * светлая/тёмная — внутри каждого стиля своя палитра.
///
/// iOS 12 не умеет системную тёмную тему, поэтому цвета применяются вручную
/// и перечитываются при смене темы (`.openVKThemeDidChange`).
enum Theme {
    enum Style: String {
        /// Оформление клиента VK 6.56: сине-серая шапка, плоские списки,
        /// тонкие рамки, почти прямые углы, ссылки синего цвета.
        case vk56
        /// Нынешний VK: карточки со скруглением, крупные заголовки.
        case modern

        var title: String {
            switch self {
            case .vk56: return "VK 6.56"
            case .modern: return "Современный"
            }
        }

        var next: Style {
            return self == .vk56 ? .modern : .vk56
        }
    }

    // MARK: - Состояние

    static var style: Style {
        get { return Style(rawValue: LocalSettings.shared.style) ?? .vk56 }
        set { LocalSettings.shared.style = newValue.rawValue }
    }

    static var isVK56: Bool { return style == .vk56 }
    static var isDark: Bool { return LocalSettings.shared.isDarkTheme }

    // MARK: - Палитра

    /// Набор цветов одного варианта оформления. Вынесен в отдельную структуру,
    /// чтобы вариантов было ровно четыре и каждый был заполнен целиком.
    struct Palette {
        let background: UIColor
        let card: UIColor
        let navRail: UIColor
        let textPrimary: UIColor
        let textSecondary: UIColor
        let divider: UIColor
        let border: UIColor
        let incoming: UIColor
        let incomingText: UIColor
        let outgoing: UIColor
        let outgoingText: UIColor
        let accent: UIColor
        let button: UIColor
        let buttonPressed: UIColor
        let buttonText: UIColor
        let error: UIColor
        let avatarPlaceholder: UIColor
        let logout: UIColor
        /// Непрочитанные счётчики и бейджи: в тёмном VK 6.56 синий глухой.
        let badge: UIColor
    }

    private static let modernLight = Palette(
        background: UIColor(hex: 0xF2F3F5),
        card: .white,
        navRail: .white,
        textPrimary: UIColor(hex: 0x0F1720),
        textSecondary: UIColor(hex: 0x818C99),
        divider: UIColor(hex: 0xE3E6E8),
        border: UIColor(hex: 0xE3E6E8),
        incoming: .white,
        incomingText: UIColor(hex: 0x0F1720),
        outgoing: UIColor(hex: 0x0077FF),
        outgoingText: .white,
        accent: UIColor(hex: 0x0077FF),
        button: UIColor(hex: 0x0077FF),
        buttonPressed: UIColor(hex: 0x0066E0),
        buttonText: .white,
        error: UIColor(hex: 0xE64646),
        avatarPlaceholder: UIColor(hex: 0xD8E3F2),
        logout: UIColor(hex: 0x7B4B4B),
        badge: UIColor(hex: 0x0077FF)
    )

    private static let modernDark = Palette(
        background: UIColor(hex: 0x19191A),
        card: UIColor(hex: 0x242527),
        navRail: UIColor(hex: 0x1F2021),
        textPrimary: .white,
        textSecondary: UIColor(hex: 0x7F8285),
        divider: UIColor(hex: 0x2E2F31),
        border: UIColor(hex: 0x2E2F31),
        incoming: UIColor(hex: 0x2E2F31),
        incomingText: .white,
        outgoing: UIColor(hex: 0x0077FF),
        outgoingText: .white,
        accent: UIColor(hex: 0x0077FF),
        button: UIColor(hex: 0x0077FF),
        buttonPressed: UIColor(hex: 0x0066E0),
        buttonText: .white,
        error: UIColor(hex: 0xE64646),
        avatarPlaceholder: UIColor(hex: 0x2C2E30),
        logout: UIColor(hex: 0x8A5A5A),
        badge: UIColor(hex: 0x0077FF)
    )

    /// Классическая палитра VK 6.56: фирменный сине-серый #45688E в шапке,
    /// ссылки #45688E, кнопки #5B7FA6, серый фон страницы и тонкие рамки.
    private static let vk56Light = Palette(
        background: UIColor(hex: 0xE7EAED),
        card: .white,
        navRail: UIColor(hex: 0x45688E),
        textPrimary: UIColor(hex: 0x2B2B2B),
        textSecondary: UIColor(hex: 0x7A7E83),
        divider: UIColor(hex: 0xD8DCE0),
        border: UIColor(hex: 0xCDD2D7),
        incoming: .white,
        incomingText: UIColor(hex: 0x2B2B2B),
        outgoing: UIColor(hex: 0xD8EAF7),
        outgoingText: UIColor(hex: 0x2B2B2B),
        accent: UIColor(hex: 0x45688E),
        button: UIColor(hex: 0x5B7FA6),
        buttonPressed: UIColor(hex: 0x45688E),
        buttonText: .white,
        error: UIColor(hex: 0xC0392B),
        avatarPlaceholder: UIColor(hex: 0xD5DCE3),
        logout: UIColor(hex: 0x8A4B4B),
        badge: UIColor(hex: 0x5B7FA6)
    )

    private static let vk56Dark = Palette(
        background: UIColor(hex: 0x2A2E33),
        card: UIColor(hex: 0x353A40),
        navRail: UIColor(hex: 0x3C5A78),
        textPrimary: UIColor(hex: 0xF0F2F4),
        textSecondary: UIColor(hex: 0x98A0A8),
        divider: UIColor(hex: 0x454B52),
        border: UIColor(hex: 0x4C545C),
        incoming: UIColor(hex: 0x3E444B),
        incomingText: UIColor(hex: 0xF0F2F4),
        outgoing: UIColor(hex: 0x4A6E8C),
        outgoingText: .white,
        accent: UIColor(hex: 0x7FA6CC),
        button: UIColor(hex: 0x5B7FA6),
        buttonPressed: UIColor(hex: 0x45688E),
        buttonText: .white,
        error: UIColor(hex: 0xD0605A),
        avatarPlaceholder: UIColor(hex: 0x3A4046),
        logout: UIColor(hex: 0x9A6060),
        badge: UIColor(hex: 0x5B7FA6)
    )

    private static var current: Palette {
        switch (style, isDark) {
        case (.modern, false): return modernLight
        case (.modern, true): return modernDark
        case (.vk56, false): return vk56Light
        case (.vk56, true): return vk56Dark
        }
    }

    // MARK: - Цвета

    static var background: UIColor { return current.background }
    static var card: UIColor { return current.card }
    static var navRail: UIColor { return current.navRail }
    static var textPrimary: UIColor { return current.textPrimary }
    static var textSecondary: UIColor { return current.textSecondary }
    static var divider: UIColor { return current.divider }
    static var border: UIColor { return current.border }
    static var incoming: UIColor { return current.incoming }
    static var incomingText: UIColor { return current.incomingText }
    static var outgoing: UIColor { return current.outgoing }
    static var outgoingText: UIColor { return current.outgoingText }
    static var accent: UIColor { return current.accent }
    static var button: UIColor { return current.button }
    static var buttonPressed: UIColor { return current.buttonPressed }
    static var buttonText: UIColor { return current.buttonText }
    static var error: UIColor { return current.error }
    static var avatarPlaceholder: UIColor { return current.avatarPlaceholder }
    static var logout: UIColor { return current.logout }
    static var badge: UIColor { return current.badge }

    static var composerBackground: UIColor { return current.card }
    static var composerBorder: UIColor { return current.divider }

    // MARK: - Метрики

    /// Скругление карточек и пузырей: у VK 6.56 углы почти прямые.
    static var cardRadius: CGFloat { return isVK56 ? 2 : 10 }
    /// В классическом стиле карточки обведены тонкой рамкой вместо тени.
    static var cardBorderWidth: CGFloat { return isVK56 ? 1 : 0 }
    /// Радиус пузыря сообщения.
    static var bubbleRadius: CGFloat { return isVK56 ? 3 : 14 }
    /// Радиус аватара: круг в современном стиле, почти прямой угол в VK 6.56.
    static func avatarRadius(_ size: CGFloat) -> CGFloat {
        return isVK56 ? 2 : size / 2
    }
    /// Отступ между строками списка.
    static var rowInset: CGFloat { return 12 }
    /// У классического VK шапка и таб-бар цветные, поэтому статус-бар всегда
    /// со светлыми символами.
    static var isChromeColored: Bool { return isVK56 }
    /// Крупные заголовки навигации есть только у современного стиля.
    static var supportsLargeTitles: Bool { return isVK56 == false }

    // MARK: - Оформление системных элементов

    /// Базовое оформление контроллера (фон, навигация, таб-бар).
    static func decorate(_ controller: UIViewController) {
        controller.view.backgroundColor = background
        controller.view.tintColor = accent

        if let navigation = controller.navigationController {
            styleNavigationBar(navigation.navigationBar)
        }
        if let tabs = controller.tabBarController {
            styleTabBar(tabs.tabBar)
        }
    }

    static func styleNavigationBar(_ bar: UINavigationBar) {
        // В VK 6.56 шапка синяя, поэтому заголовок и кнопки — белые.
        let onColoredChrome = isChromeColored
        bar.barTintColor = navRail
        bar.tintColor = onColoredChrome ? .white : accent
        bar.isTranslucent = false
        bar.shadowImage = makeDividerImage()
        bar.prefersLargeTitles = supportsLargeTitles

        let title: [NSAttributedString.Key: Any] = [
            .foregroundColor: onColoredChrome ? UIColor.white : textPrimary,
            .font: UIFont.boldSystemFont(ofSize: 17)
        ]
        bar.titleTextAttributes = title
        if supportsLargeTitles {
            bar.largeTitleTextAttributes = [
                .foregroundColor: textPrimary,
                .font: UIFont.boldSystemFont(ofSize: 30)
            ]
        } else {
            bar.largeTitleTextAttributes = title
        }
    }

    static func styleTabBar(_ bar: UITabBar) {
        let onColoredChrome = isChromeColored
        bar.barTintColor = navRail
        bar.tintColor = onColoredChrome ? .white : accent
        bar.isTranslucent = false
        // На синей подложке невыбранные пункты нельзя красить серым —
        // в классическом VK они просто чуть тусклее белого.
        bar.unselectedItemTintColor = onColoredChrome
            ? UIColor.white.withAlphaComponent(0.72)
            : textSecondary
        bar.shadowImage = makeDividerImage()
    }

    static func applyGlobalAppearance() {
        styleNavigationBar(UINavigationBar.appearance())
        styleTabBar(UITabBar.appearance())
        UITableView.appearance().backgroundColor = background
        UIRefreshControl.appearance().tintColor = textSecondary
    }

    static func reloadAppearance() {
        NotificationCenter.default.post(name: .openVKThemeDidChange, object: nil)
    }

    /// Цвет системного статус-бара под текущую тему. На iOS 12 работает
    /// только при `UIViewControllerBasedStatusBarAppearance = NO` в Info.plist.
    static func applyStatusBarStyle() {
        if isChromeColored {
            UIApplication.shared.statusBarStyle = .lightContent
        } else {
            UIApplication.shared.statusBarStyle = isDark ? .lightContent : .default
        }
    }

    private static func makeDividerImage() -> UIImage? {
        let size = CGSize(width: 1, height: 1)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        divider.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image?.resizableImage(withCapInsets: .zero, resizingMode: .stretch)
    }
}