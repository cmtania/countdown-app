import SwiftUI

enum Palette {
    static let paper = Color(hex: 0xFAF5E9)
    static let ink = Color(hex: 0x30261E)
    static let muted = Color(hex: 0x756A5D)
    static let orange = Color(hex: 0xBF461B)
    static let cheek = Color(hex: 0xFF8B3E)
    static let gold = Color(hex: 0xFFB33E)
    static let line = Color(hex: 0xE8DDCB)
    static let field = Color(hex: 0xF1E8D8)
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255,
                  blue: Double(hex & 255) / 255, opacity: 1)
    }
}

extension EventTheme {
    var color: Color {
        switch self {
        case .apricot: return Color(hex: 0xFFE1C5)
        case .lilac: return Color(hex: 0xE5DDF4)
        case .sage: return Color(hex: 0xDCE4BE)
        case .butter: return Color(hex: 0xF8E6A8)
        case .cream: return Color(hex: 0xF1E8D8)
        }
    }
}

enum TypeStyle {
    static func regular(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("CalendarNunito-Regular", size: size, relativeTo: style)
    }
    static func bold(_ size: CGFloat, relativeTo style: Font.TextStyle = .headline) -> Font {
        .custom("CalendarNunito-Bold", size: size, relativeTo: style)
    }
    static func heavy(_ size: CGFloat, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
        .custom("CalendarNunito-Heavy", size: size, relativeTo: style)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TypeStyle.bold(18)).foregroundStyle(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 17)
            .background(Palette.orange, in: Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct CircleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 20, weight: .medium))
            .frame(width: 46, height: 46)
            .background(Palette.field.opacity(configuration.isPressed ? 1 : 0.7), in: Circle())
            .foregroundStyle(Palette.ink)
    }
}

struct FormFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content.font(TypeStyle.regular(17)).padding(15)
            .background(Palette.field.opacity(0.55), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.line, lineWidth: 1))
    }
}

extension View {
    func formField() -> some View { modifier(FormFieldStyle()) }
}
