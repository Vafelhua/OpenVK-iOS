import UIKit

/// Страница сообщества: шапка, счётчик участников, стена.
final class GroupViewController: WallScreenController {
    private let group: VKGroup
    private var headerParts: HeaderParts?

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
            (title: "В браузере", action: #selector(openInBrowser), color: Theme.accent)
        ])

        loadMembersCount()
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
}