import Foundation

struct DateEngine {
    var calendar: Calendar

    init(timeZone: TimeZone = .current) {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = timeZone
        calendar = value
    }

    func today(at now: Date) -> CalendarDay { CalendarDay(now, calendar: calendar) }

    func difference(from: CalendarDay, to: CalendarDay) -> Int {
        guard let start = from.date(in: calendar), let end = to.date(in: calendar) else { return 0 }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: end)).day ?? 0
    }

    func addingDays(_ amount: Int, to day: CalendarDay) -> CalendarDay {
        guard let date = day.date(in: calendar), let result = calendar.date(byAdding: .day, value: amount, to: date) else { return day }
        return CalendarDay(result, calendar: calendar)
    }

    func daysInMonth(year: Int, month: Int) -> Int {
        guard let first = CalendarDay(year: year, month: month, day: 1).date(in: calendar) else { return 28 }
        return calendar.range(of: .day, in: .month, for: first)?.count ?? 28
    }

    func clamped(year: Int, month: Int, day: Int) -> CalendarDay {
        let y = min(9999, max(1, year)), m = min(12, max(1, month))
        return CalendarDay(year: y, month: m, day: min(max(1, day), daysInMonth(year: y, month: m)))
    }

    func occurrence(of event: CountEvent, at now: Date) -> CalendarDay {
        let current = today(at: now), anchor = event.date
        guard event.kind == .countdown, event.recurrence != .never, anchor < current else { return anchor }
        switch event.recurrence {
        case .never: return anchor
        case .weekly:
            let distance = difference(from: anchor, to: current)
            return addingDays(((distance + 6) / 7) * 7, to: anchor)
        case .monthly:
            var candidate = clamped(year: current.year, month: current.month, day: anchor.day)
            if candidate < current {
                let month = current.month == 12 ? 1 : current.month + 1
                let year = current.month == 12 ? current.year + 1 : current.year
                candidate = clamped(year: year, month: month, day: anchor.day)
            }
            return candidate
        case .yearly:
            func anniversary(_ year: Int) -> CalendarDay {
                if anchor.month == 2 && anchor.day == 29 && daysInMonth(year: year, month: 2) == 28 {
                    return event.leapDayPolicy == .february28
                        ? CalendarDay(year: year, month: 2, day: 28)
                        : CalendarDay(year: year, month: 3, day: 1)
                }
                return clamped(year: year, month: anchor.month, day: anchor.day)
            }
            let candidate = anniversary(current.year)
            return candidate < current ? anniversary(min(9999, current.year + 1)) : candidate
        }
    }

    func count(for event: CountEvent, at now: Date) -> Int {
        let current = today(at: now)
        if event.kind == .countup { return max(0, difference(from: event.date, to: current)) }
        return max(0, difference(from: current, to: occurrence(of: event, at: now)))
    }

    func label(for event: CountEvent, at now: Date) -> String {
        let date = occurrence(of: event, at: now), current = today(at: now)
        if date == current { return event.kind == .countdown ? "Today is the day!" : "It starts today." }
        if event.kind == .countdown && date < current { return "A day to remember" }
        if event.kind == .countup && date > current { return "Starts on \(formatted(date))" }
        if count(for: event, at: now) == 1 {
            if event.kind == .countdown { return "day to go" }
            if event.dayLabel.isEmpty { return "day since" }
        }
        return event.countLabel
    }

    func formatted(_ day: CalendarDay, short: Bool = false) -> String {
        guard let date = day.date(in: calendar) else { return "Invalid date" }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate(short ? "dMMMyyyy" : "dMMMMyyyy")
        return formatter.string(from: date)
    }
}
