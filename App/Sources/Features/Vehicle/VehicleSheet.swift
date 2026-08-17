import SwiftUI

struct VehicleSheet: View {
    let vehicle: Vehicle
    let route: Route?
    let onShowRoute: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        RouteBadge(
                            number: route?.number ?? "",
                            kind: route?.type ?? vehicle.type,
                            tint: vehicle.offline ? Color(.systemGray) : (route?.tint ?? .accentColor),
                            size: .large
                        )
                        VStack(alignment: .leading, spacing: 3) {
                            Text(route?.name.trimmed ?? "")
                                .font(.headline)
                                .lineLimit(2)
                            Text(vehicle.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    if vehicle.offline {
                        Label("vehicle.offline", systemImage: "wifi.slash")
                            .foregroundStyle(.orange)
                    }
                    if let speed = vehicle.knownSpeed {
                        LabeledContent("vehicle.speed", value: Formatters.speed(kmh: speed))
                    }
                    LabeledContent("vehicle.heading") {
                        Image(systemName: "location.north.fill")
                            .rotationEffect(.degrees(vehicle.direction))
                            .foregroundStyle(.secondary)
                    }
                    if let updatedAt = vehicle.updatedAt {
                        LabeledContent("vehicle.lastSeen") {
                            Text(updatedAt, style: .relative)
                                .monospacedDigit()
                        }
                    }
                }

                if route != nil {
                    Section {
                        Button("vehicle.showRoute", systemImage: "point.topleft.down.to.point.bottomright.curvepath") {
                            onShowRoute()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("vehicle.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.close") { dismiss() }
                }
            }
        }
        .presentationDetents([.height(320), .medium])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
    }
}
