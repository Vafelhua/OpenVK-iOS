import UIKit

/// Страница сообщества: шапка, счётчик участников, стена.
final class GroupViewController: WallScreenController {
    private let group: VKGroup
    private var headerParts: HeaderParts?
    private let joinButton = UIButton(type: .system)
    private var isMember: Bool?

    init(group: VKGroup) {
        self.group = group
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var wallOwnerId: Int { return -group.id }
    override var wallCount: String { return "20" }

    override func buildHeader() {
        title = group.title

        let parts = addHeaderParts(avatarSize: 64)
        parts.avatar.setRemote(group.photoMax)
        parts.title.text = group.title
        parts.subtitle.text = group.screenName.isEmpty ? "" : "@" + group.screenName
        parts.counters.text = group.membersText
        headerParts = parts

        addActionRow([
            (title: "Написать", action: #selector(openChat), color: Theme.accent),
            (title: "Фото", action: #selector(openPhotos), color: Theme.accent),
            (title: "В браузере", action: #selector(openInBrowser), color: Theme.accent)
        ])

        joinButton.setTitle("Проверяем…", for: .normal)
        joinButton.setTitleColor(Theme.textSecondary, for: .normal)
        joinButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        joinButton.backgroundColor = Theme.composerBackground
        joinButton.addTarget(self, action: #selector(toggleMembership), for: .touchUpInside)
        joinButton.heightAnchor.constraint(equalToConstant: 40).isActive = true
        headerStack.addArrangedSubview(joinButton)

        loadMembersCount()
        refreshMembership()
    }

    /// groups.getById с is_member — у OpenVK нет отдельного «я подписан».
    private func refreshMembership() {
        VKApiClient.shared.call("groups.getById",
                                ["group_id": String(group.id),
                                 "fields": "is_member"]) { [weak self] result in
            guard let self = self else { return }
            guard case .success(let value) = result else { return }
            let first = J.items(value).first as? [String: Any] ?? J.dict(J.getArr(value, "groups").first) ?? [:]
            let flag = J.getBool(first, "is_member", false)
            DispatchQueue.main.async {
                self.isMember = flag
                self.updateJoinButton()
            }
        }
    }

    private func updateJoinButton() {
        guard isMember != nil else { return }
        joinButton.setTitle(isMember == true ? "Вы подписаны" : "Вступить", for: .normal)
        joinButton.setTitleColor(isMember == true ? Theme.textSecondary : Theme.accent, for: .normal)
    }

    @objc private func toggleMembership() {
        guard let member = isMember else { return }
        joinButton.isEnabled = false

        let method = member ? "groups.leave" : "groups.join"
        VKApiClient.shared.call(method, ["group_id": String(group.id)]) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success:
                    self.isMember = member == false
                    self.updateJoinButton()
                    self.joinButton.isEnabled = true
                    if self.isMember == true {
                        self.group.membersCount += 1
                    } else {
                        self.group.membersCount = max(self.group.membersCount - 1, 0)
                    }
                    self.headerParts?.counters.text = self.group.membersText
                case .failure(let error):
                    self.joinButton.isEnabled = true
                    if error.isMethodMissing {
                        self.presentAlert(title: "Не поддерживается",
                                          message: "Инстанс не умеет менять подписку на сообщества.")
                    } else {
                        self.presentAlert(title: "Ошибка", message: error.message)
                    }
                }
            }
        }
    }

    /// groups.getMembers с count=1 — у OpenVK нет отдельного счётчика в groups.get.
    private func loadMembersCount() {
        VKApiClient.shared.call("groups.getMembers", ["group_id": String(-group.id), "count": "1"]) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let value):
                var total = J.getInt(value, "count", 0)
                if total == 0, let first = J.items(value).first {
                    if let dict = first as? [String: Any] {
                        total = J.getInt(dict, "count", 0)
                    } else {
                        total = J.toInt(first) ?? 0
                    }
                }
                guard total > 0 else { return }
                self.group.membersCount = total
                DispatchQueue.main.async {
                    self.headerParts?.counters.text = self.group.membersText
                }
            case .failure(let error):
                // На части инстансов метода нет (error_code 3) — не критично.
                if error.isMethodMissing == false {
                    self.presentAlert(title: "Ошибка", message: error.message)
                }
            }
        }
    }

    @objc private func openChat() {
        let peer = VKPeer(id: -group.id, kind: .group, title: group.title, photoURL: group.photoMax)
        Navigator.openChat(peer, in: self)
    }

    @objc private func openInBrowser() {
        Navigator.openGroupInBrowser(group, from: self)
    }

    @objc private func openPhotos() {
        Navigator.openPhotos(ownerId: -group.id, in: self)
    }

    override func applyTheme() {
        super.applyTheme()
        joinButton.backgroundColor = Theme.composerBackground
        updateJoinButton()
    }
}