import UIKit

/// Корневой экран авторизованного приложения.
///
/// Пять вкладок: при шести и более UITabBarController на iPhone/iPad
/// прячет лишние иконки в системный «Ещё», что ломает навигацию.
/// Друзья, группы, музыка и настройки доступны из профиля.
final class MainTabBarController: UITabBarController {
    /// Мини-плеер над таб-баром — общий для всех вкладок.
    private let miniPlayer = MiniPlayerBar()
    private var miniPlayerIsVisible = false

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

        buildMiniPlayer()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(themeDidChange),
                                               name: .openVKThemeDidChange,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(musicDidChange),
                                               name: .openVKMusicDidChange,
                                               object: nil)
        musicDidChange()
    }

    private func buildMiniPlayer() {
        view.addSubview(miniPlayer)
        miniPlayer.onOpen = { [weak self] in self?.openMusic() }
        NSLayoutConstraint.activate([
            miniPlayer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            miniPlayer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            miniPlayer.bottomAnchor.constraint(equalTo: tabBar.topAnchor),
            miniPlayer.heightAnchor.constraint(equalToConstant: MiniPlayerBar.height)
        ])
        miniPlayer.isHidden = true
    }

    /// Показывает мини-плеер и добавляет отступ контенту вкладок, чтобы
    /// нижние элементы не прятались за панелью.
    @objc private func musicDidChange() {
        let visible = MusicPlayer.shared.currentTrack != nil
        guard visible != miniPlayerIsVisible else { return }
        miniPlayerIsVisible = visible
        miniPlayer.isHidden = !visible
        // У UITabBarController дополнительный отступ наследуется дочерними
        // контроллерами, поэтому панель не перекрывает их содержимое.
        additionalSafeAreaInsets.bottom = visible ? MiniPlayerBar.height : 0
    }

    private func openMusic() {
        guard let navigation = selectedViewController as? UINavigationController else { return }
        if navigation.topViewController is MusicViewController { return }
        navigation.pushViewController(MusicViewController(), animated: true)
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
        miniPlayer.applyTheme()
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