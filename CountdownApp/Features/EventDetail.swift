import SwiftUI
import UIKit

@MainActor struct EventDetail: View {
    let eventID: UUID
    var onClose: (() -> Void)? = nil
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var edit: EditorRequest?
    @State private var remove = false
    @State private var share: SharePayload?
    private var event: CountEvent? { model.event(eventID) }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let event {
                    VStack(spacing: 22) {
                        BrandFace().frame(width: 65)
                        VStack(spacing: 5) {
                            Text(event.title).font(TypeStyle.heavy(32)).multilineTextAlignment(.center)
                            Text(model.engine.formatted(model.engine.occurrence(of: event, at: model.now)))
                                .font(TypeStyle.regular(17)).foregroundStyle(Palette.muted)
                        }
                        EventTicket(event: event, count: count(event), label: model.engine.label(for: event, at: model.now),
                                    animateDigits: !reduceMotion && !model.preferences.gentleMotion)
                        HStack {
                            breakdown(count(event) / 7, label: "weeks")
                            Rectangle().fill(Palette.line).frame(width: 1, height: 48)
                            breakdown(count(event) % 7, label: "days")
                        }.padding(.vertical, 4).accessibilityElement(children: .combine)
                        if !event.tag.isEmpty || !event.note.isEmpty {
                            HStack(alignment: .top, spacing: 15) {
                                Mascot(illustration: event.illustration).frame(width: 48, height: 48)
                                VStack(alignment: .leading, spacing: 7) {
                                    if !event.tag.isEmpty { Text(event.tag).font(TypeStyle.regular(13)).foregroundStyle(Palette.muted) }
                                    if !event.note.isEmpty { Text(event.note).font(TypeStyle.bold(17)).textSelection(.enabled) }
                                }
                                Spacer(minLength: 0)
                            }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                                .background(Palette.field, in: RoundedRectangle(cornerRadius: 24))
                        }
                        if event.recurrence != .never {
                            Label("Repeats \(event.recurrence.title.lowercased())", systemImage: "repeat").font(TypeStyle.regular(14)).foregroundStyle(Palette.muted)
                            Text("Originally \(model.engine.formatted(event.date))").font(TypeStyle.regular(12)).foregroundStyle(Palette.muted)
                        }
                        if event.kind == .countdown && model.engine.occurrence(of: event, at: model.now) <= model.engine.today(at: model.now) {
                            Button("Keep counting from this day") { model.convertToCountup(event) }.font(TypeStyle.bold(16)).padding(.vertical, 10)
                        }
                        Button("Remove \(event.kind.singular)", role: .destructive) { remove = true }.font(TypeStyle.regular(14)).padding(12)
                    }.padding(24)
                }
            }.background(Palette.paper)
                .navigationTitle(event?.kind.singular.capitalized ?? "Event").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button { close() } label: { Image(systemName: "chevron.down") }.accessibilityLabel("Close details") }
                }
                .safeAreaInset(edge: .bottom) {
                    if let event {
                        HStack(spacing: 14) {
                            Button("Edit \(event.kind.singular)") { edit = EditorRequest(event: event, isNew: false) }
                                .buttonStyle(PrimaryButtonStyle())
                            Button { export(event) } label: { Image(systemName: "square.and.arrow.up") }
                                .buttonStyle(CircleButtonStyle()).accessibilityLabel("Share event image")
                        }.padding(.horizontal, 24).padding(.vertical, 12).background(Palette.paper)
                    }
                }
                .sheet(item: $edit) { request in EventEditor(event: request.event, isNew: false).environment(model) }
                .sheet(item: $share) { value in ShareSheet(image: value.image) }
                .confirmationDialog("Move this event to Recently deleted?", isPresented: $remove, titleVisibility: .visible) {
                    Button("Remove event", role: .destructive) { if let event, model.remove(event) { close() } }
                    Button("Cancel", role: .cancel) {}
                } message: { Text("You can restore it from Settings.") }
                .alert("Couldn't complete that", isPresented: Binding(get: { model.errorMessage != nil && edit == nil }, set: { if !$0 { model.errorMessage = nil } })) {
                    Button("OK") { model.errorMessage = nil }
                } message: { Text(model.errorMessage ?? "") }
        }.font(TypeStyle.regular(17)).foregroundStyle(Palette.ink).tint(Palette.orange)
            .accessibilityAction(.escape) { close() }
    }

    private func count(_ event: CountEvent) -> Int { model.engine.count(for: event, at: model.now) }
    private func close() { if let onClose { onClose() } else { dismiss() } }
    private func breakdown(_ number: Int, label: String) -> some View {
        VStack(spacing: 0) {
            Text(number.formatted()).font(TypeStyle.heavy(40)).minimumScaleFactor(0.6).lineLimit(1)
            Text(number == 1 ? String(label.dropLast()) : label).font(TypeStyle.regular(15))
        }.frame(maxWidth: .infinity)
    }

    @MainActor private func export(_ event: CountEvent) {
        let renderer = ImageRenderer(content: ShareCard(event: event, engine: model.engine, now: model.now)
            .environment(\.colorScheme, .light).environment(\.dynamicTypeSize, .large))
        renderer.scale = 3
        guard let image = renderer.uiImage else { model.errorMessage = "The image could not be created. Please try again."; return }
        share = SharePayload(image: image)
    }
}

private struct SharePayload: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct ShareCard: View {
    let event: CountEvent
    let engine: DateEngine
    let now: Date
    var body: some View {
        VStack(spacing: 20) {
            Text(event.title).font(TypeStyle.heavy(29)).multilineTextAlignment(.center)
            Text(engine.formatted(engine.occurrence(of: event, at: now))).font(TypeStyle.regular(17)).foregroundStyle(Palette.muted)
            EventTicket(event: event, count: engine.count(for: event, at: now), label: engine.label(for: event, at: now), animateDigits: false)
            Text(event.kind == .countdown ? "Good things ahead." : "A little more, every day.").font(TypeStyle.bold(15))
        }.padding(28).frame(width: 390).background(Palette.paper).foregroundStyle(Palette.ink)
    }
}

@MainActor private struct ShareSheet: UIViewControllerRepresentable {
    let image: UIImage
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: [image], applicationActivities: nil) }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
