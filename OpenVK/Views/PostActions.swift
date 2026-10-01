import UIKit

/// Общие действия над записью: лайк, комментарии, репост.
enum PostActions {
    static func toggleLike(_ post: VKPost, completion: @escaping () -> Void) {
        var parameters = ["type": "post", "item_id": String(post.id)]
        if post.ownerId != 0 {
            parameters["owner_id"] = String(post.ownerId)
        }
        let method = post.isLiked ? "likes.delete" : "likes.add"

        VKApiClient.shared.call(method, parameters) { result in
            if case .success = result {
                DispatchQueue.main.async {
                    post.likesCount = max(0, post.likesCount + (post.isLiked ? -1 : 1))
                    post.isLiked.toggle()
                    completion()
                }
            }
        }
    }

    static func repost(_ post: VKPost, in controller: UIViewController) {
        var parameters = ["owner_id": String(LocalSettings.shared.userId), "message": post.text]
        if let photo = post.photo {
            parameters["attachments"] = photo.attachmentValue
        }

        VKApiClient.shared.call("wall.post", parameters) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    controller.presentAlert(title: "Готово", message: "Запись опубликована на вашей стене.")
                case .failure(let error):
                    controller.presentAlert(title: "Ошибка", message: error.message)
                }
            }
        }
    }

    static func openComments(_ post: VKPost, in controller: UIViewController) {
        let comments = CommentsViewController(post: post)
        let navigation = UINavigationController(rootViewController: comments)
        navigation.modalPresentationStyle = .fullScreen
        Theme.styleNavigationBar(navigation.navigationBar)
        controller.present(navigation, animated: true, completion: nil)
    }
}