import Foundation

/// Профиль пользователя OpenVK/VK.
final class VKUser {
    let id: Int
    var firstName: String
    var lastName: String
    var screenName: String
    var photo50: String
    var photo100: String
    var photo200: String
    var statusText: String
    var isOnline: Bool
    var friendsCount: Int
    var followersCount: Int
    var subscriptionsCount: Int

    init?(dict: [String: Any]) {
        let identifier = J.getInt(dict, "id", 0)
        guard identifier != 0 else { return nil }
        id = identifier
        firstName = J.getString(dict, "first_name", "")
        lastName = J.getString(dict, "last_name", "")
        screenName = J.getString(dict, "screen_name", "")
        photo50 = J.getString(dict, "photo_50", "")
        photo100 = J.getString(dict, "photo_100", "")
        photo200 = J.getString(dict, "photo_200", "")
        statusText = J.getString(dict, "status", "")
        isOnline = J.getBool(dict, "online", false)

        let counters = J.getDict(dict, "counters")
        friendsCount = J.getInt(counters, "friends", 0)
        followersCount = J.getInt(counters, "followers", 0)
        subscriptionsCount = J.getInt(counters, "subscriptions", 0)

        if photo100.isEmpty {
            photo100 = photo50.isEmpty ? photo200 : photo50
        }
        if photo200.isEmpty {
            photo200 = photo100
        }
    }

    var photoMax: String { return photo200.isEmpty ? photo100 : photo200 }

    var name: String {
        let value = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? (screenName.isEmpty ? "Пользователь" : screenName) : value
    }

    /// «в сети» / статус / «id12345».
    var subtitle: String {
        if isOnline { return "в сети" }
        if statusText.isEmpty == false { return statusText }
        return "id\(id)"
    }

    var countersText: String {
        var parts: [String] = []
        if friendsCount > 0 {
            parts.append("\(friendsCount) \(TimeHelper.plural(friendsCount, "друг", "друга", "друзей"))")
        }
        if followersCount > 0 {
            parts.append("\(followersCount) \(TimeHelper.plural(followersCount, "подписчик", "подписчика", "подписчиков"))")
        }
        if subscriptionsCount > 0 {
            parts.append("\(subscriptionsCount) \(TimeHelper.plural(subscriptionsCount, "подписка", "подписки", "подписок"))")
        }
        return parts.joined(separator: " · ")
    }

    static func readList(_ container: Any?, key: String = "profiles") -> [VKUser] {
        return J.getArr(container, key).compactMap { VKUser(dict: ($0 as? [String: Any]) ?? [:]) }
    }
}