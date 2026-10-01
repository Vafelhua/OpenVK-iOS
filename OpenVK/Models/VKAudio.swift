import Foundation

/// Аудиозапись (трек).
final class VKAudio {
    let id: Int
    let ownerId: Int
    var artist: String
    var title: String
    var duration: Int
    var url: String

    init?(dict: [String: Any]) {
        id = J.getInt(dict, "id", 0)
        ownerId = J.getInt(dict, "owner_id", 0)
        artist = J.getString(dict, "artist", "")
        title = J.getString(dict, "title", "")
        duration = J.getInt(dict, "duration", 0)
        url = J.getString(dict, "url", "")
        guard id != 0 || url.isEmpty == false else { return nil }
    }

    var displayName: String {
        if artist.isEmpty == false && title.isEmpty == false { return "\(artist) — \(title)" }
        if title.isEmpty == false { return title }
        return artist.isEmpty ? "Без названия" : artist
    }

    var durationText: String {
        guard duration > 0 else { return "" }
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var attachmentValue: String { return "audio\(ownerId)_\(id)" }

    static func readList(_ result: Any?) -> [VKAudio] {
        return J.items(result).compactMap { VKAudio(dict: ($0 as? [String: Any]) ?? [:]) }
    }
}