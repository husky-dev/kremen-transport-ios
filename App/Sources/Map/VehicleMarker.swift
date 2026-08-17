import SwiftUI

/// A vehicle on the map. The heading fin rotates; the route number does not — the 1.4 app
/// rotated the whole sprite, which left half the numbers upside down.
struct VehicleMarker: View {
    let vehicle: Vehicle
    let route: Route?
    let showsLabel: Bool
    let isSelected: Bool

    private var tint: Color {
        vehicle.offline ? Color(.systemGray) : (route?.tint ?? .accentColor)
    }

    private var kind: TransitKind { route?.type ?? vehicle.type }

    var body: some View {
        ZStack {
            if showsLabel {
                fin
                RouteBadge(
                    number: route?.number ?? "",
                    kind: kind,
                    tint: tint,
                    size: .small
                )
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            } else {
                Circle()
                    .fill(tint)
                    .frame(width: 11, height: 11)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                    .shadow(color: .black.opacity(0.2), radius: 1.5, y: 1)
            }
        }
        .opacity(vehicle.offline ? 0.5 : 1)
        .scaleEffect(isSelected ? 1.25 : 1)
        .animation(.spring(duration: 0.25), value: isSelected)
        .accessibilityLabel(Text(verbatim: RouteNumber.badge(route?.number ?? "")))
    }

    /// A small wedge that orbits the badge, pointing where the vehicle is going.
    private var fin: some View {
        Triangle()
            .fill(tint)
            .frame(width: 11, height: 8)
            .overlay(Triangle().stroke(.white, lineWidth: 1))
            .offset(y: -17)
            .rotationEffect(.degrees(vehicle.direction))
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
