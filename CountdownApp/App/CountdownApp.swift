import SwiftUI
import UserNotifications

@main
@MainActor
struct CountdownApp: App {
    @State private var model = AppModel()
    private let notificationDelegate = NotificationDelegate()

    init() { UNUserNotificationCenter.current().delegate = notificationDelegate }

    var body: some Scene {
        WindowGroup {
            HomeView().environment(model)
                .font(TypeStyle.regular(17))
                .foregroundStyle(Palette.ink)
                .tint(Palette.orange)
                .preferredColorScheme(.light)
        }
    }
}
