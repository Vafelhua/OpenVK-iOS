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

/// Оформление приложения — один вариант, повторяющий клиент VK 6.56.
///
/// Признаки оригинала, которые здесь воспроизводятся:
/// * шапка и таб-бар — фирменный синий #4A76A8, заголовки белые;
/// * фон страницы — холодный серо-голубой, содержимое — белые полосы;
/// * разделители в одну точку, между полосами видно фон;
/// * углы прямые: у карточек, аватаров и кнопок нет скруглений;
/// * ни одной тени и ни одного градиента.
///
/// iOS 12 не умеет системную тёмную тему, поэтому цвета применяются вручную
/// и перечитываются при смене темы (`.openVKThemeDidChange`).
enum Theme {
    // MARK: - Состояние

    /// Тёмное оформление — тот же VK 6.56, но с тёмно-синими полосами.
    static var isDark: Bool { return LocalSettings.shared.isDarkTheme }

    // MARK: - Палитра

    /// Набор цветов одного варианта оформления.
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
        let badge: UIColor
    }

    private static let vk56Light = Palette(
        background: UIColor(hex: 0xE7EAED),
        card: UIColor(hex: 0xFFFFFF),
        navRail: UIColor(hex: 0x45688E),
        textPrimary: UIColor(hex: 0x2B2B2B),
        textSecondary: UIColor(hex: 0x7A7E83),
        divider: UIColor(hex: 0xD8DCE0),
        border: UIColor(hex: 0xCDD2D7),
        incoming: UIColor(hex: 0xFFFFFF),
        incomingText: UIColor(hex: 0x2B2B2B),
        outgoing: UIColor(hex: 0xD8EAF7),
        outgoingText: UIColor(hex: 0x2B2B2B),
        accent: UIColor(hex: 0x45688E),
        button: UIColor(hex: 0x5B7FA6),
        buttonPressed: UIColor(hex: 0x45688E),
        buttonText: UIColor(hex: 0xFFFFFF),
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
        outgoingText: UIColor(hex: 0xFFFFFF),
        accent: UIColor(hex: 0x7FA6CC),
        button: UIColor(hex: 0x5B7FA6),
        buttonPressed: UIColor(hex: 0x45688E),
        buttonText: UIColor(hex: 0xFFFFFF),
        error: UIColor(hex: 0xD0605A),
        avatarPlaceholder: UIColor(hex: 0x3A4046),
        logout: UIColor(hex: 0x9A6060),
        badge: UIColor(hex: 0x5B7FA6)
    )

    private static var current: Palette {
        return isDark ? vk56Dark : vk56Light
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

    static var composerBackground: UIColor { return current.background }
    static var composerBorder: UIColor { return current.divider }

    // MARK: - Метрики

    /// У клиента 6.56 углы почти прямые — скруглений нет ни у чего.
    static let cardRadius: CGFloat = 0
    /// Полосы разделены фоном страницы, а не обводкой.
    static let cardBorderWidth: CGFloat = 0
    /// У пузырей и аватаров остаётся минимальное скругление — так выглядел оригинал.
    static let bubbleRadius: CGFloat = 2
    static func avatarRadius(_ size: CGFloat) -> CGFloat { return 2 }
    /// Горизонтальные отступы внутри строки.
    static let rowInset: CGFloat = 12
    /// Крупных заголовков в клиенте 6.56 не было.
    static let supportsLargeTitles: Bool = false
    /// Толщина линии в один экранный пиксель.
    static var hairline: CGFloat { return 1 / UIScreen.main.scale }

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
        bar.barTintColor = navRail
        bar.tintColor = .white
        bar.isTranslucent = false
        // В оригинале под синей шапкой идёт светлая линия в один пиксель.
        bar.shadowImage = makeLineImage(color: navRail.lighter(by: 0.18), height: hairline)
        bar.prefersLargeTitles = supportsLargeTitles
        bar.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.boldSystemFont(ofSize: 17)
        ]
        bar.largeTitleTextAttributes = bar.titleTextAttributes
    }

    static func styleTabBar(_ bar: UITabBar) {
        bar.barTintColor = navRail
        bar.tintColor = .white
        bar.isTranslucent = false
        // На синей подложке невыбранные пункты просто чуть тусклее белого.
        bar.unselectedItemTintColor = UIColor.white.withAlphaComponent(0.75)
        bar.shadowImage = makeLineImage(color: navRail.lighter(by: 0.18), height: hairline)
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

    /// Цвет системного статус-бара. На iOS 12 работает только при
    /// `UIViewControllerBasedStatusBarAppearance = NO` в Info.plist.
    static func applyStatusBarStyle() {
        UIApplication.shared.statusBarStyle = .lightContent
    }

    // MARK: - Вспомогательное

    private static func makeLineImage(color: UIColor, height: CGFloat) -> UIImage? {
        let size = CGSize(width: 1, height: max(height, 1))
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        color.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image?.resizableImage(withCapInsets: .zero, resizingMode: .stretch)
    }
}

extension UIColor {
    /// Осветление цвета — для линии под шапкой и рамок.
    func lighter(by amount: CGFloat) -> UIColor {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return self }
        return UIColor(red: min(red + amount, 1),
                       green: min(green + amount, 1),
                       blue: min(blue + amount, 1),
                       alpha: alpha)
    }
}