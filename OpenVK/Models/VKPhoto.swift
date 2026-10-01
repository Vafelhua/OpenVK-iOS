import Foundation

/// Фотография из вложения.
final class VKPhoto {
    let id: Int
    let ownerId: Int
    var bigURL: String
    var smallURL: String

    init?(dict: [String: Any]) {
        id = J.getInt(dict, "id", 0)
        ownerId = J.getInt(dict, "owner_id", 0)

        let sizes = J.getArr(dict, "sizes")
        if sizes.isEmpty == false {
            let preferred = ["x", "y", "z", "w", "m"]
            var chosen = ""
            for type in preferred {
                let match = sizes.first { item -> Bool in
                    return J.getString(item, "type", "") == type
                }
                if let match = match {
                    let url = J.getString(match, "url", "")
                    if url.isEmpty == false {
                        chosen = url
                        break
                    }
                }
            }
            bigURL = chosen.isEmpty ? J.getString(sizes.last, "url", "") : chosen
            let first = J.getString(sizes.first, "url", "")
            smallURL = first.isEmpty ? bigURL : first
        } else {
            var big = J.getString(dict, "photo_604", "")
            if big.isEmpty { big = J.getString(dict, "photo_807", "") }
            if big.isEmpty { big = J.getString(dict, "photo_1280", "") }
            bigURL = big

            var small = J.getString(dict, "photo_130", "")
            if small.isEmpty { small = J.getString(dict, "photo_100", "") }
            smallURL = small.isEmpty ? big : small
        }

        guard bigURL.isEmpty == false else { return nil }
    }

    /// «photo-123_456» — формат вложения для wall.post.
    var attachmentValue: String { return "photo\(ownerId)_\(id)" }
}