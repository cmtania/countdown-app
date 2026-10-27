import SwiftUI

@MainActor struct EventEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draft: CountEvent
    private let original: CountEvent
    let isNew: Bool
    private let onClose: (() -> Void)?
    @State private var showAppearance = false
    @State private var discard = false
    @State private var showMore = false
    @State private var saved = false
    @FocusState private var nameFocused: Bool

    init(event: CountEvent, isNew: Bool, onClose: (() -> Void)? = nil) {
        _draft = State(initialValue: event)
        original = event
        self.isNew = isNew
        self.onClose = onClose
    }

    private var isDirty: Bool { draft != original }
    private var error: String? {
        if draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Give your event a little name." }
        do { try draft.validate(calendar: model.engine.calendar) } catch { return error.localizedDescription }
        if isNew || draft.date != original.date {
            if draft.kind == .countdown && draft.date < model.engine.today(at: model.now) { return "Choose today or a future date to count down to." }
            if draft.kind == .countup && draft.date > model.engine.today(at: model.now) { return "Choose today or a past date to count up from." }
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    HStack {
                        BrandFace(lift: saved ? 1 : 0).frame(width: 66)
                        Spacer()
                        Text(isNew ? (draft.kind == .countdown ? "Something to look forward to." : "A beginning worth remembering.") : "Make it yours.")
                            .font(TypeStyle.regular(13)).foregroundStyle(Palette.muted).multilineTextAlignment(.trailing)
                    }
                    VStack(alignment: .leading, spacing: 7) {
                        fieldLabel("NAME")
                        TextField("What are we counting?", text: $draft.title).formField()
                            .focused($nameFocused).submitLabel(.done).onSubmit { nameFocused = false }
                            .accessibilityLabel("Event name")
                    }
                    EventDatePicker(day: $draft.date, kind: draft.kind, now: model.now)
                    VStack(spacing: 12) {
                        if draft.kind == .countdown {
                            HStack {
                                Label("Repeat", systemImage: "repeat")
                                Spacer()
                                Picker("Repeat", selection: $draft.recurrence) {
                                    ForEach(Recurrence.allCases) { item in Text(item.title).tag(item) }
                                }.labelsHidden().tint(Palette.ink)
                            }.formField()
                            if draft.recurrence == .yearly && draft.date.month == 2 && draft.date.day == 29 {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("In non-leap years").font(TypeStyle.bold(14))
                                    Picker("Leap day anniversary", selection: $draft.leapDayPolicy) {
                                        ForEach(LeapDayPolicy.allCases) { policy in Text(policy.title).tag(policy) }
                                    }.pickerStyle(.segmented)
                                }.formField()
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 7) {
                                fieldLabel("DAY LABEL")
                                TextField("days since", text: $draft.dayLabel).formField().accessibilityLabel("Day label")
                            }
                        }
                        Button { nameFocused = false; showAppearance = true } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "paintpalette")
                                Text("Appearance").font(TypeStyle.regular(17))
                                Spacer()
                                Circle().fill(draft.theme.color).frame(width: 24, height: 24)
                                    .overlay(Circle().stroke(Palette.line))
                                Mascot(illustration: draft.illustration).frame(width: 40, height: 40)
                                Image(systemName: "chevron.right").font(.system(size: 12))
                            }.formField()
                        }.buttonStyle(.plain).accessibilityLabel("Appearance, \(draft.theme.title), \(draft.illustration.title)")
                        DisclosureGroup("Tag, note & reminder", isExpanded: $showMore) {
                            VStack(alignment: .leading, spacing: 16) {
                                TextField("Tag, e.g. Travel", text: $draft.tag).formField().accessibilityLabel("Tag")
                                TextField("A little note", text: $draft.note, axis: .vertical).lineLimit(3...6).formField().accessibilityLabel("Note")
                                if draft.kind == .countdown {
                                    Toggle("Remind me on the day", isOn: $draft.reminder).font(TypeStyle.bold(15))
                                    Text(model.preferences.reminders ? "At 9:00 AM local time. Today's reminder is skipped if that time has passed." : "Enable reminders in Settings to receive these at 9:00 AM local time.")
                                        .font(TypeStyle.regular(12)).foregroundStyle(Palette.muted)
                                }
                            }.padding(.top, 12)
                        }.font(TypeStyle.bold(14)).tint(Palette.orange).padding(.horizontal, 4)
                    }
                    if let error, !draft.title.isEmpty {
                        Text(error).font(TypeStyle.bold(13)).foregroundStyle(Palette.orange).multilineTextAlignment(.center)
                    }
                    Text("Saved on this iPhone. No account needed.")
                        .font(TypeStyle.regular(12)).foregroundStyle(Palette.muted).padding(.bottom, 4)
                }.padding(24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Palette.paper)
            .navigationTitle("\(isNew ? "Add" : "Edit") \(draft.kind.singular)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.paper, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { attemptClose() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Close editor").disabled(saved)
                }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { nameFocused = false } }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button(action: save) {
                    Label(saved ? "Saved" : isNew ? "Create \(draft.kind.singular)" : "Save changes", systemImage: saved ? "checkmark" : isNew ? "plus" : "checkmark")
                }.buttonStyle(PrimaryButtonStyle()).disabled(error != nil || saved || model.loadFailed)
                    .opacity(error != nil ? 0.5 : 1).padding(.horizontal, 24).padding(.vertical, 12).background(Palette.paper)
            }
            .interactiveDismissDisabled(isDirty || saved)
            .confirmationDialog("Discard your changes?", isPresented: $discard, titleVisibility: .visible) {
                Button("Discard changes", role: .destructive) { close() }
                Button("Keep editing", role: .cancel) {}
            }
            .sheet(isPresented: $showAppearance) { AppearancePicker(theme: $draft.theme, illustration: $draft.illustration) }
            .alert("Couldn't save", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
                Button("OK") { model.errorMessage = nil }
            } message: { Text(model.errorMessage ?? "") }
        }
        .font(TypeStyle.regular(17)).foregroundStyle(Palette.ink).tint(Palette.orange)
        .accessibilityAction(.escape) { attemptClose() }
    }

    private func fieldLabel(_ label: String) -> some View {
        Text(label).font(TypeStyle.regular(11)).tracking(1.4).foregroundStyle(Palette.muted)
    }

    private func save() {
        guard !saved, error == nil else { return }
        nameFocused = false
        guard model.save(draft) else { return }
        withAnimation(model.motion(reduceMotion: reduceMotion)) { saved = true }
        Task { @MainActor in
            if !reduceMotion && !model.preferences.gentleMotion { try? await Task.sleep(for: .milliseconds(360)) }
            close()
        }
    }

    private func attemptClose() {
        guard !saved else { return }
        if isDirty { discard = true } else { close() }
    }
    private func close() { nameFocused = false; if let onClose { onClose() } else { dismiss() } }
}

