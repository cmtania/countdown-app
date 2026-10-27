import SwiftUI
import UIKit

struct EditorRequest: Identifiable {
    let id = UUID()
    let event: CountEvent
    let isNew: Bool
}

@MainActor struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var textSize
    @Environment(\.scenePhase) private var scenePhase
    @State private var editor: EditorRequest?
    @State private var detail: CountEvent?
    @State private var showSettings = false
    @State private var showList = false
    @State private var closingEditor = false
    @State private var closingDetail = false
    @State private var glance: CGFloat = 0
    @State private var celebrating = false
    @State private var expressionTask: Task<Void, Never>?
    @ScaledMetric(relativeTo: .largeTitle) private var pageHeight: CGFloat = 465

    private var ordered: [CountEvent] { model.ordered(model.kind) }
    private var selected: CountEvent? { ordered.first { $0.id == model.selectedID } ?? ordered.first }
    private var pageNumber: Int { (ordered.firstIndex { $0.id == model.selectedID } ?? 0) + 1 }
    private var next: CountEvent? {
        guard ordered.count > 1, let selected, let index = ordered.firstIndex(where: { $0.id == selected.id }) else { return nil }
        return ordered[(index + 1) % ordered.count]
    }

    var body: some View {
        ZStack {
            Palette.paper.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    header
                    if model.loadFailed { recovery }
                    else if ordered.isEmpty { emptyState }
                    else { eventPages }
                }.padding(.top, 12).padding(.bottom, 20)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { tabBar }
            .allowsHitTesting(editor == nil && detail == nil)
            .accessibilityHidden(editor != nil || detail != nil)
            .overlay(alignment: .top) {
                if let text = model.toast {
                    Text(text).font(TypeStyle.bold(14)).foregroundStyle(.white)
                        .padding(14).background(Palette.ink, in: Capsule())
                        .padding(.horizontal, 20).padding(.top, 5)
                        .accessibilityAddTraits(.updatesFrequently)
                        .transition(.opacity).allowsHitTesting(false)
                }
            }
        }
        .overlayPreferenceValue(PanelAnchorKey.self) { anchors in
            GeometryReader { proxy in
                if let request = editor {
                    let fallback = CGRect(x: proxy.size.width / 2 - 47, y: proxy.size.height - 65, width: 94, height: 60)
                    let origin = anchors["add"].map { proxy[$0] } ?? fallback
                    ExpandingPanel(origin: origin, canvas: proxy.size, originColor: Palette.orange,
                                   motion: model.motion(reduceMotion: reduceMotion), closing: $closingEditor,
                                   onDismiss: { editor = nil; closingEditor = false }) {
                        EventEditor(event: request.event, isNew: request.isNew, onClose: { closingEditor = true }).environment(model)
                    }.id(request.id)
                } else if let event = detail {
                    let fallback = CGRect(x: 24, y: 180, width: proxy.size.width - 48, height: 360)
                    let origin = anchors[event.id.uuidString].map { proxy[$0] } ?? fallback
                    ExpandingPanel(origin: origin, canvas: proxy.size, originColor: model.event(event.id)?.theme.color ?? event.theme.color,
                                   motion: model.motion(reduceMotion: reduceMotion), closing: $closingDetail,
                                   onDismiss: { detail = nil; closingDetail = false }) {
                        EventDetail(eventID: event.id, onClose: { closingDetail = true }).environment(model)
                    }.id(event.id)
                }
            }.allowsHitTesting(editor != nil || detail != nil)
        }
        .sheet(isPresented: $showSettings) { SettingsView().environment(model) }
        .sheet(isPresented: $showList) { EventListView(kind: model.kind).environment(model) }
        .alert("A little hiccup", isPresented: Binding(get: { model.errorMessage != nil && editor == nil && detail == nil && !showSettings && !showList }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
        .task {
            model.refresh(); openPendingNotification()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { return }
                if scenePhase == .active { model.refresh() }
            }
        }
        .onChange(of: scenePhase) { _, value in
            if value == .active { model.refresh(); openPendingNotification() }
            else { expressionTask?.cancel(); glance = 0; celebrating = false }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in model.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in model.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .openCountEvent)) { _ in openPendingNotification() }
        .onReceive(NotificationCenter.default.publisher(for: .reminderSchedulingFailed)) { _ in
            model.showToast("Some reminders could not be scheduled. Open Settings to retry.")
        }
        .onChange(of: model.selectedID) { _, _ in animateExpression() }
        .onChange(of: model.engine.today(at: model.now)) { _, _ in animateExpression() }
        .onDisappear { expressionTask?.cancel() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                BrandFace().frame(width: 69, height: 48)
                Spacer()
                if model.isDemo { Text("PREVIEW").font(TypeStyle.bold(10)).foregroundStyle(Palette.muted) }
                Button { showSettings = true } label: { Image(systemName: "gearshape") }
                    .buttonStyle(CircleButtonStyle()).accessibilityLabel("Settings")
            }
            HStack(alignment: .firstTextBaseline) {
                Text(model.kind.title).font(TypeStyle.heavy(36)).minimumScaleFactor(0.7).lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 4)
                if !ordered.isEmpty {
                    Button { showList = true } label: {
                        Text("\(pageNumber.formatted(.number.precision(.integerLength(2)))) / \(ordered.count.formatted(.number.precision(.integerLength(2))))")
                            .font(TypeStyle.regular(13)).foregroundStyle(Palette.muted).padding(.vertical, 12)
                    }.accessibilityLabel("All \(model.kind.title.lowercased()), \(ordered.count) events")
                }
            }
        }.padding(.horizontal, 24)
    }

    private var eventPages: some View {
        VStack(spacing: 16) {
            if textSize.isAccessibilitySize {
                if let selected { page(selected).padding(.horizontal, 24) }
                HStack {
                    Button("Previous") { moveSelection(-1) }
                    Spacer()
                    Button("All events") { showList = true }
                    Spacer()
                    Button("Next") { moveSelection(1) }
                }.font(TypeStyle.bold(15)).padding(.horizontal, 24)
            } else {
                TabView(selection: Binding(get: { model.selectedID }, set: { model.selectedID = $0 })) {
                    ForEach(ordered) { event in
                        page(event).padding(.horizontal, 24).tag(Optional(event.id))
                    }
                }.tabViewStyle(.page(indexDisplayMode: .never)).frame(height: pageHeight)
            }
            HStack(spacing: 9) {
                ForEach(Array(ordered.prefix(7).enumerated()), id: \.element.id) { index, event in
                    Button { withAnimation(model.motion(reduceMotion: reduceMotion)) { model.select(event) } } label: {
                        Circle().fill(selected?.id == event.id ? Palette.orange : Palette.line).frame(width: 9, height: 9)
                            .frame(width: 24, height: 30)
                    }.accessibilityLabel("Show \(event.title)").accessibilityAddTraits(selected?.id == event.id ? .isSelected : [])
                }
                if ordered.count > 7 { Button("All") { showList = true }.font(TypeStyle.bold(12)) }
            }
            if let next {
                Button { withAnimation(model.motion(reduceMotion: reduceMotion)) { model.select(next) } } label: {
                    EventRow(event: next, engine: model.engine, now: model.now, prefix: "Next · ")
                }.buttonStyle(.plain).padding(.horizontal, 24)
            }
        }
    }

    private func page(_ event: CountEvent) -> some View {
        VStack(spacing: 17) {
            VStack(spacing: 4) {
                Text(event.title).font(TypeStyle.heavy(27)).multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.8)
                Text(model.engine.formatted(model.engine.occurrence(of: event, at: model.now)))
                    .font(TypeStyle.regular(16)).foregroundStyle(Palette.muted)
            }.frame(minHeight: 64)
            Button { detail = event } label: {
                EventTicket(event: event, count: model.engine.count(for: event, at: model.now),
                            label: model.engine.label(for: event, at: model.now), glance: glance,
                            celebrate: celebrating, animateDigits: !reduceMotion && !model.preferences.gentleMotion)
            }.buttonStyle(.plain).accessibilityHint("Opens event details and editing")
                .anchorPreference(key: PanelAnchorKey.self, value: .bounds) { [event.id.uuidString: $0] }
                .opacity(detail?.id == event.id ? 0 : 1)
        }.frame(maxHeight: .infinity, alignment: .top)
    }

    private var tabBar: some View {
        HStack(spacing: 12) {
            tab(.countdown)
            Button {
                model.tickHaptic()
                editor = EditorRequest(event: model.newEvent(), isNew: true)
            } label: {
                Image(systemName: "plus").font(.system(size: 28, weight: .medium))
                    .frame(width: 94, height: 60).foregroundStyle(.white).background(Palette.orange, in: Capsule())
            }.accessibilityLabel("Add \(model.kind.singular)").disabled(model.loadFailed)
                .anchorPreference(key: PanelAnchorKey.self, value: .bounds) { ["add": $0] }
                .opacity(editor == nil ? 1 : 0)
            tab(.countup)
        }.padding(.horizontal, 22).padding(.top, 10).padding(.bottom, 5)
            .background(Palette.paper.shadow(color: Palette.ink.opacity(0.03), radius: 10, y: -4))
            .overlay(alignment: .top) { Rectangle().fill(Palette.line.opacity(0.6)).frame(height: 1) }
    }

    private func tab(_ kind: EventKind) -> some View {
        Button {
            withAnimation(model.motion(reduceMotion: reduceMotion)) { model.kind = kind }
            model.tickHaptic()
        } label: {
            VStack(spacing: 5) {
                Image(systemName: kind == .countdown ? "calendar.badge.clock" : "calendar.badge.checkmark").font(.system(size: 25))
                Text(kind.title).font(TypeStyle.bold(12)).lineLimit(1).minimumScaleFactor(0.6)
            }.frame(maxWidth: .infinity, minHeight: 56)
                .foregroundStyle(model.kind == kind ? Palette.orange : Palette.muted)
        }.accessibilityAddTraits(model.kind == kind ? .isSelected : [])
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            BrandFace().frame(width: 180).padding(.top, 45)
            Text(model.kind == .countdown ? "Good things ahead." : "Every beginning counts.")
                .font(TypeStyle.heavy(29)).multilineTextAlignment(.center)
            Text(model.kind == .countdown ? "A birthday, a big adventure, or simply next Friday. Give it a date." : "A first hello. A fresh start. Keep track of how far you've come.")
                .font(TypeStyle.regular(17)).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
            Button("Add your first \(model.kind.singular)") { editor = EditorRequest(event: model.newEvent(), isNew: true) }
                .buttonStyle(PrimaryButtonStyle()).padding(.top, 10)
            if model.events.isEmpty {
                Button("Try a few examples") { model.addExamples() }.font(TypeStyle.bold(14)).padding(12)
            }
        }.padding(.horizontal, 32).padding(.bottom, 30)
    }

    private var recovery: some View {
        VStack(spacing: 20) {
            BrandFace().frame(width: 150)
            Text("Your collection needs a little care.").font(TypeStyle.heavy(26)).multilineTextAlignment(.center)
            Text("The saved file is untouched. Retry opening it, or export it for recovery.")
                .multilineTextAlignment(.center).font(TypeStyle.regular(16))
            Button("Retry loading") { model.load() }.buttonStyle(PrimaryButtonStyle())
            if FileManager.default.fileExists(atPath: model.store.url.path) {
                ShareLink(item: model.store.url) { Label("Export saved file", systemImage: "square.and.arrow.up") }
            }
        }.padding(30)
    }

    private func moveSelection(_ offset: Int) {
        guard !ordered.isEmpty else { return }
        let index = ordered.firstIndex { $0.id == model.selectedID } ?? 0
        model.select(ordered[(index + offset + ordered.count) % ordered.count])
    }

    private func animateExpression() {
        expressionTask?.cancel()
        guard !reduceMotion, !model.preferences.gentleMotion, scenePhase == .active else { return }
        withAnimation(model.motion(reduceMotion: reduceMotion)) {
            glance = 0.8
            if let selected { celebrating = model.celebrateIfNeeded(selected) }
        }
        expressionTask = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            withAnimation(model.motion(reduceMotion: reduceMotion)) { glance = 0; celebrating = false }
        }
    }

    private func openPendingNotification() {
        guard !model.isDemo, let raw = UserDefaults.standard.string(forKey: "pendingNotificationEvent"),
              let id = UUID(uuidString: raw) else { return }
        UserDefaults.standard.removeObject(forKey: "pendingNotificationEvent")
        if let event = model.event(id) { model.select(event) }
    }
}
