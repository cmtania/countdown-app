import SwiftUI
import UserNotifications
import UIKit

@MainActor struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var notificationState: UNAuthorizationStatus = .notDetermined
    @State private var requesting = false
    @State private var notificationError: String?

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        BrandFace().frame(width: 100)
                        Text("In your own time.").font(TypeStyle.heavy(27))
                        Text("A little company for your days.").font(TypeStyle.regular(15)).foregroundStyle(Palette.muted)
                    }.frame(maxWidth: .infinity).padding(.vertical, 17)
                }.listRowBackground(Color.clear)
                Section {
                    Toggle("Gentle motion", isOn: $model.preferences.gentleMotion)
                    Toggle("Haptic feedback", isOn: $model.preferences.haptics)
                } header: { Text("Feel") } footer: {
                    Text("Gentle motion removes expressive movement. Your iPhone's Reduce Motion setting is always respected.")
                }
                Section {
                    Toggle("Date reminders", isOn: Binding(get: { model.preferences.reminders }, set: setReminders))
                        .disabled(requesting || model.isDemo)
                    if requesting { ProgressView("Checking permission…") }
                    if notificationState == .denied {
                        Text("Notifications are disabled in iPhone Settings.").foregroundStyle(Palette.muted)
                        Button("Open iPhone Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                        }
                    }
                    if model.preferences.reminders {
                        Button("Refresh scheduled reminders") { model.syncReminders(); model.showToast("Refreshing your date reminders.") }
                    }
                    if let notificationError { Text(notificationError).foregroundStyle(Palette.orange) }
                } header: { Text("A gentle nudge") } footer: {
                    Text("Enable a reminder on each countdown you want to hear about. Delivery is at 9:00 AM local time. Up to 60 upcoming reminders are scheduled; recurring dates refresh when you open the app.")
                }
                Section {
                    NavigationLink {
                        RecentlyDeletedView()
                    } label: {
                        HStack { Label("Recently deleted", systemImage: "arrow.uturn.backward"); Spacer(); Text("\(model.collection.deleted.count)").foregroundStyle(Palette.muted) }
                    }
                    if !model.isDemo && FileManager.default.fileExists(atPath: model.store.url.path) {
                        ShareLink(item: model.store.url) { Label("Export collection", systemImage: "square.and.arrow.up") }
                    }
                } header: { Text("Your collection") } footer: {
                    Text("Events stay on this iPhone. Deleted events remain recoverable here. No account, advertising, or analytics.")
                }
                Section("About") {
                    NavigationLink("Typography & license") { FontLicenseView() }
                    HStack { Text("Version"); Spacer(); Text("1.0 · Build 1").foregroundStyle(Palette.muted) }
                }
            }
            .font(TypeStyle.regular(16)).scrollContentBackground(.hidden).background(Palette.paper)
            .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task { await refreshPermission() }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in Task { await refreshPermission() } }
            .alert("Couldn't complete that", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
                Button("OK") { model.errorMessage = nil }
            } message: { Text(model.errorMessage ?? "") }
        }.tint(Palette.orange).foregroundStyle(Palette.ink)
    }

    private func setReminders(_ enabled: Bool) {
        if !enabled { model.preferences.reminders = false; model.syncReminders(); return }
        requesting = true
        Task { @MainActor in
            defer { requesting = false }
            do {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                model.preferences.reminders = granted
                notificationError = granted ? nil : "Allow notifications in iPhone Settings to turn on reminders."
                await refreshPermission()
                model.syncReminders()
            } catch { notificationError = error.localizedDescription }
        }
    }

    private func refreshPermission() async {
        notificationState = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        if notificationState == .denied { model.preferences.reminders = false; model.syncReminders() }
    }
}

@MainActor private struct RecentlyDeletedView: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        List {
            if model.collection.deleted.isEmpty {
                VStack(spacing: 20) {
                    BrandFace().frame(width: 120)
                    Text("Nothing left behind.").font(TypeStyle.heavy(24))
                    Text("Removed events will wait here until you restore them.").font(TypeStyle.regular(16)).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity).padding(.vertical, 35).listRowBackground(Color.clear)
            }
            ForEach(model.collection.deleted.sorted { $0.deletedAt > $1.deletedAt }) { item in
                VStack(alignment: .leading, spacing: 10) {
                    Text(item.event.title).font(TypeStyle.bold(19))
                    Text(model.engine.formatted(item.event.date)).font(TypeStyle.regular(14)).foregroundStyle(Palette.muted)
                    Button("Restore \(item.event.kind.singular)") { model.restore(item) }.font(TypeStyle.bold(15))
                }.padding(.vertical, 8).listRowBackground(Palette.field)
            }
        }.scrollContentBackground(.hidden).background(Palette.paper).navigationTitle("Recently deleted")
    }
}

private struct FontLicenseView: View {
    private var text: String {
        guard let url = Bundle.main.url(forResource: "OFL", withExtension: "txt", subdirectory: "Fonts"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return "Nunito — SIL Open Font License 1.1. License is included in the app's Fonts resources." }
        return text
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Nunito").font(TypeStyle.heavy(34))
                Text("The supplied regular, bold, and heavy faces are bundled locally. Their internal names were made unique; the original letterforms are unchanged.").font(TypeStyle.regular(16))
                Text(text).font(TypeStyle.regular(13)).textSelection(.enabled)
            }.padding(24)
        }.background(Palette.paper).navigationTitle("Typography")
    }
}
