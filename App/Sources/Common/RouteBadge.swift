import SwiftUI

/// The route's identity, used identically on the map, in the picker and in the arrivals
/// sheet — so the list teaches you how to read the map.
struct RouteBadge: View {
    let number: String
    let kind: TransitKind
    let tint: Color
    var size: Size = .regular
    var isMuted: Bool = false

    enum Size {
        case small, regular, large

        var height: CGFloat {
            switch self {
            case .small: 22
            case .regular: 30
            case .large: 44
            }
        }

        var font: Font {
            switch self {
            case .small: .system(size: 11, weight: .bold, design: .rounded)
            case .regular: .system(size: 14, weight: .bold, design: .rounded)
            case .large: .system(size: 19, weight: .bold, design: .rounded)
            }
        }
    }

    private var label: String { RouteNumber.badge(number) }
    private var fill: Color { isMuted ? Color(.systemGray3) : tint }

    var body: some View {
        Text(label)
            .font(size.font)
            .monospacedDigit()
            .foregroundStyle(fill.contrastingLabel)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, size.height * 0.28)
            .frame(minWidth: size.height * 1.3, minHeight: size.height)
            .background(fill, in: shape)
            .overlay(shape.strokeBorder(.white.opacity(0.35), lineWidth: 0.5))
            .accessibilityLabel(Text(verbatim: "\(label)"))
    }

    /// Bus and trolleybus differ by silhouette, not just by an icon: a capsule versus a
    /// squared-off tag. It reads at marker size where a glyph would not.
    private var shape: AnyInsettableShape {
        switch kind {
        case .bus: AnyInsettableShape(Capsule())
        case .trolleybus: AnyInsettableShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }
}

/// Type-erased `InsettableShape` so `strokeBorder` still works after erasure.
struct AnyInsettableShape: InsettableShape {
    private let makePath: @Sendable (CGRect) -> Path
    private let makeInset: @Sendable (CGFloat) -> AnyInsettableShape

    init<S: InsettableShape>(_ shape: S) {
        makePath = { shape.path(in: $0) }
        makeInset = { AnyInsettableShape(shape.inset(by: $0)) }
    }

    func path(in rect: CGRect) -> Path { makePath(rect) }
    func inset(by amount: CGFloat) -> AnyInsettableShape { makeInset(amount) }
}
