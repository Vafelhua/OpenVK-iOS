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

/// Тема приложения (светлая/тёмная). iOS 12 не умеет системную тёмную тему,
/// поэтому цвета применяются вручную и перечитываются при смене темы.
/// Палитра повторяет цвета официального клиента VK.
enum Theme {
    static var isDark: Bool { return LocalSettings.shared.isDarkTheme }

    static var background: UIColor { return isDark ? UIColor(hex: 0x19191A) : UIColor(hex: 0xF2F3F5) }
    static var card: UIColor { return isDark ? UIColor(hex: 0x242527) : .white }
    static var navRail: UIColor { return isDark ? UIColor(hex: 0x1F2021) : .white }
    static var textPrimary: UIColor { return isDark ? .white : UIColor(hex: 0x0F1720) }
    static var textSecondary: UIColor { return isDark ? UIColor(hex: 0x7F8285) : UIColor(hex: 0x818C99) }
    static var divider: UIColor { return isDark ? UIColor(hex: 0x2E2F31) : UIColor(hex: 0xE3E6E8) }
    static var composerBackground: UIColor { return isDark ? UIColor(hex: 0x242527) : .white }
    static var composerBorder: UIColor { return isDark ? UIColor(hex: 0x2E2F31) : UIColor(hex: 0xE3E6E8) }

    static let accent = UIColor(hex: 0x0077FF)
    static let accentPressed = UIColor(hex: 0x0066E0)
    static let outgoing = UIColor(hex: 0x0077FF)
    static let error = UIColor(hex: 0xE64646)
    static let avatarPlaceholder = UIColor(hex: 0xD8E3F2)
    static let logout = UIColor(hex: 0x7B4B4B)

    static var incoming: UIColor { return isDark ? UIColor(hex: 0x2E2F31) : .white }
    static var incomingText: UIColor { return isDark ? .white : UIColor(hex: 0x0F1720) }

    /// Скругление карточек — как в клиенте VK.
    static var cardRadius: CGFloat { return 10 }
    /// Высота плавающей кнопки/строки.
    static var rowInset: CGFloat { return 12 }

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
        bar.tintColor = accent
        bar.isTranslucent = false
        bar.shadowImage = makeDividerImage()
        let title: [NSAttributedString.Key: Any] = [
            .foregroundColor: textPrimary,
            .font: UIFont.boldSystemFont(ofSize: 17)
        ]
        bar.titleTextAttributes = title
        // Крупный заголовок на корневых экранах — как в клиенте VK.
        bar.largeTitleTextAttributes = [
            .foregroundColor: textPrimary,
            .font: UIFont.boldSystemFont(ofSize: 30)
        ]
    }

    static func styleTabBar(_ bar: UITabBar) {
        bar.barTintColor = navRail
        bar.tintColor = accent
        bar.isTranslucent = false
        bar.unselectedItemTintColor = textSecondary
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
        UIApplication.shared.statusBarStyle = isDark ? .lightContent : .default
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