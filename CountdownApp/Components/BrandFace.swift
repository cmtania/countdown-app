import SwiftUI

/// All smiles in the product use this one geometry. The dark line is an inset
/// stroke of the same path, never a second mouth.
struct SmileCurve: Shape {
    var lift: CGFloat = 0
    var animatableData: CGFloat {
        get { lift }
        set { lift = newValue }
    }
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.width * 0.09, y: rect.height * 0.18))
        p.addCurve(to: CGPoint(x: rect.width * 0.91, y: rect.height * 0.18),
                   control1: CGPoint(x: rect.width * 0.29, y: rect.height * (1.02 - lift * 0.1)),
                   control2: CGPoint(x: rect.width * 0.71, y: rect.height * (1.02 - lift * 0.1)))
        return p
    }
}

struct BrandSmile: View {
    var lift: CGFloat = 0
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            SmileCurve(lift: lift).stroke(Palette.gold, style: StrokeStyle(lineWidth: width * 0.085, lineCap: .round))
                .overlay(SmileCurve(lift: lift).stroke(Palette.orange, style: StrokeStyle(lineWidth: width * 0.025, lineCap: .round)))
        }
        .accessibilityHidden(true)
    }
}

struct BrandEyes: View {
    var glance: CGFloat = 0
    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: proxy.size.width * 0.09) {
                ForEach(0..<2) { _ in
                    GeometryReader { eye in
                        Ellipse().fill(.white)
                        Circle().fill(Palette.ink)
                            .frame(width: eye.size.width * 0.44, height: eye.size.width * 0.44)
                            .offset(x: eye.size.width * (0.47 + min(1, max(-1, glance)) * 0.09), y: eye.size.height * 0.28)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}

struct BrandFace: View {
    var glance: CGFloat = 0
    var lift: CGFloat = 0
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width, h = proxy.size.height
            ZStack {
                BrandEyes(glance: glance).frame(width: w * 0.58, height: h * 0.48).position(x: w / 2, y: h * 0.26)
                Circle().fill(Palette.cheek).frame(width: w * 0.19).position(x: w * 0.12, y: h * 0.59)
                Circle().fill(Palette.cheek).frame(width: w * 0.19).position(x: w * 0.88, y: h * 0.59)
                BrandSmile(lift: lift).frame(width: w * 0.61, height: h * 0.42).position(x: w / 2, y: h * 0.77)
            }
        }
        .aspectRatio(1.45, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// Editable vector motifs. Every illustrated character reuses BrandFace.
struct Mascot: View {
    var illustration: Illustration
    var body: some View {
        GeometryReader { proxy in
            let s = min(proxy.size.width, proxy.size.height)
            ZStack {
                switch illustration {
                case .sun:
                    ForEach(0..<10) { i in
                        Capsule().fill(Palette.gold).frame(width: s * 0.055, height: s * 0.15)
                            .offset(y: -s * 0.41).rotationEffect(.degrees(Double(i) * 36))
                    }
                    Circle().fill(Palette.gold.opacity(0.55)).frame(width: s * 0.66)
                case .flower:
                    ForEach(0..<7) { i in
                        Ellipse().fill(Color.white.opacity(0.85)).frame(width: s * 0.32, height: s * 0.47)
                            .offset(y: -s * 0.25).rotationEffect(.degrees(Double(i) * 360 / 7))
                    }
                    Circle().fill(Palette.gold.opacity(0.7)).frame(width: s * 0.5)
                case .gift:
                    RoundedRectangle(cornerRadius: s * 0.1).fill(EventTheme.lilac.color).frame(width: s * 0.8, height: s * 0.68).offset(y: s * 0.09)
                    Rectangle().fill(.white.opacity(0.6)).frame(width: s * 0.12, height: s * 0.7).offset(y: s * 0.08)
                    ForEach([CGFloat(-1), CGFloat(1)], id: \.self) { side in
                        Ellipse().stroke(Palette.cheek, lineWidth: s * 0.045).frame(width: s * 0.3, height: s * 0.17)
                            .rotationEffect(.degrees(Double(side) * -35)).offset(x: side * s * 0.12, y: -s * 0.31)
                    }
                case .sprout:
                    Capsule().fill(Color(hex: 0x839E55)).frame(width: s * 0.05, height: s * 0.65).offset(y: -s * 0.05)
                    ForEach([CGFloat(-1), CGFloat(1)], id: \.self) { side in
                        Ellipse().fill(Color(hex: 0xA6BC76)).frame(width: s * 0.44, height: s * 0.22)
                            .rotationEffect(.degrees(Double(side) * -35)).offset(x: side * s * 0.17, y: -s * 0.3)
                    }
                case .home:
                    RoundedRectangle(cornerRadius: s * 0.05).fill(.white.opacity(0.88)).frame(width: s * 0.68, height: s * 0.55).offset(y: s * 0.12)
                    HouseRoof().stroke(Palette.cheek, style: StrokeStyle(lineWidth: s * 0.1, lineCap: .round, lineJoin: .round))
                        .frame(width: s * 0.83, height: s * 0.35).offset(y: -s * 0.23)
                }
                BrandFace().frame(width: s * 0.65).offset(y: illustration == .sprout ? s * 0.15 : s * 0.05)
            }.frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(1, contentMode: .fit).accessibilityHidden(true)
    }
}

private struct HouseRoof: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(); p.move(to: CGPoint(x: 0, y: r.height)); p.addLine(to: CGPoint(x: r.midX, y: 0)); p.addLine(to: CGPoint(x: r.width, y: r.height)); return p
    }
}
