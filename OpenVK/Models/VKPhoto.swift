import UIKit

/// Фотография из вложения.
final class VKPhoto {
    let id: Int
    let ownerId: Int
    var bigURL: String
    var smallURL: String
    /// Размеры большой версии — нужны, чтобы не искажать пропорции при вёрстке.
    var width: CGFloat = 0
    var height: CGFloat = 0

    init?(dict: [String: Any]) {
        id = J.getInt(dict, "id", 0)
        ownerId = J.getInt(dict, "owner_id", 0)

        let sizes = J.getArr(dict, "sizes")
        if sizes.isEmpty == false {
            let preferred = ["x", "y", "z", "w", "m"]
            var chosen = ""
            var chosenSize: [String: Any]?
            for type in preferred {
                if let raw = sizes.first(where: { J.getString($0, "type", "") == type }),
                   let match = J.dict(raw) {
                    let url = J.getString(match, "url", "")
                    if url.isEmpty == false {
                        chosen = url
                        chosenSize = match
                        break
                    }
                }
            }
            if chosen.isEmpty {
                chosen = J.getString(sizes.last, "url", "")
                chosenSize = J.dict(sizes.last)
            }
            bigURL = chosen

            width = CGFloat(J.getInt(chosenSize, "width", 0))
            height = CGFloat(J.getInt(chosenSize, "height", 0))

            // Для превью берём первый размер покрупнее, а не самый мелкий.
            let smallPreferred = ["m", "s", "n", "x"]
            var small = ""
            for type in smallPreferred {
                if let match = sizes.first(where: { J.getString($0, "type", "") == type }) {
                    small = J.getString(match, "url", "")
                    if small.isEmpty == false { break }
                }
            }
            if small.isEmpty { small = J.getString(sizes.first, "url", "") }
            smallURL = small.isEmpty ? bigURL : small
        } else {
            var big = J.getString(dict, "photo_604", "")
            if big.isEmpty { big = J.getString(dict, "photo_807", "") }
            if big.isEmpty { big = J.getString(dict, "photo_1280", "") }
            bigURL = big

            var small = J.getString(dict, "photo_130", "")
            if small.isEmpty { small = J.getString(dict, "photo_100", "") }
            smallURL = small.isEmpty ? big : small

            width = CGFloat(J.getInt(dict, "width", 0))
            height = CGFloat(J.getInt(dict, "height", 0))
        }

        guard bigURL.isEmpty == false else { return nil }
    }

    /// Доля высоты к ширине; при неизвестном размере — эвристика VK (широкие кадры).
    var aspectRatio: CGFloat {
        if width > 0, height > 0 {
            let ratio = height / width
            return min(max(ratio, 0.35), 2.4)
        }
        return 0.68
    }

    /// «photo-123_456» — формат вложения для wall.post.
    var attachmentValue: String { return "photo\(ownerId)_\(id)" }
}