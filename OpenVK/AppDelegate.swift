import UIKit

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    static var shared: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        Theme.applyGlobalAppearance()

        let window = UIWindow(frame: UIScreen.main.bounds)
        window.backgroundColor = Theme.background
        self.window = window

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(authExpired),
                                               name: .openVKAuthExpired,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleMemoryWarning),
                                               name: UIApplication.didReceiveMemoryWarningNotification,
                                               object: nil)

        showRoot(animated: false)
        return true
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Корневой экран

    func showRoot(animated: Bool) {
        let root: UIViewController = LocalSettings.shared.tokenPresent
            ? MainTabBarController()
            : LoginViewController()

        window?.rootViewController = root
        window?.makeKeyAndVisible()

        guard animated, let window = window else { return }
        UIView.transition(with: window, duration: 0.28, options: [.transitionCrossDissolve], animations: nil)
    }

    func signIn() {
        VKApiClient.shared.resetAuthExpiredFlag()
        showRoot(animated: true)
    }

    func signOut() {
        LocalSettings.shared.clearCredentials()
        showRoot(animated: true)
    }

    // MARK: - Реакции на события

    /// Токен протух: чистим учётные данные и объясняем пользователю причину
    /// на экране входа, который `showRoot` только что поставил.
    @objc private func authExpired(_ note: Notification) {
        let reason = (note.object as? VKError)?.message ?? "Сессия истекла."
        LocalSettings.shared.clearCredentials()
        showRoot(animated: false)

        (window?.rootViewController as? LoginViewController)?.showSessionExpired(reason)
    }

    @objc private func handleMemoryWarning() {
        ImageLoader.shared.purgeMemory()
    }
}