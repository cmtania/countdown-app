import SwiftUI

struct PanelAnchorKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

/// Animates the actual control surface into the destination. Content remains
/// full-size and is revealed by a moving mask, so text never stretches.
@MainActor struct ExpandingPanel<Content: View>: View {
    let canvas: CGSize
    let originColor: Color
    let motion: Animation?
    @Binding var closing: Bool
    let onDismiss: () -> Void
    let content: Content
    @State private var origin: CGRect
    @State private var expanded = false
    @State private var showContent = false
    @State private var closeTask: Task<Void, Never>?

    init(origin: CGRect, canvas: CGSize, originColor: Color, motion: Animation?, closing: Binding<Bool>,
         onDismiss: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        _origin = State(initialValue: origin)
        self.canvas = canvas; self.originColor = originColor; self.motion = motion
        _closing = closing; self.onDismiss = onDismiss; self.content = content()
    }

    private var surface: some View {
        RoundedRectangle(cornerRadius: expanded ? 0 : 30, style: .continuous)
            .frame(width: expanded ? canvas.width : origin.width, height: expanded ? canvas.height : origin.height)
            .position(x: expanded ? canvas.width / 2 : origin.midX, y: expanded ? canvas.height / 2 : origin.midY)
    }

    var body: some View {
        ZStack {
            surface.foregroundStyle(expanded ? Palette.paper : originColor)
            content.frame(width: canvas.width, height: canvas.height)
                .opacity(showContent ? 1 : 0)
                .mask { surface.foregroundStyle(.white) }
                .allowsHitTesting(showContent && !closing)
                .accessibilityHidden(!showContent || closing)
        }.frame(width: canvas.width, height: canvas.height)
            .task {
                withAnimation(motion) { expanded = true }
                if motion != nil { try? await Task.sleep(for: .milliseconds(100)) }
                guard !Task.isCancelled, !closing else { return }
                withAnimation(motion == nil ? nil : .easeOut(duration: 0.18)) { showContent = true }
            }
            .onChange(of: closing) { _, value in
                guard value else { return }
                closeTask?.cancel()
                withAnimation(motion == nil ? nil : .easeOut(duration: 0.12)) { showContent = false }
                withAnimation(motion) { expanded = false }
                closeTask = Task { @MainActor in
                    if motion != nil { try? await Task.sleep(for: .milliseconds(380)) }
                    guard !Task.isCancelled else { return }
                    onDismiss()
                }
            }
            .onDisappear { closeTask?.cancel() }
    }
}
