import XCTest
#if SWIFT_PACKAGE
@testable import CountdownCore
#else
@testable import CountdownApp
#endif

final class DateEngineTests: XCTestCase {
    private let engine = DateEngine(timeZone: TimeZone(identifier: "Asia/Manila")!)
    private func day(_ year: Int, _ month: Int, _ day: Int) -> CalendarDay { CalendarDay(year: year, month: month, day: day) }
    private func now(_ year: Int, _ month: Int, _ day: Int) -> Date { self.day(year, month, day).date(in: engine.calendar)! }
    private func event(_ date: CalendarDay, kind: EventKind = .countdown, recurrence rule: Recurrence = .never) -> CountEvent {
        CountEvent(kind: kind, title: "Test date", date: date, recurrence: rule)
    }

    func testReferenceCountsAndBreakdown() {
        let instant = now(2026, 10, 27)
        let days = engine.count(for: event(day(2026, 11, 14)), at: instant)
        XCTAssertEqual(days, 18)
        XCTAssertEqual(days / 7, 2)
        XCTAssertEqual(days % 7, 4)
        XCTAssertEqual(engine.count(for: event(day(2026, 6, 21), kind: .countup), at: instant), 128)
        XCTAssertEqual(engine.count(for: event(day(2026, 2, 9), kind: .countup), at: instant), 260)
    }

    func testTodayAndFinishedCountdownStayAtZero() {
        XCTAssertEqual(engine.count(for: event(day(2026, 10, 27)), at: now(2026, 10, 27)), 0)
        XCTAssertEqual(engine.label(for: event(day(2026, 10, 27)), at: now(2026, 10, 27)), "Today is the day!")
        XCTAssertEqual(engine.count(for: event(day(2026, 10, 26)), at: now(2026, 10, 27)), 0)
        XCTAssertEqual(engine.label(for: event(day(2026, 10, 26)), at: now(2026, 10, 27)), "A day to remember")
    }

    func testFutureCountupNeverDisplaysNegative() {
        XCTAssertEqual(engine.count(for: event(day(2026, 10, 28), kind: .countup), at: now(2026, 10, 27)), 0)
    }

    func testWeeklyIncludesOccurrenceDayThenAdvances() {
        let value = event(day(2026, 10, 20), recurrence: .weekly)
        XCTAssertEqual(engine.occurrence(of: value, at: now(2026, 10, 27)), day(2026, 10, 27))
        XCTAssertEqual(engine.occurrence(of: value, at: now(2026, 10, 28)), day(2026, 11, 3))
    }

    func testMonthlyRetainsOriginalDayAfterShortMonth() {
        let value = event(day(2026, 1, 31), recurrence: .monthly)
        XCTAssertEqual(engine.occurrence(of: value, at: now(2026, 2, 1)), day(2026, 2, 28))
        XCTAssertEqual(engine.occurrence(of: value, at: now(2026, 2, 28)), day(2026, 2, 28))
        XCTAssertEqual(engine.occurrence(of: value, at: now(2026, 3, 1)), day(2026, 3, 31))
        XCTAssertEqual(engine.occurrence(of: value, at: now(2026, 12, 31)), day(2026, 12, 31))
        XCTAssertEqual(engine.occurrence(of: value, at: now(2027, 1, 1)), day(2027, 1, 31))
    }

    func testLeapDayPolicies() {
        var value = event(day(2024, 2, 29), recurrence: .yearly)
        XCTAssertEqual(engine.occurrence(of: value, at: now(2025, 1, 1)), day(2025, 2, 28))
        value.leapDayPolicy = .march1
        XCTAssertEqual(engine.occurrence(of: value, at: now(2025, 1, 1)), day(2025, 3, 1))
        XCTAssertEqual(engine.occurrence(of: value, at: now(2028, 1, 1)), day(2028, 2, 29))
    }

    func testYearlyAndFutureAnchors() {
        let value = event(day(2020, 12, 12), recurrence: .yearly)
        XCTAssertEqual(engine.occurrence(of: value, at: now(2026, 12, 12)), day(2026, 12, 12))
        XCTAssertEqual(engine.occurrence(of: value, at: now(2026, 12, 13)), day(2027, 12, 12))
        let future = event(day(2030, 4, 1), recurrence: .monthly)
        XCTAssertEqual(engine.occurrence(of: future, at: now(2026, 10, 27)), future.date)
    }

    func testDSTUsesCalendarDaysNotSeconds() {
        let ny = DateEngine(timeZone: TimeZone(identifier: "America/New_York")!)
        XCTAssertEqual(ny.difference(from: day(2026, 3, 7), to: day(2026, 3, 9)), 2)
        XCTAssertEqual(ny.difference(from: day(2026, 10, 31), to: day(2026, 11, 2)), 2)
    }

    func testTimezoneChangeChangesTodayWithoutChangingEvent() {
        let date = ISO8601DateFormatter().date(from: "2026-10-27T00:30:00Z")!
        let la = DateEngine(timeZone: TimeZone(identifier: "America/Los_Angeles")!)
        let value = event(day(2026, 10, 28))
        XCTAssertEqual(engine.count(for: value, at: date), 1)
        XCTAssertEqual(la.count(for: value, at: date), 2)
        XCTAssertEqual(value.date, day(2026, 10, 28))
    }

    func testValidDatesAndClamping() {
        XCTAssertFalse(day(2026, 2, 29).isValid(in: engine.calendar))
        XCTAssertTrue(day(2028, 2, 29).isValid(in: engine.calendar))
        XCTAssertFalse(day(2026, 13, 1).isValid(in: engine.calendar))
        XCTAssertEqual(engine.clamped(year: 2026, month: 2, day: 31), day(2026, 2, 28))
        XCTAssertEqual(engine.clamped(year: 2028, month: 2, day: 31), day(2028, 2, 29))
    }

    func testCalendarYearBoundary() {
        XCTAssertEqual(engine.difference(from: day(2026, 12, 31), to: day(2027, 1, 1)), 1)
        XCTAssertEqual(engine.difference(from: day(2024, 2, 28), to: day(2024, 3, 1)), 2)
    }

    func testCountupCannotRepeatOrScheduleDateReminder() {
        var value = event(day(2020, 1, 1), kind: .countup)
        value.recurrence = .monthly
        XCTAssertThrowsError(try value.validate(calendar: engine.calendar))
        value.recurrence = .never
        value.reminder = true
        XCTAssertThrowsError(try value.validate(calendar: engine.calendar))
    }
}
