import SwiftUI
import UIKit

@MainActor struct DateEyeWheel: View {
    let title: String
    let values: [Int]
    @Binding var value: Int
    let display: (Int) -> String
    let onStep: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppModel.self) private var model
    @State private var drag: CGFloat = 0
    @State private var lastStep = 0
    @GestureState private var isDragging = false

    private var index: Int { values.firstIndex(of: value) ?? 0 }
    private var motionEnabled: Bool { !reduceMotion && !model.preferences.gentleMotion }
    private var selectionMotion: Animation? { motionEnabled ? .spring(response: 0.30, dampingFraction: 0.86) : nil }

    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { proxy in
                let size = min(proxy.size.width, proxy.size.height)
                let stepDistance = max(1, size * 0.25)
                ZStack {
                    Circle().fill(Color(hex: 0xFFFCF5)).shadow(color: Palette.ink.opacity(0.05), radius: 8, y: 3)
                    ForEach(0..<60) { tick in
                        Rectangle().fill(Palette.muted.opacity(0.40)).frame(width: 1, height: tick % 5 == 0 ? 8 : 5)
                            .offset(y: -size / 2 + 12)
                            .rotationEffect(.degrees(Double(tick) * 6 + (motionEnabled ? Double(index) * 6 - Double(drag / stepDistance) * 6 : 0)))
                            .animation(selectionMotion, value: value)
                    }
                    // Stable identities let each value travel between the neighbor
                    // and selected positions instead of replacing the center text.
                    ZStack {
                        ForEach(Array(values.enumerated()), id: \.element) { position, candidate in
                            let distance = position - index
                            Text(display(candidate))
                                .font(TypeStyle.heavy(size * (title == "MONTH" ? 0.21 : 0.31)))
                                .lineLimit(1).minimumScaleFactor(0.5)
                                .scaleEffect(distance == 0 ? 1 : (title == "MONTH" ? 0.57 : 0.39))
                                .frame(width: size * 0.64, height: stepDistance)
                                .contentShape(Rectangle())
                                .onTapGesture { change(distance) }
                                .foregroundStyle(Palette.ink.opacity(distance == 0 ? 1 : 0.42))
                                .offset(y: CGFloat(distance) * stepDistance + drag)
                                .opacity(abs(distance) <= 2 ? 1 : 0)
                                .allowsHitTesting(abs(distance) == 1)
                        }
                    }
                    .frame(width: size * 0.66, height: size * 0.73)
                    .mask(LinearGradient(stops: [
                        .init(color: .clear, location: 0), .init(color: .white, location: 0.12),
                        .init(color: .white, location: 0.88), .init(color: .clear, location: 1)
                    ], startPoint: .top, endPoint: .bottom))
                    .clipped()
                    .animation(selectionMotion, value: value)
                    Circle().fill(Palette.ink).frame(width: size * 0.1, height: size * 0.1)
                        .offset(x: size * 0.35, y: motionEnabled ? drag * 0.1 : 0)
                }.frame(width: size, height: size).contentShape(Circle())
                    .gesture(DragGesture(minimumDistance: 8)
                        .updating($isDragging) { _, active, _ in active = true }
                        .onChanged { gesture in
                            let step = Int((-gesture.translation.height / stepDistance).rounded(.towardZero))
                            if step != lastStep { change(step - lastStep); lastStep = step }
                            let remainder = gesture.translation.height + CGFloat(step) * stepDistance
                            let atBoundary = (index == 0 && remainder > 0) || (index == values.count - 1 && remainder < 0)
                            drag = motionEnabled ? remainder * (atBoundary ? 0.15 : 1) : 0
                        }
                        .onEnded { gesture in
                            // Snap to the closest value without momentum skipping
                            // over a date the user did not deliberately select.
                            let step = Int((-gesture.translation.height / stepDistance).rounded())
                            change(step - lastStep)
                            lastStep = 0
                            withAnimation(selectionMotion) { drag = 0 }
                        })
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(title == "MONTH" ? "Month" : "Day")
                    .accessibilityValue(display(value))
                    .accessibilityHint("Swipe up or down to adjust. Activate the year to open the calendar.")
                    .accessibilityAdjustableAction { direction in
                        if direction == .increment { change(1) }
                        if direction == .decrement { change(-1) }
                    }
            }.aspectRatio(1, contentMode: .fit)
            Text(title).font(TypeStyle.regular(11)).tracking(1.5)
        }
        .onChange(of: motionEnabled) { _, enabled in
            if !enabled { drag = 0 }
        }
        .onChange(of: isDragging) { _, active in
            if !active {
                lastStep = 0
                withAnimation(selectionMotion) { drag = 0 }
            }
        }
        .onDisappear { drag = 0; lastStep = 0 }
    }

    private func change(_ delta: Int) {
        let next = min(values.count - 1, max(0, index + delta))
        guard values.indices.contains(next), values[next] != value else { return }
        withAnimation(selectionMotion) { value = values[next] }
        onStep()
    }
}

