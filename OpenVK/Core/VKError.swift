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
}

extension Error {
    var asVKError: VKError {
        if let error = self as? VKError { return error }
        return VKError(code: 0, message: localizedDescription)
    }
}