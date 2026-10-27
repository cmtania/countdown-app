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
    @Environment(\.dynamicTypeSize) private var textSize
    let event: CountEvent
    let count: Int
    let label: String
    var glance: CGFloat = 0
    var celebrate = false
    var animateDigits = true

    var body: some View {
        Group {
            if textSize.isAccessibilitySize {
                VStack(spacing: 12) {
                    BrandFace(glance: glance, lift: celebrate ? 1 : 0).frame(width: 130)
                    digits(size: 90).frame(maxWidth: .infinity)
                    Text(label).font(TypeStyle.bold(23)).multilineTextAlignment(.center)
                }.padding(30)
            } else {
                GeometryReader { proxy in
                    let w = proxy.size.width, h = proxy.size.height
                    ZStack {
                        BrandEyes(glance: glance).frame(width: w * 0.43, height: h * 0.20)
                            .position(x: w * 0.5, y: h * 0.16)
                        digits(size: w * 0.405).frame(width: w * 0.65, height: h * 0.37)
                            .position(x: w * 0.5, y: h * 0.435)
                        ForEach([CGFloat(0.165), CGFloat(0.835)], id: \.self) { x in
                            Circle().fill(Palette.cheek).frame(width: w * 0.145, height: w * 0.145)
                                .position(x: w * x, y: h * 0.475)
                        }
                        BrandSmile(lift: celebrate ? 1 : 0).frame(width: w * 0.59, height: h * 0.19)
                            .position(x: w * 0.5, y: h * 0.70)
                        Text(label).font(TypeStyle.heavy(w * 0.069)).lineLimit(2).minimumScaleFactor(0.65)
                            .multilineTextAlignment(.center).frame(width: w * 0.66, height: h * 0.12)
                            .position(x: w * 0.5, y: h * 0.845)
                        if event.kind == .countup {
                            Text("A little more, every day.").font(TypeStyle.regular(w * 0.038))
                                .lineLimit(1).minimumScaleFactor(0.7).frame(width: w * 0.66)
                                .position(x: w * 0.5, y: h * 0.935)
                        }
                    }
                }.aspectRatio(360.0 / 350.0, contentMode: .fit)
            }
        }
        .frame(maxWidth: .infinity)
        .background {
            ZStack {
                event.theme.color
                if !textSize.isAccessibilitySize {
                    Image(event.illustration.sceneryAsset).resizable().scaledToFill().accessibilityHidden(true)
                }
            }
        }
        .clipShape(TicketShape(), style: FillStyle(eoFill: true))
        .animation(animateDigits ? .easeInOut(duration: 0.25) : nil, value: count)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(event.title), \(count) \(label)")
    }

    private func digits(size: CGFloat) -> some View {
        Text(count.formatted()).font(TypeStyle.heavy(size)).monospacedDigit()
            .minimumScaleFactor(0.25).lineLimit(1)
            .contentTransition(animateDigits ? .numericText(value: Double(count)) : .identity)
    }
}

private extension Illustration {
    var sceneryAsset: String {
        switch self {
        case .sun: return "scene-seaside"
        case .flower: return "scene-garden"
        case .gift: return "scene-gift"
        case .sprout: return "scene-sprout"
        case .home: return "scene-home"
        }
    }
}

struct EventRow: View {
    let event: CountEvent
    let engine: DateEngine
    let now: Date
    var prefix = ""
    var body: some View {
        HStack(spacing: 12) {
            Mascot(illustration: event.illustration).padding(7).frame(width: 60, height: 60)
                .background(event.theme.color, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(prefix + event.title).font(TypeStyle.bold(16)).lineLimit(2)
                Text(engine.formatted(engine.occurrence(of: event, at: now)))
                    .font(TypeStyle.regular(12)).foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 3)
            VStack(spacing: 0) {
                Text(engine.count(for: event, at: now).formatted()).font(TypeStyle.heavy(28)).lineLimit(1).minimumScaleFactor(0.5)
                Text("days").font(TypeStyle.regular(12))
            }.frame(minWidth: 44, maxWidth: 80)
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
        }.padding(12).background(Palette.field.opacity(0.7), in: RoundedRectangle(cornerRadius: 26))
            .accessibilityElement(children: .combine)
    }
}
