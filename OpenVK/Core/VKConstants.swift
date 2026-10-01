import Foundation

/// Константы подключения к OpenVK API.
enum VKConstants {
    /// Базовый адрес API, совместимый с ВКонтакте (реализация OpenVK).
    static let defaultAPIBaseURL = "https://api.openvk.org/method/"

    /// Эндпоинт получения токена (OpenVK, grant_type=password).
    static let defaultTokenURL = "https://openvk.org/token"

    /// Версия API (VK-совместимая).
    static let apiVersion = "5.106"

    /// Клиент «VK for Windows Phone» (id: 5027722) — OpenVK опознаёт его.
    static let clientID = "5027722"

    static let clientName = "OpenVK iOS"

    static let userAgent = "OpenVK iOS (LuVK-style client)"

    static let bundleName = "OpenVK"
}