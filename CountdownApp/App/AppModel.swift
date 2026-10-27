import SwiftUI
import Observation
import UIKit

struct AppPreferences: Codable, Equatable {
    var haptics = true
    var gentleMotion = false
    var reminders = false
}

@MainActor @Observable
final class AppModel {
    private(set) var collection = EventCollection()
    private(set) var loadFailed = false
    var errorMessage: String?
    var toast: String?
    var now: Date
    var kind: EventKind = .countdown
    var selectedCountdown: UUID?
    var selectedCountup: UUID?
    var preferences: AppPreferences {
        didSet {
            if !isDemo, let data = try? JSONEncoder().encode(preferences) {
                UserDefaults.standard.set(data, forKey: "preferences.v1")
            }
        }
    }
    let store: EventStore
    let isDemo: Bool
    private let demoNow: Date?
    private var toastTask: Task<Void, Never>?
    private var celebratedOccurrences: Set<String> = []
    private var lastReminderDay: CalendarDay?
    private var lastReminderTimeZone = ""
    private var reminderRevision = 0

    var engine: DateEngine { DateEngine() }
    var events: [CountEvent] { collection.events }
    var selectedID: UUID? {
        get { kind == .countdown ? selectedCountdown : selectedCountup }
        set {
            if kind == .countdown { selectedCountdown = newValue } else { selectedCountup = newValue }
            if !isDemo { UserDefaults.standard.set(newValue?.uuidString, forKey: "selected.\(kind.rawValue)") }
        }
    }

    init() {
        isDemo = ProcessInfo.processInfo.arguments.contains("--demo")
        let engine = DateEngine()
        let fixedDate = CalendarDay(year: 2026, month: 10, day: 27).date(in: engine.calendar) ?? Date()
        demoNow = isDemo ? fixedDate : nil
        now = isDemo ? fixedDate : Date()
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CountdownApp", isDirectory: true)
        store = EventStore(url: folder.appendingPathComponent("events-v1.json"))
        if !isDemo, let data = UserDefaults.standard.data(forKey: "preferences.v1"),
           let saved = try? JSONDecoder().decode(AppPreferences.self, from: data) { preferences = saved }
        else { preferences = AppPreferences() }
        if isDemo { collection.events = Self.samples(engine: engine, now: fixedDate) }
        else {
            if let value = UserDefaults.standard.string(forKey: "selected.countdown") { selectedCountdown = UUID(uuidString: value) }
            if let value = UserDefaults.standard.string(forKey: "selected.countup") { selectedCountup = UUID(uuidString: value) }
            load()
        }
        normalizeSelection()
    }

    func load() {
        do {
            collection = try store.load(calendar: engine.calendar)
            loadFailed = false
            normalizeSelection()
        } catch {
            loadFailed = true
            errorMessage = "Your saved events could not be opened. The file is untouched. \(error.localizedDescription)"
        }
    }

    func ordered(_ kind: EventKind) -> [CountEvent] {
        events.filter { $0.kind == kind }.sorted {
            let a = engine.occurrence(of: $0, at: now), b = engine.occurrence(of: $1, at: now)
            if a == b { return $0.createdAt < $1.createdAt }
            return kind == .countdown ? a < b : a > b
        }
    }

    func event(_ id: UUID) -> CountEvent? { events.first { $0.id == id } }

    func select(_ event: CountEvent) {
        kind = event.kind
        selectedID = event.id
    }

    func normalizeSelection() {
        if !ordered(.countdown).contains(where: { $0.id == selectedCountdown }) { selectedCountdown = ordered(.countdown).first?.id }
        if !ordered(.countup).contains(where: { $0.id == selectedCountup }) { selectedCountup = ordered(.countup).first?.id }
    }

    func refresh() {
        now = demoNow ?? Date()
        normalizeSelection()
        let day = engine.today(at: now), zone = engine.calendar.timeZone.identifier
        if day != lastReminderDay || zone != lastReminderTimeZone {
            lastReminderDay = day; lastReminderTimeZone = zone
            syncReminders()
        }
    }

    @discardableResult
    private func commit(_ candidate: EventCollection) -> Bool {
        guard !loadFailed else { errorMessage = EventError.unavailable.localizedDescription; return false }
        do {
            if !isDemo { try store.save(candidate, calendar: engine.calendar) }
            collection = candidate
            normalizeSelection()
            syncReminders()
            return true
        } catch {
            errorMessage = "Your change was not saved. \(error.localizedDescription)"
            return false
        }
    }

