import UIKit

/// Корневой экран авторизованного приложения: 7 вкладок, как в UWP-клиенте.
final class MainTabBarController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()
        Theme.decorate(self)
        Theme.styleTabBar(tabBar)

        viewControllers = [
            wrap(NewsfeedViewController(), title: "Новости", glyph: "▦"),
            wrap(ConversationsViewController(), title: "Сообщения", glyph: "✉"),
            wrap(FriendsViewController(), title: "Друзья", glyph: "☺"),
            wrap(GroupsViewController(), title: "Группы", glyph: "☷"),
            wrap(MusicViewController(), title: "Музыка", glyph: "♪"),
            wrap(ProfileViewController(), title: "Профиль", glyph: "☰"),
            wrap(SettingsViewController(), title: "Настройки", glyph: "⚙")
        ]

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(themeDidChange),
                                               name: .openVKThemeDidChange,
                                               object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func themeDidChange() {
        Theme.decorate(self)
        Theme.styleTabBar(tabBar)
    }

    private func wrap(_ controller: UIViewController, title: String, glyph: String) -> UINavigationController {
        controller.title = title
        let navigation = UINavigationController(rootViewController: controller)
        navigation.navigationBar.isTranslucent = false
        Theme.styleNavigationBar(navigation.navigationBar)

        let item = UITabBarItem(title: title,
                                image: UIFactory.icon(glyph, size: 26),
                                selectedImage: nil)
        item.title = title
        navigation.tabBarItem = item
        return navigation
    }
}