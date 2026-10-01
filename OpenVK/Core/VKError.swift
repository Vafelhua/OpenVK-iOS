import Foundation

/// Ошибка OpenVK/VK API: код (`error_code`) + текст (`error_msg`).
struct VKError: Error {
    let code: Int
    let message: String

    init(code: Int, message: String) {
        self.code = code
        self.message = message
    }

    var localizedDescription: String { return message }

    /// 3 — «Метод не найден»: на некоторых инстансах метода нет,
    /// вызывающий код должен уметь деградировать (см. NewsfeedViewController).
    var isMethodMissing: Bool { return code == 3 }

    /// Токен недействителен или истёк (5 — auth failed, 14/36 — нет доступа,
    /// 15 — нет доступа к токену). Приложение обязано выйти на экран входа.
    var isAuthExpired: Bool { return code == 5 || code == 14 || code == 15 || code == 36 }

    /// Превышен лимит запросов (6) — стоит показать «слишком часто», а не «ошибка».
    var isRateLimited: Bool { return code == 6 }

    /// Нет прав на действие (15/7/13 — нет доступа, нет прав).
    var isPermissionDenied: Bool { return code == 7 || code == 13 }
}

extension Error {
    var asVKError: VKError {
        if let error = self as? VKError { return error }
        return VKError(code: 0, message: localizedDescription)
    }
}