import Foundation

/// Толерантные к типам помощники чтения JSON.
///
/// OpenVK/VK отдают смешанные типы: числа приходят строками, флаги — 0/1,
/// а `fields`-объекты могут быть как объектом, так и массивом из одного элемента.
enum J {
    static func dict(_ container: Any?) -> [String: Any]? {
        if let value = container as? [String: Any] { return value }
        if let array = container as? [Any] { return array.first as? [String: Any] }
        return nil
    }

    static func arr(_ value: Any?) -> [Any]? {
        return value as? [Any]
    }

    /// Список элементов ответа: `{"items":[…]}`, `{"response":[…]}` или «голый» массив.
    static func items(_ result: Any?) -> [Any] {
        if let array = result as? [Any] { return array }
        guard let object = dict(result) else { return [] }
        if let array = arr(object["response"]) { return array }
        if let array = arr(object["items"]) { return array }
        return []
    }

    static func getDict(_ container: Any?, _ key: String) -> [String: Any]? {
        guard let object = dict(container) else { return nil }
        return dict(object[key])
    }

    static func getArr(_ container: Any?, _ key: String) -> [Any] {
        guard let object = dict(container) else { return [] }
        return arr(object[key]) ?? []
    }

    static func getString(_ container: Any?, _ key: String, _ fallback: String = "") -> String {
        guard let object = dict(container), let value = object[key], !(value is NSNull) else {
            return fallback
        }
        if let string = value as? String { return string }
        if let number = value as? NSNumber {
            return numberFormatter.string(from: number) ?? fallback
        }
        return fallback
    }

    static func getInt(_ container: Any?, _ key: String, _ fallback: Int = 0) -> Int {
        guard let object = dict(container), let value = object[key], !(value is NSNull) else {
            return fallback
        }
        return toInt(value) ?? fallback
    }

    static func getInt(_ container: Any?, _ key: String) -> Int? {
        guard let object = dict(container), let value = object[key], !(value is NSNull) else {
            return nil
        }
        return toInt(value)
    }

    static func getBool(_ container: Any?, _ key: String, _ fallback: Bool = false) -> Bool {
        guard let object = dict(container), let value = object[key], !(value is NSNull) else {
            return fallback
        }
        return toBool(value) ?? fallback
    }

    static func getDouble(_ container: Any?, _ key: String, _ fallback: Double = 0) -> Double {
        guard let object = dict(container), let value = object[key], !(value is NSNull) else {
            return fallback
        }
        return toDouble(value) ?? fallback
    }

    // MARK: - Значения

    static func toInt(_ value: Any?) -> Int? {
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String {
            if let result = Int(string) { return result }
            if let result = Double(string) { return Int(result) }
        }
        return nil
    }

    static func toBool(_ value: Any?) -> Bool? {
        if let number = value as? NSNumber { return number.boolValue }
        if let string = value as? String {
            let normalized = string.lowercased()
            if normalized == "1" || normalized == "true" { return true }
            if normalized == "0" || normalized == "false" { return false }
        }
        return nil
    }

    static func toDouble(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String { return Double(string) }
        return nil
    }

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .none
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}