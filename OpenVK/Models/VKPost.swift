import Foundation

/// Запись со стены / из новостной ленты.
final class VKPost {
    let id: Int
    let ownerId: Int
    let fromId: Int
    let date: Int
    var text: String
    var likesCount: Int
    var isLiked: Bool
    var commentsCount: Int
    var repostsCount: Int
    var attachments: [VKAttachment]
    var viewsCount: Int

    /// Принимает и «голую» запись `wall.get`, и элемент ленты `{type:"post", post:{…}}`.
    init(item: [String: Any]) {
        var source = item
        if J.getString(item, "type", "") == "post", let nested = J.dict(item["post"]) {
            source = nested
        } else if let nested = J.dict(item["post"]) {
            source = nested
        }

        id = J.getInt(source, "id", 0)
        ownerId = J.getInt(source, "owner_id", 0)
        fromId = J.getInt(source, "from_id", 0)
        date = J.getInt(source, "date", 0)
        text = J.getString(source, "text", "")

        let likes = J.getDict(source, "likes")
        likesCount = J.getInt(likes, "count", 0)
        isLiked = J.getBool(likes, "user_likes", J.getBool(likes, "my_likes", false))

        let comments = J.getDict(source, "comments")
        commentsCount = J.getInt(comments, "count", 0)

        let reposts = J.getDict(source, "reposts")
        repostsCount = J.getInt(reposts, "count", 0)

        viewsCount = J.getInt(J.getDict(source, "views"), "count", 0)

        var parsed = VKAttachment.readList(source)
        if parsed.isEmpty {
            // Старый формат: photos[] лежит рядом, без обёртки type.
            for element in J.getArr(source, "photos") {
                if let dict = element as? [String: Any],
                    let attachment = VKAttachment(dict: ["type": "photo", "photo": dict]) {
                    parsed.append(attachment)
                }
            }
        }
        attachments = parsed
    }

    static func readList(_ result: Any?, key: String = "items") -> [VKPost] {
        let source = J.arr(result) ?? J.getArr(result, key)
        return source.compactMap { element in
            guard let dict = element as? [String: Any] else { return nil }
            return VKPost(item: dict)
        }
    }

    var hasPhoto: Bool {
        return attachments.contains { ($0.photo?.bigURL ?? "").hasPrefix("http") }
    }

    /// Первое фото записи (в UWP-клиенте показывается только оно).
    var photo: VKPhoto? {
        for attachment in attachments {
            if let photo = attachment.photo, photo.bigURL.hasPrefix("http") { return photo }
        }
        return nil
    }

    var ownerIsGroup: Bool { return ownerId < 0 }
    var groupId: Int { return abs(ownerId) }

    var attachmentsString: String {
        let values = attachments.compactMap { attachment -> String? in
            if let photo = attachment.photo, photo.id != 0 { return photo.attachmentValue }
            if let audio = attachment.audio, audio.id != 0 { return audio.attachmentValue }
            return nil
        }
        return values.joined(separator: ",")
    }
}