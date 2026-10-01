import UIKit

/// Страница пользователя: шапка, счётчики, добавление в друзья, стена.
final class UserViewController: WallScreenController {
    private let user: VKUser
    private var headerParts: HeaderParts?
    private let addButton = UIButton(type: .system)
    private var isFriend = false

    init(user: VKUser) {
        self.user = user
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var wallOwnerId: Int { return user.id }
    override var wallCount: String { return "20" }

    override func buildHeader() {
        title = user.name

        let parts = addHeaderParts(avatarSize: 64)
        parts.avatar.setRemote(user.photoMax)
        parts.title.text = user.name
        parts.subtitle.text = user.countersText.isEmpty ? user.subtitle
            : user.subtitle + "\n" + user.countersText
        headerParts = parts

        let actions = UIStackView()
        actions.axis = .horizontal
        actions.distribution = .fillEqually
        actions.spacing = 8

        let messageButton = UIButton(type: .system)
        messageButton.setTitle("Написать", for: .normal)
        messageButton.setTitleColor(Theme.accent, for: .normal)
        messageButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        messageButton.backgroundColor = Theme.composerBackground
        messageButton.addTarget(self, action: #selector(openChat), for: .touchUpInside)
        actions.addArrangedSubview(messageButton)

        addButton.setTitle("Добавить в друзья", for: .normal)
        addButton.setTitleColor(Theme.accent, for: .normal)
        addButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        addButton.backgroundColor = Theme.composerBackground
        addButton.addTarget(self, action: #selector(addFriend), for: .touchUpInside)
        actions.addArrangedSubview(addButton)

        actions.heightAnchor.constraint(equalToConstant: 40).isActive = true
        headerStack.addArrangedSubview(actions)

        refreshFriendState()
    }

    private func refreshFriendState() {
        guard user.id != LocalSettings.shared.userId else {
            addButton.setTitle("Это вы", for: .normal)
            addButton.isEnabled = false
            return
        }
        addButton.setTitle("Проверяем…", for: .normal)
        addButton.isEnabled = false

        VKApiClient.shared.call("friends.get", ["fields": "photo_50,photo_100"]) { [weak self] result in
            guard let self = self else { return }
            var found = false
            if case .success(let value) = result {
                let ids = VKUser.readList(value, key: "items").map { $0.id }
                found = ids.contains(self.user.id)
            }
            DispatchQueue.main.async {
                self.isFriend = found
                self.addButton.isEnabled = true
                self.addButton.setTitle(found ? "Вы друзья" : "Добавить в друзья", for: .normal)
                self.addButton.setTitleColor(found ? Theme.textSecondary : Theme.accent, for: .normal)
            }
        }
    }

    @objc private func addFriend() {
        guard isFriend == false else { return }
        addButton.isEnabled = false
        addButton.setTitle("Добавляем…", for: .normal)

        VKApiClient.shared.call("friends.add", ["user_id": String(user.id), "follow": "1"]) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.addButton.isEnabled = true
                switch result {
                case .success:
                    self.isFriend = true
                    self.addButton.setTitle("Вы друзья", for: .normal)
                    self.addButton.setTitleColor(Theme.textSecondary, for: .normal)
                case .failure(let error):
                    self.addButton.setTitle("Добавить в друзья", for: .normal)
                    self.presentAlert(title: "Ошибка", message: error.message)
                }
            }
        }
    }

    @objc private func openChat() {
        let peer = VKPeer(id: user.id, kind: .user, title: user.name, photoURL: user.photoMax)
        Navigator.openChat(peer, in: self)
    }
}