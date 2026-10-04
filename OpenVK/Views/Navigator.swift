import UIKit

/// Общие переходы между экранами.
enum Navigator {
    static func openUser(_ user: VKUser, in controller: UIViewController) {
        push(UserViewController(user: user), in: controller)
    }

    static func openUser(id: Int, in controller: UIViewController) {
        VKApiClient.shared.call("users.get", ["user_ids": String(id),
                                              "fields": "photo_50,photo_100,photo_200,status,online,counters"]) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let value):
                    let dict = J.items(value).first as? [String: Any] ?? J.dict(value) ?? [:]
                    if let user = VKUser(dict: dict) {
                        openUser(user, in: controller)
                    } else {
                        controller.presentAlert(title: "Ошибка", message: "Не удалось загрузить профиль.")
                    }
                case .failure(let error):
                    controller.presentAlert(title: "Ошибка", message: error.message)
                }
            }
        }
    }

    static func openGroup(_ group: VKGroup, in controller: UIViewController) {
        push(GroupViewController(group: group), in: controller)
    }

    static func openChat(_ peer: VKPeer, in controller: UIViewController) {
        push(ChatViewController(peer: peer), in: controller)
    }

    static func openPhotos(ownerId: Int, in controller: UIViewController) {
        push(PhotosViewController(ownerId: ownerId), in: controller)
    }

    static func openLikes(post: VKPost, in controller: UIViewController) {
        push(LikesViewController(ownerId: post.ownerId, postId: post.id), in: controller)
    }

    static func openGroupInBrowser(_ group: VKGroup, from controller: UIViewController) {
        let path = group.screenName.isEmpty ? "club\(group.id)" : group.screenName
        let urlString = LocalSettings.shared.instanceWebBaseURL + path
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    private static func push(_ controller: UIViewController, in parent: UIViewController) {
        let navigation = parent.navigationController ?? AppDelegate.shared.window?.rootViewController as? UINavigationController
        navigation?.pushViewController(controller, animated: true)
    }
}