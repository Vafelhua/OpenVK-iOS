import UIKit

/// Общие действия над записью: лайк, комментарии, репост.
enum PostActions {
    static func toggleLike(_ post: VKPost, in controller: UIViewController, completion: @escaping () -> Void) {
        var parameters = ["type": "post", "item_id": String(post.id)]
        if post.ownerId != 0 {
            parameters["owner_id"] = String(post.ownerId)
        }
        let method = post.isLiked ? "likes.delete" : "likes.add"

        VKApiClient.shared.call(method, parameters) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // Локально обновляем счётчик только при успехе — иначе лента
                    // разойдётся с сервером после первой неудачи.
                    post.likesCount = max(0, post.likesCount + (post.isLiked ? -1 : 1))
                    post.isLiked.toggle()
                    completion()
                case .failure(let error):
                    // Раньше ошибка игнорировалась: кнопка «молча» не работала.
                    controller.presentAlert(title: "Не удалось изменить лайк", message: error.message)
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

    /// Меню записи по долгому нажатию: оценки и удаление своей записи.
    static func openMenu(_ post: VKPost, in controller: UIViewController, onDeleted: (() -> Void)? = nil) {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        if post.likesCount > 0 {
            sheet.addAction(UIAlertAction(title: "Понравилось: \(post.likesCount)",
                                          style: .default) { _ in
                Navigator.openLikes(post: post, in: controller)
            })
        }

        let isOwn = post.ownerId == LocalSettings.shared.userId
        if isOwn {
            sheet.addAction(UIAlertAction(title: "Удалить запись", style: .destructive) { _ in
                delete(post, in: controller, completion: onDeleted)
            })
        }

        sheet.addAction(UIAlertAction(title: "Отмена", style: .cancel, handler: nil))

        // На iPad actionSheet требует anchor — иначе аварийно падает.
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = controller.view
            popover.sourceRect = CGRect(x: controller.view.bounds.midX,
                                        y: controller.view.bounds.midY,
                                        width: 1, height: 1)
            popover.permittedArrowDirections = []
        }
        controller.present(sheet, animated: true, completion: nil)
    }

    static func delete(_ post: VKPost,
                       in controller: UIViewController,
                       completion: (() -> Void)? = nil) {
        var parameters: [String: String] = ["post_id": String(post.id)]
        if post.ownerId == LocalSettings.shared.userId {
            parameters["owner_id"] = String(post.ownerId)
        }

        VKApiClient.shared.call("wall.delete", parameters) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    completion?()
                case .failure(let error):
                    controller.presentAlert(title: "Ошибка", message: error.message)
                }
            }
        }
    }
}