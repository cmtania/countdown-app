import Foundation
import UserNotifications

struct ReminderState: Sendable {
    let events: [CountEvent]
    let enabled: Bool
    let revision: Int
}

/// One serialized worker reconciles the newest state, preventing older saves
/// from reintroducing reminders after deletion or a preferences change.
actor ReminderScheduler {
    static let shared = ReminderScheduler()
    private var pending: ReminderState?
    private var processing = false
    private var latestRevision = -1
    private let prefix = "calendar-event."

    func submit(_ state: ReminderState) async {
        guard state.revision > latestRevision else { return }
        latestRevision = state.revision
        pending = state
        guard !processing else { return }
        processing = true
        while let next = pending {
            pending = nil
            await reconcile(next)
        }
        processing = false
    }

    private func reconcile(_ state: ReminderState) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        let requests = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: requests.filter { $0.identifier.hasPrefix(prefix) }.map(\.identifier))
        guard state.enabled, [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus) else { return }
        let now = Date(), engine = DateEngine()
        // Schedule the nearest 60 occurrences, sharing iOS's pending limit fairly.
        // Future repeating occurrences are refreshed on each foreground/save.
        var dates: [(CountEvent, CalendarDay)] = []
        for event in state.events where event.kind == .countdown && event.reminder {
            var cursor = now
            for _ in 0..<(event.recurrence == .never ? 1 : 12) {
                let day = engine.occurrence(of: event, at: cursor)
                if day >= engine.today(at: now) { dates.append((event, day)) }
                guard event.recurrence != .never,
                      let next = engine.addingDays(1, to: day).date(in: engine.calendar) else { break }
                cursor = next
            }
        }
        for (event, day) in dates.sorted(by: { $0.1 < $1.1 }).prefix(60) {
            var components = DateComponents(year: day.year, month: day.month, day: day.day, hour: 9)
            components.calendar = engine.calendar
            guard let fireDate = engine.calendar.date(from: components), fireDate > now else { continue }
            let content = UNMutableNotificationContent()
            content.title = "Today is the day!"
            content.body = event.title
            content.sound = .default
            content.userInfo = ["eventID": event.id.uuidString]
            let id = "\(prefix)\(event.id).\(day.year)-\(day.month)-\(day.day)"
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            do { try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger)) }
            catch { await MainActor.run { NotificationCenter.default.post(name: .reminderSchedulingFailed, object: nil) } }
        }
    }
}

extension Notification.Name {
    static let reminderSchedulingFailed = Notification.Name("reminderSchedulingFailed")
    static let openCountEvent = Notification.Name("openCountEvent")
}

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if let id = response.notification.request.content.userInfo["eventID"] as? String {
            UserDefaults.standard.set(id, forKey: "pendingNotificationEvent")
            DispatchQueue.main.async { NotificationCenter.default.post(name: .openCountEvent, object: id) }
        }
        completionHandler()
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
