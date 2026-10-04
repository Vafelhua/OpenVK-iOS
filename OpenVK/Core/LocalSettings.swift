import Foundation

/// Локальные настройки: токен (Keychain), id пользователя, инстанс, тема.
final class LocalSettings {
    static let shared = LocalSettings()

    private let defaults = UserDefaults.standard
    private let tokenKey = "openvk.access_token"
    private let uidKey = "openvk.user_id"
    private let instanceKey = "openvk.instance_base_url"
    private let themeKey = "openvk.theme"
    private let styleKey = "openvk.style"

    private init() {}

    // MARK: - Credentials

    var token: String? {
        get { return Keychain.get(tokenKey) }
        set { Keychain.set(newValue, for: tokenKey) }
    }

    var userId: Int {
        get { return defaults.integer(forKey: uidKey) }
        set { defaults.set(newValue, forKey: uidKey) }
    }

    var tokenPresent: Bool {
        let value = token ?? ""
        return value.isEmpty == false && userId != 0
    }

    func saveCredentials(token: String, userId: Int) {
        self.token = token
        self.userId = userId
    }

    func clearCredentials() {
        token = nil
        defaults.removeObject(forKey: uidKey)
    }

    // MARK: - Instance

    var instanceBaseURL: String {
        get {
            if let stored = defaults.string(forKey: instanceKey), stored.isEmpty == false {
                return stored
            }
            return VKConstants.defaultAPIBaseURL
        }
        set { defaults.set(newValue, forKey: instanceKey) }
    }

    /// Адрес веб-версии инстанса (для открытия групп в браузере).
    var instanceWebBaseURL: String {
        var value = instanceBaseURL
        value = value.replacingOccurrences(of: "/method/", with: "/")
        value = value.replacingOccurrences(of: "/method", with: "")
        value = value.replacingOccurrences(of: "api.", with: "")
        if value.hasSuffix("/") == false { value += "/" }
        return value
    }

    /// Адрес получения токена, выведенный из адреса инстанса.
    var tokenURL: String {
        let value = instanceBaseURL
        guard value != VKConstants.defaultAPIBaseURL else { return VKConstants.defaultTokenURL }

        if let url = URL(string: value), let host = url.host, host.isEmpty == false {
            return "https://\(host)/token"
        }
        var patched = value
        if patched.hasPrefix("https://") == false && patched.hasPrefix("http://") == false {
            patched = "https://" + patched
        }
        patched = patched.replacingOccurrences(of: "/method/", with: "")
        if let url = URL(string: patched), let host = url.host, host.isEmpty == false {
            return "https://\(host)/token"
        }
        return VKConstants.defaultTokenURL
    }

    // MARK: - Theme

    var theme: String {
        get { return defaults.string(forKey: themeKey) ?? "light" }
        set { defaults.set(newValue, forKey: themeKey) }
    }

    var isDarkTheme: Bool {
        get { return theme == "dark" }
        set { theme = newValue ? "dark" : "light" }
    }

    /// Стиль оформления интерфейса: классический VK 6.56 или современный.
    var style: String {
        get { return defaults.string(forKey: styleKey) ?? "vk56" }
        set { defaults.set(newValue, forKey: styleKey) }
    }
}