    @discardableResult
    func save(_ draft: CountEvent) -> Bool {
        var value = draft
        value.title = value.title.trimmingCharacters(in: .whitespacesAndNewlines)
        value.tag = value.tag.trimmingCharacters(in: .whitespacesAndNewlines)
        value.dayLabel = value.dayLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        value.updatedAt = now
        do {
            try value.validate(calendar: engine.calendar)
            let original = event(value.id)
            let unchangedDate = original?.date == value.date && original?.kind == value.kind
            if !unchangedDate {
                if value.kind == .countdown && value.date < engine.today(at: now) { throw EventError.invalid("Choose today or a future date for your countdown.") }
                if value.kind == .countup && value.date > engine.today(at: now) { throw EventError.invalid("Choose today or a past date for your countup.") }
            }
            var candidate = collection
            if let i = candidate.events.firstIndex(where: { $0.id == value.id }) { candidate.events[i] = value }
            else { candidate.events.append(value) }
            guard commit(candidate) else { return false }
            select(value)
            feedback(.success)
            showToast(original == nil ? "A little day, worth keeping." : "Changes saved.")
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }

    @discardableResult
    func remove(_ event: CountEvent) -> Bool {
        var candidate = collection
        candidate.events.removeAll { $0.id == event.id }
        candidate.deleted.append(DeletedEvent(event: event, deletedAt: now))
        guard commit(candidate) else { return false }
        showToast("Moved to Recently deleted. Restore it in Settings.")
        return true
    }

    func restore(_ deleted: DeletedEvent) {
        var candidate = collection
        candidate.deleted.removeAll { $0.id == deleted.id }
        candidate.events.append(deleted.event)
        if commit(candidate) { select(deleted.event); showToast("Your event is back.") }
    }

    func convertToCountup(_ event: CountEvent) {
        let occurrence = engine.occurrence(of: event, at: now)
        guard event.kind == .countdown, occurrence <= engine.today(at: now) else { return }
        var converted = event
        converted.kind = .countup
        converted.date = occurrence
        converted.recurrence = .never
        converted.reminder = false
        _ = save(converted)
    }

    func newEvent() -> CountEvent {
        let day = engine.today(at: now)
        return CountEvent(kind: kind, title: "", date: kind == .countdown ? engine.addingDays(7, to: day) : day,
                          theme: kind == .countdown ? .apricot : .lilac,
                          illustration: kind == .countdown ? .sun : .flower)
    }

    func addExamples() {
        guard events.isEmpty else { return }
        var candidate = collection
        candidate.events = Self.samples(engine: engine, now: now)
        _ = commit(candidate)
    }

    private static func samples(engine: DateEngine, now: Date) -> [CountEvent] {
        let today = engine.today(at: now)
        return [
            CountEvent(kind: .countdown, title: "Seaside escape", date: engine.addingDays(18, to: today), theme: .apricot, illustration: .sun, tag: "Travel", note: "A little sunshine awaits."),
            CountEvent(kind: .countdown, title: "My birthday", date: engine.addingDays(46, to: today), theme: .lilac, illustration: .gift, tag: "Birthdays", recurrence: .yearly),
            CountEvent(kind: .countdown, title: "A fresh chapter", date: engine.addingDays(65, to: today), theme: .sage, illustration: .sprout),
            CountEvent(kind: .countup, title: "Since we met", date: engine.addingDays(-128, to: today), theme: .lilac, illustration: .flower, tag: "Relationships", dayLabel: "days together"),
            CountEvent(kind: .countup, title: "Our first home", date: engine.addingDays(-260, to: today), theme: .apricot, illustration: .home)
        ]
    }

    func tickHaptic() { if preferences.haptics { UISelectionFeedbackGenerator().selectionChanged() } }
    func feedback(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        if preferences.haptics { UINotificationFeedbackGenerator().notificationOccurred(type) }
    }
    func motion(reduceMotion: Bool) -> Animation? {
        reduceMotion || preferences.gentleMotion ? nil : .spring(response: 0.36, dampingFraction: 0.86)
    }
    func showToast(_ text: String) {
        toastTask?.cancel(); toast = text
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }
    func celebrateIfNeeded(_ event: CountEvent) -> Bool {
        let occurrence = engine.occurrence(of: event, at: now)
        let key = "\(event.id):\(occurrence.year)-\(occurrence.month)-\(occurrence.day)"
        guard event.kind == .countdown, occurrence == engine.today(at: now), !celebratedOccurrences.contains(key) else { return false }
        celebratedOccurrences.insert(key)
        feedback(.success)
        return true
    }
    func syncReminders() {
        guard !isDemo, !loadFailed else { return }
        reminderRevision += 1
        let state = ReminderState(events: events, enabled: preferences.reminders, revision: reminderRevision)
        Task { await ReminderScheduler.shared.submit(state) }
    }
}
