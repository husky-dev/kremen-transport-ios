import SwiftUI

/// Arrivals at one stop, split by travel direction.
///
/// The API returns a stop's `sid` for both directions at the same coordinate, so the stop
/// itself carries no usable direction. Each *prediction* does (`reverse`), and that is what
/// splits the two sections — filtering the stop's own `directionForward` the way the web app
/// does would silently drop about half the arrivals.
struct StationSheet: View {
    let stop: Stop
    let routesByID: [Int: Route]
    let selectedRouteIDs: Set<Int>

    @State private var feed: PredictionFeed
    @State private var scope: Scope = .selected
    @State private var now = Date()

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    /// The backend recomputes arrivals every 10 s; polling faster only burns battery.
    private static let pollInterval = Duration.seconds(5)

    private enum Scope: Hashable, CaseIterable {
        case selected, all

        var titleKey: LocalizedStringKey {
            switch self {
            case .selected: "station.filter.selected"
            case .all: "station.filter.all"
            }
        }
    }

    init(stop: Stop, routesByID: [Int: Route], selectedRouteIDs: Set<Int>, api: APIClient) {
        self.stop = stop
        self.routesByID = routesByID
        self.selectedRouteIDs = selectedRouteIDs
        _feed = State(wrappedValue: PredictionFeed(api: api, sid: stop.sid))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(stop.name)
                .navigationBarTitleDisplayMode(.inline)
                .safeAreaInset(edge: .top, spacing: 0) { header }
        }
        .presentationDetents([.height(340), .medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        // A plain list draws no background of its own; without an explicit opaque colour the
        // map shows through and the arrival times become unreadable.
        .presentationBackground(Color(.systemBackground))
        // Keep the map usable underneath — you can pan to the next stop without dismissing.
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        .task {
            // Poll only while the sheet is up; the task dies with the view.
            let poll = Poller.loop(every: Self.pollInterval) { await feed.reload() }
            defer { poll.cancel() }
            await poll.value
        }
        .onReceive(tick) { now = $0 }
    }

    // MARK: - Sections

    @ViewBuilder
    private var content: some View {
        switch feed.state {
        case .loading where feed.predictions.isEmpty:
            ProgressView().controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed:
            ContentUnavailableView(
                "station.error.title",
                systemImage: "exclamationmark.triangle",
                description: Text("error.load.message")
            )
        default:
            if visible.isEmpty {
                ContentUnavailableView(
                    "station.empty.title",
                    systemImage: "clock.badge.questionmark",
                    description: Text("station.empty.message")
                )
            } else {
                List {
                    section(titleKey: "station.direction.forward", items: visible.filter { !$0.reverse })
                    section(titleKey: "station.direction.reverse", items: visible.filter(\.reverse))
                }
                .listStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func section(titleKey: LocalizedStringKey, items: [Prediction]) -> some View {
        if !items.isEmpty {
            Section {
                ForEach(items) { row($0) }
            } header: {
                Text(titleKey)
                    .font(.footnote.weight(.semibold))
                    .textCase(nil)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "dot.radiowaves.up.forward")
                .font(.caption2)
            Text(String(format: String(localized: "station.updated"),
                        Formatters.freshness(since: feed.lastUpdate, now: now)))
                .font(.caption)
                .monospacedDigit()
            Spacer()
            Picker("", selection: $scope) {
                ForEach(Scope.allCases, id: \.self) { Text($0.titleKey).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(width: 170)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal)
        .padding(.bottom, 8)
        .background(.bar)
    }

    @ViewBuilder
    private func row(_ item: Prediction) -> some View {
        let route = routesByID[item.rid]
        HStack(spacing: 12) {
            RouteBadge(
                number: route?.number ?? "",
                kind: route?.type ?? .bus,
                tint: route?.tint ?? .accentColor,
                size: .regular
            )
            .frame(width: 52, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(route?.destination(reverse: item.reverse) ?? "")
                    .font(.subheadline)
                    .lineLimit(1)
                Text(subtitle(for: item))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer(minLength: 8)

            // Counts down locally between the 5 s polls, so it never looks frozen.
            Text(Formatters.eta(seconds: remaining(item)))
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(remaining(item) <= 60 ? Color.accentColor : .primary)
                .contentTransition(.numericText(countsDown: true))
        }
        .padding(.vertical, 2)
    }

    // MARK: - Data

    private var visible: [Prediction] {
        feed.predictions.filter { item in
            guard routesByID[item.rid] != nil else { return false }
            return scope == .all || selectedRouteIDs.contains(item.rid)
        }
    }

    private func remaining(_ item: Prediction) -> Int {
        guard let lastUpdate = feed.lastUpdate else { return item.prediction }
        let elapsed = Int(now.timeIntervalSince(lastUpdate))
        return max(0, item.prediction - elapsed)
    }

    private func subtitle(for item: Prediction) -> String {
        var parts = [Formatters.distance(metres: item.distance)]
        if item.speed > 0 { parts.append(Formatters.speed(kmh: item.speed)) }
        return parts.joined(separator: " · ")
    }
}
