import Foundation

enum PeerKind: String {
    case user, chat, group, unknown

    init(raw: String) {
        self = PeerKind(rawValue: raw) ?? .unknown
    }
}

/// Собеседник диалога (пользователь, мультичат или сообщество).
final class VKPeer {
    let id: Int
    let kind: PeerKind
    var title: String
    var photoURL: String
    var subtitle: String

    init(id: Int, kind: PeerKind, title: String, photoURL: String, subtitle: String = "") {
        self.id = id
        self.kind = kind
        self.title = title
        self.photoURL = photoURL
        self.subtitle = subtitle
    }

    var isGroup: Bool { return kind == .group || id < 0 }

    /// Разрешает собеседника по `peer` + `profiles`/`groups` ответа диалогов.
    static func resolve(peerId: Int,
                        kind: String?,
                        container: Any?,
                        profiles: [VKUser],
                        groups: [VKGroup]) -> VKPeer {
        let resolvedKind = PeerKind(raw: kind ?? "")
        if peerId < 0 || resolvedKind == .group {
            let identifier = abs(peerId)
            if let group = groups.first(where: { $0.id == identifier }) {
                return VKPeer(id: peerId, kind: .group, title: group.title,
                              photoURL: group.photoMax, subtitle: group.membersText)
            }
            return VKPeer(id: peerId, kind: .group,
                          title: resolvedKind == .chat ? "Беседа" : "Сообщество",
                          photoURL: "", subtitle: "")
        }

        if let user = profiles.first(where: { $0.id == peerId }) {
            return VKPeer(id: peerId, kind: .user, title: user.name,
                          photoURL: user.photoMax, subtitle: user.subtitle)
        }
        if let user = profiles.first, profiles.count == 1, peerId != 0 {
            return VKPeer(id: peerId, kind: .user, title: user.name,
                          photoURL: user.photoMax, subtitle: user.subtitle)
        }
        return VKPeer(id: peerId, kind: resolvedKind == .chat ? .chat : .user,
                      title: resolvedKind == .chat ? "Беседа" : "Пользователь \(peerId)",
                      photoURL: "", subtitle: "id\(peerId)")
    }
}