@MainActor struct EventDatePicker: View {
    @Binding var day: CalendarDay
    let kind: EventKind
    let now: Date
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var useCalendar = false
    private var engine: DateEngine { model.engine }

    private var monthBinding: Binding<Int> {
        Binding(get: { day.month }, set: { update(year: day.year, month: $0, value: day.day) })
    }
    private var dayBinding: Binding<Int> {
        Binding(get: { day.day }, set: { update(year: day.year, month: day.month, value: $0) })
    }
    private var dateBinding: Binding<Date> {
        Binding(get: { day.date(in: engine.calendar) ?? now }, set: { day = CalendarDay($0, calendar: engine.calendar) })
    }

    var body: some View {
        VStack(spacing: 13) {
            Text("CHOOSE A DATE")
                .font(TypeStyle.regular(12)).foregroundStyle(Palette.ink)
            if textSize.isAccessibilitySize {
                DatePicker("Date", selection: dateBinding, displayedComponents: .date)
                    .datePickerStyle(.graphical).environment(\.calendar, engine.calendar)
                    .tint(Palette.orange)
            } else {
                HStack(spacing: 15) {
                    Button { update(year: day.year - 1, month: day.month, value: day.day); model.tickHaptic() } label: {
                        Image(systemName: "chevron.left").frame(width: 44, height: 44)
                    }.disabled(day.year <= 1).accessibilityLabel("Previous year")
                    Button { useCalendar = true } label: {
                        Text(String(day.year)).font(TypeStyle.heavy(25)).monospacedDigit().frame(minHeight: 44)
                    }.accessibilityLabel("Year \(day.year), open calendar")
                        .accessibilityHint("Choose any date using the calendar.")
                    Button { update(year: day.year + 1, month: day.month, value: day.day); model.tickHaptic() } label: {
                        Image(systemName: "chevron.right").frame(width: 44, height: 44)
                    }.disabled(day.year >= 9999).accessibilityLabel("Next year")
                }.foregroundStyle(Palette.ink).background(Palette.field, in: Capsule())
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        DateEyeWheel(title: "MONTH", values: Array(1...12), value: monthBinding,
                                     display: { month in engine.calendar.shortMonthSymbols[month - 1].uppercased() }, onStep: model.tickHaptic)
                        DateEyeWheel(title: "DAY", values: Array(1...engine.daysInMonth(year: day.year, month: day.month)),
                                     value: dayBinding, display: { String($0) }, onStep: model.tickHaptic)
                    }
                    HStack(alignment: .top, spacing: 8) {
                        Circle().fill(Palette.cheek).frame(width: 46, height: 46).offset(y: -28)
                        BrandSmile().frame(height: 70).padding(.top, 1)
                        Circle().fill(Palette.cheek).frame(width: 46, height: 46).offset(y: -28)
                    }.accessibilityHidden(true)
                }
            }
            Text(dateSummary).font(TypeStyle.regular(15)).multilineTextAlignment(.center)
                .foregroundStyle(Palette.muted).accessibilityAddTraits(.updatesFrequently)
        }
        .sheet(isPresented: $useCalendar) {
            NavigationStack {
                ScrollView {
                    DatePicker(kind == .countdown ? "Count down to" : "Count up from", selection: dateBinding, displayedComponents: .date)
                        .datePickerStyle(.graphical).environment(\.calendar, engine.calendar)
                        .tint(Palette.orange).padding(20)
                }.background(Palette.paper)
                    .navigationTitle("Choose a date").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { useCalendar = false } } }
            }.presentationDetents([.medium, .large])
        }
    }

    private var dateSummary: String {
        let distance = engine.difference(from: engine.today(at: now), to: day)
        let suffix = distance == 0 ? "Today" : distance > 0 ? "\(distance) days away" : "\(-distance) days ago"
        return "\(engine.formatted(day)) · \(suffix)"
    }

    private func update(year: Int, month: Int, value: Int) {
        let next = engine.clamped(year: year, month: month, day: value)
        if next.day != value {
            UIAccessibility.post(notification: .announcement, argument: "Day adjusted to \(next.day) for this month.")
        }
        day = next
    }
}
