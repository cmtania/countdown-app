import SwiftUI

struct TicketShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path(roundedRect: rect, cornerRadius: 30)
        let radius: CGFloat = 12
        p.addEllipse(in: CGRect(x: -radius, y: rect.height * 0.37 - radius, width: radius * 2, height: radius * 2))
        p.addEllipse(in: CGRect(x: rect.width - radius, y: rect.height * 0.37 - radius, width: radius * 2, height: radius * 2))
        return p
    }
}

struct EventTicket: View {
    let event: CountEvent
    let count: Int
    let label: String
    var glance: CGFloat = 0
    var celebrate = false
    var animateDigits = true

    var body: some View {
        VStack(spacing: 0) {
            BrandEyes(glance: glance).frame(width: 150, height: 76).padding(.top, 23)
            HStack(spacing: 8) {
                Circle().fill(Palette.cheek).frame(width: 35, height: 35)
                Text(count.formatted()).font(TypeStyle.heavy(136)).monospacedDigit()
                    .minimumScaleFactor(0.3).lineLimit(1)
                    .contentTransition(animateDigits ? .numericText(value: Double(count)) : .identity)
                    .frame(maxWidth: .infinity)
                Circle().fill(Palette.cheek).frame(width: 35, height: 35)
            }.padding(.horizontal, 25).padding(.top, -4)
            BrandSmile(lift: celebrate ? 1 : 0).frame(width: 211, height: 67).padding(.top, -7)
            Text(label).font(TypeStyle.bold(23)).multilineTextAlignment(.center)
                .padding(.horizontal, 24).padding(.top, 3)
            Text(event.kind == .countup ? "A little more, every day." : "Something good is on its way.")
                .font(TypeStyle.regular(13)).multilineTextAlignment(.center)
                .padding(.horizontal, 28).padding(.top, 7).padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity)
        .background {
            ZStack(alignment: .bottom) {
                event.theme.color
                TicketScenery(illustration: event.illustration).frame(height: 88)
            }
        }
        .clipShape(TicketShape(), style: FillStyle(eoFill: true))
        .animation(animateDigits ? .easeInOut(duration: 0.25) : nil, value: count)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(event.title), \(count) \(label)")
    }
}

private struct TicketScenery: View {
    let illustration: Illustration
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            if illustration == .sun {
                WaveShape().fill(Color(hex: 0xC7BCE7)).frame(height: 33).offset(y: size.height - 33)
                WaveShape().stroke(.white.opacity(0.8), lineWidth: 3).frame(height: 30).offset(y: size.height - 25)
                Path { p in
                    p.move(to: CGPoint(x: size.width - 42, y: 4))
                    p.addLine(to: CGPoint(x: size.width - 42, y: 47))
                    p.addLine(to: CGPoint(x: size.width - 69, y: 47)); p.closeSubpath()
                }.fill(Palette.cheek.opacity(0.65))
            } else {
                HStack {
                    Mascot(illustration: illustration).frame(width: 50, height: 50).rotationEffect(.degrees(-13))
                    Spacer()
                    Mascot(illustration: illustration).frame(width: 40, height: 40).rotationEffect(.degrees(12))
                }.padding(.horizontal, 12).offset(y: 30).opacity(0.6)
            }
        }.accessibilityHidden(true)
    }
}

private struct WaveShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(); p.move(to: CGPoint(x: 0, y: r.height * 0.4))
        p.addCurve(to: CGPoint(x: r.width, y: r.height * 0.4), control1: CGPoint(x: r.width * 0.35, y: r.height * 1.7), control2: CGPoint(x: r.width * 0.65, y: -r.height))
        p.addLine(to: CGPoint(x: r.width, y: r.height)); p.addLine(to: CGPoint(x: 0, y: r.height)); p.closeSubpath(); return p
    }
}

struct EventRow: View {
    let event: CountEvent
    let engine: DateEngine
    let now: Date
    var prefix = ""
    var body: some View {
        HStack(spacing: 12) {
            Mascot(illustration: event.illustration).frame(width: 54, height: 54)
                .background(event.theme.color, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(prefix + event.title).font(TypeStyle.bold(17)).lineLimit(2)
                Text(engine.formatted(engine.occurrence(of: event, at: now), short: true))
                    .font(TypeStyle.regular(12)).foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 3)
            VStack(spacing: 0) {
                Text(engine.count(for: event, at: now).formatted()).font(TypeStyle.heavy(28)).lineLimit(1).minimumScaleFactor(0.5)
                Text("days").font(TypeStyle.regular(12))
            }.frame(minWidth: 44, maxWidth: 80)
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
        }.padding(15).background(Palette.field.opacity(0.7), in: RoundedRectangle(cornerRadius: 24))
            .accessibilityElement(children: .combine)
    }
}
