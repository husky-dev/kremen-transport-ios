import SwiftUI

/// Choosing what to watch. Every tap writes through to storage immediately — there is no
/// Cancel, so nothing is ever lost by swiping the sheet away.
struct RoutePickerView: View {
    let routes: [Route]
    @Bindable var selection: SelectionStore

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var filter: Filter = .all

    private enum Filter: Hashable, CaseIterable {
        case all, bus, trolleybus

        var titleKey: LocalizedStringKey {
            switch self {
            case .all: "routes.filter.all"
            case .bus: "routes.filter.bus"
            case .trolleybus: "routes.filter.trolley"
            }
        }

        var kind: TransitKind? {
            switch self {
            case .all: nil
            case .bus: .bus
            case .trolleybus: .trolleybus
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if !selectedRoutes.isEmpty, query.isEmpty {
                    Section("routes.section.selected") {
                        ForEach(selectedRoutes) { row($0) }
                    }
                }

                ForEach(groups, id: \.kind) { group in
                    Section(LocalizedStringKey(group.kind.sectionTitleKey)) {
                        ForEach(group.routes) { row($0) }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("routes.title")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: Text("routes.search.prompt")
            )
            .overlay {
                if filtered.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                Picker("", selection: $filter) {
                    ForEach(Filter.allCases, id: \.self) { Text($0.titleKey).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.bar)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("routes.selectAll", systemImage: "checklist.checked") {
                            selection.replace(with: Set(routes.map(\.rid)))
                        }
                        Button("routes.clear", systemImage: "xmark.circle", role: .destructive) {
                            selection.clear()
                        }
                        Divider()
                        Toggle("routes.showOffline", isOn: $selection.showOffline)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Rows

    @ViewBuilder
    private func row(_ route: Route) -> some View {
        let isSelected = selection.contains(route.rid)
        Button {
            selection.toggle(route.rid)
        } label: {
            HStack(spacing: 12) {
                RouteBadge(
                    number: route.number,
                    kind: route.type,
                    tint: route.tint,
                    size: .regular,
                    isMuted: route.active == 0
                )
                .frame(width: 52, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text(route.name.trimmed)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text(route.active == 0
                        ? String(localized: "routes.notRunning")
                        : String(format: String(localized: "routes.onRoute"), route.active))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color(.tertiaryLabel))
                    .contentTransition(.symbolEffect(.replace))
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    // MARK: - Data

    private var filtered: [Route] {
        routes.filter { route in
            guard filter.kind == nil || route.type == filter.kind else { return false }
            guard !query.isEmpty else { return true }
            return RouteNumber.matches(route.number, query: query)
                || route.name.localizedCaseInsensitiveContains(query)
        }
    }

    private var selectedRoutes: [Route] {
        filtered.filter { selection.contains($0.rid) }
    }

    private var groups: [(kind: TransitKind, routes: [Route])] {
        TransitKind.allCases.compactMap { kind in
            let members = filtered.filter { $0.type == kind }
            return members.isEmpty ? nil : (kind, members)
        }
    }
}
