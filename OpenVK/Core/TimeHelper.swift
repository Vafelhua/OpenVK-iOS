import Foundation

/// Форматирование времени в стиле ВК (русские относительные подписи).
enum TimeHelper {
    /// «только что», «5 мин», «час назад», «вчера», «3 дня назад», «12 дек».
    static func relative(_ unix: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(unix))
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "только что" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes) мин" }
        let hours = minutes / 60
        if hours < 24 { return plural(hours, "час назад", "часа назад", "часов назад") }
        let days = hours / 24
        if days == 1 { return "вчера" }
        if days < 7 { return "\(days) \(plural(days, "день", "дня", "дней")) назад" }
        return shortDate(date)
    }

    /// «сегодня в 14:03» / «вчера в 9:12» / «5 января 2020 в 9:12».
    static func full(_ unix: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(unix))
        let time = timeFormatter.string(from: date)
        if isToday(date) { return "сегодня в \(time)" }
        if isYesterday(date) { return "вчера в \(time)" }
        return "\(dayFormatter.string(from: date)) в \(time)"
    }

    /// Время для сообщений в списке диалогов: «14:03» / «5 янв» / «05.01.2020».
    static func compact(_ unix: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(unix))
        if isToday(date) { return timeFormatter.string(from: date) }
        if isYesterday(date) { return "вчера" }
        let calendar = Calendar.current
        if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
            return dayFormatter.string(from: date)
        }
        return yearDayFormatter.string(from: date)
    }

    static func clock(_ unix: Int) -> String {
        return timeFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(unix)))
    }

    static func isToday(_ date: Date) -> Bool {
        return Calendar.current.isDateInToday(date)
    }

    static func isYesterday(_ date: Date) -> Bool {
        return Calendar.current.isDateInYesterday(date)
    }

    /// Русская плюрализация: 1 участник / 2 участника / 5 участников.
    static func plural(_ count: Int, _ one: String, _ few: String, _ many: String) -> String {
        let remainder100 = abs(count) % 100
        let remainder10 = abs(count) % 10
        if remainder100 >= 11 && remainder100 <= 19 { return many }
        if remainder10 == 1 { return one }
        if remainder10 >= 2 && remainder10 <= 4 { return few }
        return many
    }

    private static func shortDate(_ date: Date) -> String {
        return dayFormatter.string(from: date)
    }

    private static let timeFormatter: DateFormatter = make("HH:mm")
    private static let dayFormatter: DateFormatter = make("d MMMM yyyy")
    private static let yearDayFormatter: DateFormatter = make("dd.MM.yyyy")

    private static func make(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = format
        return formatter
    }
}