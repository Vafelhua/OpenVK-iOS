import Foundation

/// Сообщество (группа/паблик/встреча).
final class VKGroup {
    let id: Int
    var name: String
    var screenName: String
    var photo50: String
    var photo100: String
    var photo200: String
    var membersCount: Int
    var type: String

    init?(dict: [String: Any]) {
        let identifier = J.getInt(dict, "id", 0)
        guard identifier != 0 else { return nil }
        id = identifier
        name = J.getString(dict, "name", "")
        screenName = J.getString(dict, "screen_name", "")
        photo50 = J.getString(dict, "photo_50", "")
        photo100 = J.getString(dict, "photo_100", "")
        photo200 = J.getString(dict, "photo_200", "")
        membersCount = J.getInt(dict, "members_count", 0)
        type = J.getString(dict, "type", "group")

        if photo100.isEmpty {
            photo100 = photo50.isEmpty ? photo200 : photo50
        }
        if photo200.isEmpty {
            photo200 = photo100
        }
    }

    var photoMax: String { return photo200.isEmpty ? photo100 : photo200 }

    var title: String {
        return name.isEmpty ? (screenName.isEmpty ? "Сообщество" : screenName) : name
    }

    /// «1.2 тыс. участников».
    var membersText: String {
        guard membersCount > 0 else { return "" }
        let short = Self.shortNumber(membersCount)
        return "\(short) \(TimeHelper.plural(membersCount, "участник", "участника", "участников"))"
    }

    static func shortNumber(_ value: Int) -> String {
        if value < 1000 { return String(value) }
        if value < 1000000 {
            let thousands = Double(value) / 1000.0
            return String(format: "%.1f тыс.", thousands).replacingOccurrences(of: ".0 ", with: " ")
        }
        let millions = Double(value) / 1000000.0
        return String(format: "%.1f млн", millions).replacingOccurrences(of: ".0 ", with: " ")
    }

    static func readList(_ container: Any?, key: String = "groups") -> [VKGroup] {
        return J.getArr(container, key).compactMap { VKGroup(dict: ($0 as? [String: Any]) ?? [:]) }
    }
}