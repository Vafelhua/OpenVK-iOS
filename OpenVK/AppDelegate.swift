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

        showRoot(animated: false)
        return true
    }

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
        showRoot(animated: true)
    }

    func signOut() {
        LocalSettings.shared.clearCredentials()
        showRoot(animated: true)
    }
}