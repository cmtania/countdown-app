import Foundation

enum EventKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case countdown, countup
    var id: String { rawValue }
    var title: String { self == .countdown ? "Countdowns" : "Countups" }
    var singular: String { self == .countdown ? "countdown" : "countup" }
    var symbol: String { self == .countdown ? "calendar.badge.clock" : "calendar.badge.checkmark" }
}

enum EventTheme: String, Codable, CaseIterable, Identifiable, Sendable {
    case apricot, lilac, sage, butter, cream
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum Illustration: String, Codable, CaseIterable, Identifiable, Sendable {
    case sun, flower, gift, sprout, home
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum Recurrence: String, Codable, CaseIterable, Identifiable, Sendable {
    case never, weekly, monthly, yearly
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum LeapDayPolicy: String, Codable, CaseIterable, Identifiable, Sendable {
    case february28, march1
    var id: String { rawValue }
    var title: String { self == .february28 ? "February 28" : "March 1" }
}

struct CalendarDay: Codable, Hashable, Comparable, Sendable {
    var year: Int
    var month: Int
    var day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year; self.month = month; self.day = day
    }

    init(_ date: Date, calendar: Calendar) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        year = components.year ?? 2000
        month = components.month ?? 1
        day = components.day ?? 1
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.year != rhs.year { return lhs.year < rhs.year }
        if lhs.month != rhs.month { return lhs.month < rhs.month }
        return lhs.day < rhs.day
    }

    /// Noon avoids local midnight anomalies. Arithmetic still uses calendar dates.
    func date(in calendar: Calendar) -> Date? {
        guard (1...9999).contains(year), (1...12).contains(month), (1...31).contains(day),
              let value = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)),
              CalendarDay(value, calendar: calendar) == self else { return nil }
        return value
    }

    func isValid(in calendar: Calendar) -> Bool { date(in: calendar) != nil }
}

struct CountEvent: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var kind: EventKind
    var title: String
    var date: CalendarDay
    var theme: EventTheme = .apricot
    var illustration: Illustration = .sun
    var tag = ""
    var dayLabel = ""
    var note = ""
    var recurrence: Recurrence = .never
    var leapDayPolicy: LeapDayPolicy = .february28
    var reminder = false
    var createdAt = Date()
    var updatedAt = Date()

    var countLabel: String {
        kind == .countdown ? "days to go" : (dayLabel.isEmpty ? "days since" : dayLabel)
    }

    func validate(calendar: Calendar) throws {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, title.count <= 60 else {
            throw EventError.invalid("Give your event a name of 1–60 characters.")
        }
        guard date.isValid(in: calendar) else { throw EventError.invalid("Choose a valid calendar date.") }
        guard tag.count <= 40, dayLabel.count <= 32, note.count <= 1000 else {
            throw EventError.invalid("Use a shorter tag, day label, or note.")
        }
        guard kind == .countdown || (recurrence == .never && !reminder) else {
            throw EventError.invalid("Repeats and date reminders belong to countdowns.")
        }
    }
}

enum EventError: LocalizedError {
    case invalid(String)
    case unsupportedVersion
    case unavailable
    var errorDescription: String? {
        switch self {
        case .invalid(let message): return message
        case .unsupportedVersion: return "This collection was saved by a newer app version. Update the app to open it."
        case .unavailable: return "Your saved collection could not be opened. It has been left untouched. Retry loading before making changes."
        }
    }
}

struct DeletedEvent: Identifiable, Codable, Equatable {
    var event: CountEvent
    var deletedAt: Date
    var id: UUID { event.id }
}

struct EventCollection: Codable, Equatable {
    var version = 1
    var events: [CountEvent] = []
    var deleted: [DeletedEvent] = []

    func validate(calendar: Calendar) throws {
        guard version == 1 else { throw EventError.unsupportedVersion }
        let all = events + deleted.map(\.event)
        guard Set(all.map(\.id)).count == all.count else {
            throw EventError.invalid("The saved collection contains duplicate event identifiers.")
        }
        for event in all { try event.validate(calendar: calendar) }
    }
}