@MainActor struct AppearancePicker: View {
    @Binding var theme: EventTheme
    @Binding var illustration: Illustration
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var model
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Mascot(illustration: illustration).frame(width: 135, height: 135)
                        .padding(25).background(theme.color, in: RoundedRectangle(cornerRadius: 30))
                        .frame(maxWidth: .infinity)
                    Text("Pick a little personality.").font(TypeStyle.heavy(25))
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 78))], spacing: 14) {
                        ForEach(Illustration.allCases) { value in
                            Button {
                                illustration = value; model.tickHaptic()
                            } label: {
                                VStack(spacing: 6) {
                                    Mascot(illustration: value).frame(height: 60)
                                    Text(value.title).font(TypeStyle.bold(12))
                                }.padding(9).frame(maxWidth: .infinity)
                                    .background(illustration == value ? theme.color : Palette.field, in: RoundedRectangle(cornerRadius: 18))
                                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(illustration == value ? Palette.orange : .clear, lineWidth: 2))
                            }.buttonStyle(.plain).accessibilityLabel(value.title).accessibilityAddTraits(illustration == value ? .isSelected : [])
                        }
                    }
                    Text("And a color.").font(TypeStyle.heavy(25))
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 18) {
                        ForEach(EventTheme.allCases) { value in
                            Button { theme = value; model.tickHaptic() } label: {
                                VStack(spacing: 7) {
                                    Circle().fill(value.color).frame(width: 50, height: 50)
                                        .overlay(Circle().stroke(theme == value ? Palette.ink : Palette.line, lineWidth: theme == value ? 2 : 1))
                                        .overlay { if theme == value { Image(systemName: "checkmark").foregroundStyle(Palette.ink) } }
                                    Text(value.title).font(TypeStyle.regular(12))
                                }
                            }.buttonStyle(.plain).accessibilityLabel(value.title).accessibilityAddTraits(theme == value ? .isSelected : [])
                        }
                    }
                }.padding(24)
            }.background(Palette.paper).navigationTitle("Make it yours").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.font(TypeStyle.bold(16)) } }
        }.tint(Palette.orange).foregroundStyle(Palette.ink)
    }
}
