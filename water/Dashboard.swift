//
//  Dashboard.swift
//  water
//

import Foundation

/// Every kind of widget that can be placed on the Home dashboard.
/// To add a widget for a new module: add a case here, fill in its metadata,
/// and add its view to `WidgetContent` in HomeView.swift.
enum WidgetKind: String, Codable, CaseIterable, Identifiable {
    case journalRecent
    case journalStats
    case academicsUpcoming
    case academicsProgress

    var id: Self { self }

    /// The module this widget previews; clicking the widget opens it.
    var module: AppModule {
        switch self {
        case .journalRecent, .journalStats: .journal
        case .academicsUpcoming, .academicsProgress: .academics
        }
    }

    var title: String {
        switch self {
        case .journalRecent: "Recent Entries"
        case .journalStats: "Journal Stats"
        case .academicsUpcoming: "Upcoming Exams"
        case .academicsProgress: "Syllabus Progress"
        }
    }

    var systemImage: String {
        switch self {
        case .journalRecent: "book.closed"
        case .journalStats: "chart.bar"
        case .academicsUpcoming: "calendar"
        case .academicsProgress: "checklist"
        }
    }

    /// Size in grid cells (columns × rows) when first added.
    var defaultSize: GridSize {
        switch self {
        case .journalRecent: GridSize(width: 4, height: 3)
        case .journalStats: GridSize(width: 4, height: 1)
        case .academicsUpcoming: GridSize(width: 4, height: 2)
        case .academicsProgress: GridSize(width: 4, height: 2)
        }
    }

    var minimumSize: GridSize {
        switch self {
        case .journalRecent: GridSize(width: 2, height: 2)
        case .journalStats: GridSize(width: 3, height: 1)
        case .academicsUpcoming: GridSize(width: 2, height: 2)
        case .academicsProgress: GridSize(width: 2, height: 2)
        }
    }
}

struct GridSize: Hashable {
    var width: Int
    var height: Int
}

/// A widget placed on the dashboard grid. Position and size are in grid units.
struct DashboardWidget: Codable, Identifiable, Hashable {
    var id = UUID()
    var kind: WidgetKind
    var x: Int
    var y: Int
    var width: Int
    var height: Int

    func overlaps(_ other: DashboardWidget) -> Bool {
        x < other.x + other.width && other.x < x + width &&
        y < other.y + other.height && other.y < y + height
    }
}

enum DashboardLayout {
    static let columns = 8

    /// Removes overlaps and floats widgets upward to fill gaps.
    /// The pinned widget (the one being dragged or resized) keeps its spot and everything else moves around it.
    static func resolve(_ widgets: [DashboardWidget], pinning pinnedID: UUID? = nil) -> [DashboardWidget] {
        var placed: [DashboardWidget] = []
        if let pinned = widgets.first(where: { $0.id == pinnedID }) {
            placed.append(pinned)
        }

        let others = widgets
            .filter { $0.id != pinnedID }
            .sorted { ($0.y, $0.x) < ($1.y, $1.x) }

        for var widget in others {
            widget.width = min(widget.width, columns)
            widget.x = min(max(widget.x, 0), columns - widget.width)
            // Gravity: take the highest row where the widget doesn't collide with anything already placed.
            widget.y = 0
            while placed.contains(where: { $0.overlaps(widget) }) {
                widget.y += 1
            }
            placed.append(widget)
        }
        return placed
    }
}

/// Owns the Home layout and persists it locally.
@Observable
final class DashboardStore {
    var widgets: [DashboardWidget] {
        didSet { save() }
    }

    // Bumped when the grid changed from 12 columns to an 8 × N bento grid, so old layouts reset.
    private static let layoutKey = "dashboardLayout.bento"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.layoutKey),
           let saved = try? JSONDecoder().decode([DashboardWidget].self, from: data) {
            widgets = saved
        } else {
            widgets = Self.defaultLayout
        }
    }

    static var defaultLayout: [DashboardWidget] {
        [
            DashboardWidget(kind: .academicsUpcoming, x: 0, y: 0, width: 4, height: 2),
            DashboardWidget(kind: .journalStats, x: 4, y: 0, width: 4, height: 1),
            DashboardWidget(kind: .academicsProgress, x: 4, y: 1, width: 4, height: 2),
            DashboardWidget(kind: .journalRecent, x: 0, y: 2, width: 4, height: 3),
        ]
    }

    /// Widgets not yet on the dashboard (each kind appears at most once).
    var availableKinds: [WidgetKind] {
        WidgetKind.allCases.filter { kind in !widgets.contains { $0.kind == kind } }
    }

    func add(_ kind: WidgetKind) {
        let bottom = widgets.map { $0.y + $0.height }.max() ?? 0
        let size = kind.defaultSize
        let widget = DashboardWidget(kind: kind, x: 0, y: bottom, width: size.width, height: size.height)
        widgets = DashboardLayout.resolve(widgets + [widget])
    }

    func remove(_ widget: DashboardWidget) {
        widgets = DashboardLayout.resolve(widgets.filter { $0.id != widget.id })
    }

    func resetLayout() {
        widgets = Self.defaultLayout
    }

    private func save() {
        if let data = try? JSONEncoder().encode(widgets) {
            UserDefaults.standard.set(data, forKey: Self.layoutKey)
        }
    }
}
