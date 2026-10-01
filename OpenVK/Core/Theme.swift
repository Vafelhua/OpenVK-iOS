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
enum Theme {
    static var isDark: Bool { return LocalSettings.shared.isDarkTheme }

    static var background: UIColor { return isDark ? UIColor(hex: 0x1B1B1B) : UIColor(hex: 0xF3F3F3) }
    static var card: UIColor { return isDark ? UIColor(hex: 0x252525) : UIColor.white }
    static var navRail: UIColor { return isDark ? UIColor(hex: 0x1E1E1E) : UIColor.white }
    static var textPrimary: UIColor { return isDark ? UIColor.white : UIColor(hex: 0x1A1A1A) }
    static var textSecondary: UIColor { return isDark ? UIColor(hex: 0x9E9E9E) : UIColor(hex: 0x767676) }
    static var divider: UIColor { return isDark ? UIColor(hex: 0x3A3A3A) : UIColor(hex: 0xE1E1E1) }
    static var composerBackground: UIColor { return isDark ? UIColor(hex: 0x2D2D2D) : UIColor(hex: 0xF3F3F3) }
    static var composerBorder: UIColor { return isDark ? UIColor(hex: 0x2D2D2D) : UIColor(hex: 0xDCDCDC) }

    static let accent = UIColor(hex: 0x0078D7)
    static let accentPressed = UIColor(hex: 0x0063B1)
    static let outgoing = UIColor(hex: 0x0078D7)
    static let error = UIColor(hex: 0xC0392B)
    static let avatarPlaceholder = UIColor(hex: 0xC0D9F0)
    static let logout = UIColor(hex: 0x7B4B4B)

    static var incoming: UIColor { return isDark ? UIColor(hex: 0x2B2B2B) : UIColor(hex: 0xE4E4E4) }
    static var incomingText: UIColor { return isDark ? UIColor.white : UIColor(hex: 0x1A1A1A) }

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
        bar.titleTextAttributes = [
            .foregroundColor: textPrimary,
            .font: UIFont.boldSystemFont(ofSize: 17)
        ]
        bar.setTitleTextAttributes([
            .foregroundColor: textPrimary,
            .font: UIFont.boldSystemFont(ofSize: 17)
        ], for: .normal)
    }

    static func styleTabBar(_ bar: UITabBar) {
        bar.barTintColor = navRail
        bar.tintColor = accent
        bar.isTranslucent = false
        bar.unselectedItemTintColor = textSecondary
    }

    static func applyGlobalAppearance() {
        styleNavigationBar(UINavigationBar.appearance())
        styleTabBar(UITabBar.appearance())
        UITableView.appearance().backgroundColor = background
    }

    static func reloadAppearance() {
        NotificationCenter.default.post(name: .openVKThemeDidChange, object: nil)
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