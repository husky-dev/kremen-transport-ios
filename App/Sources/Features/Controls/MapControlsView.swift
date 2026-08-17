import SwiftUI

/// A floating control surface with a consistent look across the app's map chrome.
struct FloatingSurface<Content: View>: View {
    var shape: AnyInsettableShape = AnyInsettableShape(Capsule())
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(.regularMaterial, in: shape)
            .overlay(shape.strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.18), radius: 10, y: 3)
    }
}

/// A round icon button sized for a thumb.
struct MapIconButton: View {
    let systemName: String
    let labelKey: LocalizedStringKey
    var isBusy: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 46, height: 46)
                .contentShape(.rect)
                .symbolEffect(.pulse, isActive: isBusy)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(Text(labelKey))
    }
}

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

/// The zoom pair reads as one control rather than two more buttons, and sits at the trailing
/// edge around thumb height — deliberately apart from the primary actions along the bottom.
struct ZoomStepper: View {
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void

    var body: some View {
        FloatingSurface(shape: AnyInsettableShape(Capsule())) {
            VStack(spacing: 0) {
                MapIconButton(systemName: "plus", labelKey: "map.control.zoomIn", action: onZoomIn)
                Divider().frame(width: 26)
                MapIconButton(systemName: "minus", labelKey: "map.control.zoomOut", action: onZoomOut)
            }
        }
    }
}

/// The primary action is labelled, not an anonymous circle: it tells you what it opens and
/// how many routes you are watching.
struct RoutesPill: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "bus.fill")
                    .font(.system(size: 15, weight: .semibold))
                Text("map.routes.button")
                    .font(.system(size: 16, weight: .semibold))
                Text(count.formatted())
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.accentColor.contrastingLabel)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.accentColor, in: Capsule())
            }
            .padding(.leading, 16)
            .padding(.trailing, 10)
            .frame(height: 46)
            .contentShape(.rect)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

/// A binary liveness indicator: green while data is arriving, red once it stops — so "nothing
/// is moving" is never ambiguous. The exact age of the last poll is detail nobody asked for.
struct ConnectionChip: View {
    let lastUpdate: Date?
    let isFailing: Bool

    /// Positions poll every 5 s; three missed ticks is a stall worth showing.
    private static let staleAfter: TimeInterval = 15

    @State private var now = Date()
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var isOnline: Bool {
        guard !isFailing, let lastUpdate else { return false }
        return now.timeIntervalSince(lastUpdate) <= Self.staleAfter
    }

    var body: some View {
        FloatingSurface(shape: AnyInsettableShape(Capsule())) {
            HStack(spacing: 6) {
                Circle()
                    .fill(isOnline ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                // Both labels are laid out and one is hidden, so the chip keeps a single width
                // in every locale and at every Dynamic Type size instead of jumping on a flip.
                ZStack {
                    Text("map.status.online").hidden()
                    Text("map.status.disconnected").hidden()
                    Text(isOnline ? "map.status.online" : "map.status.disconnected")
                }
                .font(.system(size: 12, weight: .medium))
                .fixedSize()
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 11)
            .frame(height: 28)
        }
        .onReceive(tick) { now = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(isOnline ? "map.status.online" : "map.status.disconnected"))
    }
}
