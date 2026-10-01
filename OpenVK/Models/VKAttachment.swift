import Foundation

enum AttachmentType: String {
    case photo, doc, audio, video, link, sticker, graffiti, wall, unknown

    init(raw: String) {
        self = AttachmentType(rawValue: raw) ?? .unknown
    }

    var displayName: String {
        switch self {
        case .photo: return "Фотография"
        case .doc: return "Документ"
        case .audio: return "Аудиозапись"
        case .video: return "Видео"
        case .link: return "Ссылка"
        case .sticker: return "Стикер"
        case .graffiti: return "Рисунок"
        case .wall: return "Запись"
        case .unknown: return "Вложение"
        }
    }
}

/// Вложение к записи или сообщению.
final class VKAttachment {
    let type: AttachmentType
    var photo: VKPhoto?
    var audio: VKAudio?
    var title: String
    var url: String
    let ownerId: Int
    let id: Int

    init?(dict: [String: Any]) {
        let raw = J.getString(dict, "type", "")
        type = AttachmentType(raw: raw)
        guard type != .unknown || raw.isEmpty == false else { return nil }

        if type == .photo, let object = J.dict(dict["photo"]) {
            photo = VKPhoto(dict: object)
        } else if type == .audio, let object = J.dict(dict["audio"]) {
            audio = VKAudio(dict: object)
            title = audio?.displayName ?? ""
            ownerId = audio?.ownerId ?? 0
            id = audio?.id ?? 0
            url = audio?.url ?? ""
            return
        } else if type == .video, let object = J.dict(dict["video"]) {
            title = J.getString(object, "title", "")
            ownerId = J.getInt(object, "owner_id", 0)
            id = J.getInt(object, "id", 0)
            url = ""
        } else if type == .doc, let object = J.dict(dict["doc"]) {
            title = J.getString(object, "title", "")
            ownerId = J.getInt(object, "owner_id", 0)
            id = J.getInt(object, "id", 0)
            url = J.getString(object, "url", "")
        } else if type == .link, let object = J.dict(dict["link"]) {
            title = J.getString(object, "title", "")
            ownerId = 0
            id = 0
            url = J.getString(object, "url", "")
        } else {
            title = ""
            ownerId = 0
            id = 0
            url = ""
        }

        if type == .photo {
            ownerId = photo?.ownerId ?? 0
            id = photo?.id ?? 0
        }
    }

    static func readList(_ container: Any?, key: String = "attachments") -> [VKAttachment] {
        return J.getArr(container, key).compactMap { VKAttachment(dict: ($0 as? [String: Any]) ?? [:]) }
    }
}