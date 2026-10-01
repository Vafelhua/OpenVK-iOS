import Foundation

/// Сообщение диалога.
final class VKMessage {
    let id: Int
    let date: Int
    let peerId: Int
    let fromId: Int
    let isOutgoing: Bool
    var text: String
    var attachments: [VKAttachment]
    var reactionsCount: Int
    var commentsCount: Int

    init?(dict: [String: Any]) {
        let identifier = J.getInt(dict, "id", 0)
        guard identifier != 0 else { return nil }
        id = identifier
        date = J.getInt(dict, "date", 0)
        fromId = J.getInt(dict, "from_id", 0)
        isOutgoing = J.getBool(dict, "out", false)
        text = J.getString(dict, "text", "")
        attachments = VKAttachment.readList(dict)

        var peer = J.getInt(dict, "peer_id", 0)
        if peer == 0 { peer = fromId }
        peerId = peer

        let reactions = J.getDict(dict, "reactions")
        if let count = J.getInt(reactions, "count") {
            reactionsCount = count
        } else if let flat = J.getInt(dict, "reactions_count") {
            reactionsCount = flat
        } else {
            reactionsCount = J.getInt(dict, "reaction_count", 0)
        }
        commentsCount = J.getInt(dict, "comments_count", 0)
    }

    var photo: VKPhoto? {
        for attachment in attachments {
            if let photo = attachment.photo, photo.bigURL.hasPrefix("http") { return photo }
        }
        return nil
    }

    /// Текст для списка диалогов.
    var preview: String {
        if text.isEmpty == false {
            return text.replacingOccurrences(of: "\n", with: " ")
        }
        if let photo = photo { return "Фотография" }
        if let audio = attachments.compactMap({ $0.audio }).first {
            return "Аудио: " + audio.displayName
        }
        return "Вложение"
    }

    static func readList(_ result: Any?) -> [VKMessage] {
        return J.items(result).compactMap { VKMessage(dict: ($0 as? [String: Any]) ?? [:]) }
    }
}