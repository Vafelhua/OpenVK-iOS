import UIKit

/// Корневой экран авторизованного приложения.
///
/// Пять вкладок: при шести и более UITabBarController на iPhone/iPad
/// прячет лишние иконки в системный «Ещё», что ломает навигацию.
/// Друзья, группы, музыка и настройки доступны из профиля.
final class MainTabBarController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()
        Theme.decorate(self)
        Theme.styleTabBar(tabBar)

        viewControllers = [
            wrap(NewsfeedViewController(), title: "Новости", icon: .news),
            wrap(ConversationsViewController(), title: "Сообщения", icon: .messages),
            wrap(ProfileViewController(), title: "Профиль", icon: .profile),
            wrap(SettingsViewController(), title: "Настройки", icon: .settings)
        ]
        tabBar.isTranslucent = false

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
        // Навигационные бары дочерних вкладок создаются один раз и хранят
        // цвета, выставленные напрямую. Appearance-proxy их не обновляет,
        // поэтому после смены темы перекрашиваем каждый бар вручную — иначе
        // сверху остаётся светлая полоса.
        for case let navigation as UINavigationController in viewControllers ?? [] {
            Theme.styleNavigationBar(navigation.navigationBar)
            navigation.topViewController?.view.backgroundColor = Theme.background
        }
        Theme.applyStatusBarStyle()
    }

    private func wrap(_ controller: UIViewController,
                      title: String,
                      icon: UIFactory.TabIcon) -> UINavigationController {
        controller.title = title
        let navigation = UINavigationController(rootViewController: controller)
        navigation.navigationBar.isTranslucent = false
        Theme.styleNavigationBar(navigation.navigationBar)

        let item = UITabBarItem(title: title,
                                image: UIFactory.tabIcon(icon),
                                selectedImage: UIFactory.tabIcon(icon))
        navigation.tabBarItem = item
        return navigation
    }
}