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

    private var index: Int { values.firstIndex(of: value) ?? 0 }
    private func neighbor(_ offset: Int) -> String {
        let i = index + offset
        return values.indices.contains(i) ? display(values[i]) : "·"
    }

    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { proxy in
                let size = min(proxy.size.width, proxy.size.height)
                ZStack {
                    Circle().fill(Color(hex: 0xFFFCF5)).shadow(color: Palette.ink.opacity(0.05), radius: 8, y: 3)
                    ForEach(0..<60) { tick in
                        Rectangle().fill(Palette.muted.opacity(0.40)).frame(width: 1, height: tick % 5 == 0 ? 8 : 5)
                            .offset(y: -size / 2 + 12).rotationEffect(.degrees(Double(tick) * 6 + Double(drag) * 0.2))
                    }
                    VStack(spacing: 4) {
                        Text(neighbor(-1)).font(TypeStyle.bold(size * 0.12)).foregroundStyle(Palette.muted.opacity(0.55))
                        Text(display(value)).font(TypeStyle.heavy(size * (title == "MONTH" ? 0.21 : 0.31)))
                            .lineLimit(1).minimumScaleFactor(0.5)
                            .contentTransition(reduceMotion || model.preferences.gentleMotion ? .identity : title == "MONTH" ? .opacity : .numericText())
                        Text(neighbor(1)).font(TypeStyle.bold(size * 0.12)).foregroundStyle(Palette.muted.opacity(0.55))
                    }.offset(y: drag * 0.09)
                    Circle().fill(Palette.ink).frame(width: size * 0.1, height: size * 0.1)
                        .offset(x: size * 0.35, y: 0)
                }.frame(width: size, height: size).contentShape(Circle())
                    .gesture(DragGesture(minimumDistance: 8)
                        .onChanged { gesture in
                            drag = reduceMotion || model.preferences.gentleMotion ? 0 : gesture.translation.height.truncatingRemainder(dividingBy: 34)
                            let step = Int((-gesture.translation.height / 34).rounded(.towardZero))
                            if step != lastStep { change(step - lastStep); lastStep = step }
                        }
                        .onEnded { _ in
                            lastStep = 0
                            withAnimation(model.motion(reduceMotion: reduceMotion)) { drag = 0 }
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
    }

    private func change(_ delta: Int) {
        let next = min(values.count - 1, max(0, index + delta))
        guard values.indices.contains(next), values[next] != value else { return }
        withAnimation(model.motion(reduceMotion: reduceMotion)) { value = values[next] }
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
