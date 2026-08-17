import SwiftUI

/// Stops are intentionally quiet — a ring, not a pin — so live vehicles stay the foreground layer.
struct StopMarker: View {
    let isSelected: Bool

    var body: some View {
        Circle()
            .fill(.background)
            .frame(width: 13, height: 13)
            .overlay(
                Circle()
                    .strokeBorder(isSelected ? Color.accentColor : Color.secondary, lineWidth: 3.5)
            )
            .shadow(color: .black.opacity(0.18), radius: 1.5, y: 1)
            .scaleEffect(isSelected ? 1.55 : 1)
            .animation(.spring(duration: 0.3), value: isSelected)
    }
}
