import Foundation

/// Элемент списка диалогов.
final class VKConversation {
    let peerId: Int
    let kind: PeerKind
    var unreadCount: Int
    var peer: VKPeer
    var lastMessage: VKMessage?

    init(peerId: Int, kind: PeerKind, unread: Int, peer: VKPeer, message: VKMessage?) {
        self.peerId = peerId
        self.kind = kind
        unreadCount = unread
        self.peer = peer
        lastMessage = message
    }

    static func readList(_ result: Any?) -> [VKConversation] {
        let source = J.items(result)
        guard source.isEmpty == false else { return [] }

        let profiles = VKUser.readList(result)
        let groups = VKGroup.readList(result)

        return source.compactMap { element -> VKConversation? in
            guard let dict = element as? [String: Any] else { return nil }
            let peerObject = J.getDict(dict, "peer")
            let identifier = J.getInt(peerObject, "id", 0)
            guard identifier != 0 else { return nil }
            let kind = PeerKind(raw: J.getString(peerObject, "type", ""))
            let peer = VKPeer.resolve(peerId: identifier,
                                      kind: kind.rawValue,
                                      container: dict,
                                      profiles: profiles,
                                      groups: groups)
            let message = J.dict(dict["last_message"]).flatMap { VKMessage(dict: $0) }
            return VKConversation(peerId: identifier,
                                  kind: kind,
                                  unread: J.getInt(dict, "unread_count", 0),
                                  peer: peer,
                                  message: message)
        }
    }

    /// Последнее сообщение для ячейки списка диалогов.
    func apply(to cell: ConversationCell) {
        cell.unreadCount = unreadCount
        cell.avatarView.setRemote(peer.photoURL)
        cell.titleText = peer.title

        if let message = lastMessage {
            cell.timeText = TimeHelper.relative(message.date)
            cell.messageText = message.preview
            cell.setPhoto(message.photo?.smallURL)
        } else {
            cell.timeText = nil
            cell.messageText = "Нет сообщений"
            cell.setPhoto(nil)
        }
    }
}