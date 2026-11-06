//
//  HomeView.swift
//  water
//

import SwiftUI

/// The Home dashboard: a bento grid of widget previews that can be rearranged and resized in edit mode.
struct HomeView: View {
    @Environment(DashboardStore.self) private var dashboard
    @Environment(ThemeStore.self) private var theme
    @Environment(\.contentLayerWidth) private var layerWidth

    /// Called when a widget is clicked outside of edit mode.
    var onOpen: (AppModule) -> Void

    @State private var isEditing = false
    @State private var interaction: Interaction?

    private static let padding: CGFloat = 24

    /// The grid's width is derived from the whole window layer, always leaving room for the sidebar
    /// whether or not it's showing. So hiding/showing the sidebar just slides the grid as one block,
    /// with every widget keeping its exact position and size.
    private var canvasWidth: CGFloat {
        max(layerWidth - (SidebarMetrics.reservedWidth - SidebarMetrics.margin) - Self.padding * 2, 0)
    }

    /// An in-progress drag or resize of one widget.
    private struct Interaction {
        enum Kind { case move, resize }
        var widgetID: UUID
        var kind: Kind
        var translation: CGSize
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(
                    title: greeting,
                    subtitle: isEditing
                        ? "Drag widgets to move them. Drag the corner handle to resize."
                        : Date.now.formatted(date: .complete, time: .omitted)
                )

                if dashboard.widgets.isEmpty {
                    emptyState
                } else if canvasWidth > 0 {
                    canvas(metrics: DashboardMetrics(width: canvasWidth))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Self.padding)
        }
        .navigationTitle("Home")
        .toolbar { toolbarContent }
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        default: "Good evening"
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup {
            if isEditing {
                addWidgetMenu
                Button("Reset Layout", systemImage: "arrow.counterclockwise") {
                    withAnimation(.snappy) { dashboard.resetLayout() }
                }
            }
            Button(isEditing ? "Done" : "Edit Layout", systemImage: isEditing ? "checkmark" : "square.grid.3x3") {
                withAnimation(.snappy) { isEditing.toggle() }
            }
        }
    }

    private var addWidgetMenu: some View {
        Menu("Add Widget", systemImage: "plus") {
            ForEach(dashboard.availableKinds) { kind in
                Button(kind.title, systemImage: kind.systemImage) {
                    withAnimation(.snappy) { dashboard.add(kind) }
                }
            }
        }
        .disabled(dashboard.availableKinds.isEmpty)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.grid.3x3")
                .font(.system(size: 40, weight: .black))
                .foregroundStyle(theme.accent)
            Text("Your Home is empty")
                .font(.system(.title2, weight: .black))
                .foregroundStyle(theme.text)
            Text("Add widgets to preview your tools here.")
                .foregroundStyle(theme.secondaryText)
            addWidgetMenu
                .fixedSize()
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .themedSurface()
    }

    // MARK: Canvas

    private func canvas(metrics: DashboardMetrics) -> some View {
        let layout = proposedLayout(for: interaction, metrics: metrics)
        let rows = (layout.map { $0.y + $0.height }.max() ?? 0) + (isEditing ? 2 : 0)

        return ZStack(alignment: .topLeading) {
            if isEditing {
                CellGuides(metrics: metrics, rows: rows, color: theme.text)
            }

            // Shows where the widget being dragged/resized will land.
            if let interaction, let target = layout.first(where: { $0.id == interaction.widgetID }) {
                let frame = metrics.frame(for: target)
                Rectangle()
                    .fill(theme.accent.opacity(0.18))
                    .overlay {
                        Rectangle().strokeBorder(theme.accent, style: StrokeStyle(lineWidth: 3, dash: [8, 5]))
                    }
                    .frame(width: frame.width, height: frame.height)
                    .offset(x: frame.minX, y: frame.minY)
                    .animation(.snappy(duration: 0.2), value: target)
            }

            ForEach(layout) { widget in
                widgetView(widget, metrics: metrics)
            }
        }
        .frame(width: metrics.width, height: metrics.height(forRows: rows), alignment: .topLeading)
        .coordinateSpace(.named(DashboardMetrics.coordinateSpace))
    }

    @ViewBuilder
    private func widgetView(_ widget: DashboardWidget, metrics: DashboardMetrics) -> some View {
        let isActive = interaction?.widgetID == widget.id
        let frame = displayFrame(for: widget, metrics: metrics)

        WidgetCard(widget: widget, isEditing: isEditing, isActive: isActive)
            .frame(width: frame.width, height: frame.height)
            .overlay(alignment: .topTrailing) {
                if isEditing {
                    Button {
                        withAnimation(.snappy) { dashboard.remove(widget) }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(theme.text)
                    }
                    .buttonStyle(.plain)
                    .help("Remove Widget")
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if isEditing {
                    ResizeHandle()
                        .gesture(dragGesture(for: widget, kind: .resize, metrics: metrics))
                }
            }
            .contentShape(.rect)
            .gesture(dragGesture(for: widget, kind: .move, metrics: metrics), isEnabled: isEditing)
            .onTapGesture {
                if !isEditing { onOpen(widget.kind.module) }
            }
            .pointerStyle(isEditing ? .grabIdle : nil)
            .offset(x: frame.minX, y: frame.minY)
            .zIndex(isActive ? 1 : 0)
            // The widget under the pointer tracks it directly; everything else animates into place.
            // Keyed on grid position (not points) so window resizing doesn't animate.
            .animation(isActive ? nil : .snappy(duration: 0.25), value: widget)
    }

    /// Where a widget is drawn right now: under the pointer if it's being dragged, otherwise its layout slot.
    private func displayFrame(for widget: DashboardWidget, metrics: DashboardMetrics) -> CGRect {
        let frame = metrics.frame(for: widget)
        guard let interaction, interaction.widgetID == widget.id,
              let original = dashboard.widgets.first(where: { $0.id == widget.id }) else {
            return frame
        }

        let originalFrame = metrics.frame(for: original)
        switch interaction.kind {
        case .move:
            return originalFrame.offsetBy(dx: interaction.translation.width, dy: interaction.translation.height)
        case .resize:
            let minimum = metrics.size(for: widget.kind.minimumSize)
            return CGRect(
                origin: originalFrame.origin,
                size: CGSize(
                    width: max(originalFrame.width + interaction.translation.width, minimum.width),
                    height: max(originalFrame.height + interaction.translation.height, minimum.height)
                )
            )
        }
    }

    // MARK: Gestures

    private func dragGesture(for widget: DashboardWidget, kind: Interaction.Kind, metrics: DashboardMetrics) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named(DashboardMetrics.coordinateSpace))
            .onChanged { value in
                interaction = Interaction(widgetID: widget.id, kind: kind, translation: value.translation)
            }
            .onEnded { value in
                let final = Interaction(widgetID: widget.id, kind: kind, translation: value.translation)
                let layout = DashboardLayout.resolve(proposedLayout(for: final, metrics: metrics))
                withAnimation(.snappy(duration: 0.25)) {
                    dashboard.widgets = layout
                    interaction = nil
                }
            }
    }

    /// The layout the dashboard would have if the current drag/resize ended now.
    private func proposedLayout(for interaction: Interaction?, metrics: DashboardMetrics) -> [DashboardWidget] {
        let widgets = dashboard.widgets
        guard let interaction,
              let index = widgets.firstIndex(where: { $0.id == interaction.widgetID }),
              metrics.columnStep > 0 else {
            return widgets
        }

        var target = widgets[index]
        let frame = metrics.frame(for: target)
        let translation = interaction.translation

        switch interaction.kind {
        case .move:
            let column = Int(((frame.minX + translation.width) / metrics.columnStep).rounded())
            let row = Int(((frame.minY + translation.height) / metrics.rowStep).rounded())
            target.x = min(max(column, 0), DashboardLayout.columns - target.width)
            target.y = max(row, 0)
        case .resize:
            let minimum = target.kind.minimumSize
            let width = Int(((frame.width + translation.width + metrics.spacing) / metrics.columnStep).rounded())
            let height = Int(((frame.height + translation.height + metrics.spacing) / metrics.rowStep).rounded())
            target.width = min(max(width, minimum.width), DashboardLayout.columns - target.x)
            target.height = max(height, minimum.height)
        }

        var updated = widgets
        updated[index] = target
        return DashboardLayout.resolve(updated, pinning: target.id)
    }
}

/// Converts between grid cells and points. Cells are square-ish, so the grid reads as rows × columns.
private struct DashboardMetrics {
    static let coordinateSpace = "dashboard"

    let width: CGFloat
    let spacing: CGFloat = 18

    var columnWidth: CGFloat {
        max((width - spacing * CGFloat(DashboardLayout.columns - 1)) / CGFloat(DashboardLayout.columns), 0)
    }

    /// Rows match the column width (square cells), within limits so very wide or narrow windows stay usable.
    var rowHeight: CGFloat { min(max(columnWidth, 110), 170) }

    var columnStep: CGFloat { columnWidth + spacing }
    var rowStep: CGFloat { rowHeight + spacing }

    func frame(for widget: DashboardWidget) -> CGRect {
        CGRect(
            x: CGFloat(widget.x) * columnStep,
            y: CGFloat(widget.y) * rowStep,
            width: CGFloat(widget.width) * columnStep - spacing,
            height: CGFloat(widget.height) * rowStep - spacing
        )
    }

    func size(for gridSize: GridSize) -> CGSize {
        CGSize(width: CGFloat(gridSize.width) * columnStep - spacing, height: CGFloat(gridSize.height) * rowStep - spacing)
    }

    func height(forRows rows: Int) -> CGFloat {
        max(CGFloat(rows) * rowStep - spacing, 0)
    }
}

/// Edit-mode backdrop showing every cell of the bento grid.
private struct CellGuides: View {
    let metrics: DashboardMetrics
    let rows: Int
    let color: Color

    var body: some View {
        Canvas { context, _ in
            for row in 0..<rows {
                for column in 0..<DashboardLayout.columns {
                    let cell = metrics.frame(for: DashboardWidget(kind: .journalRecent, x: column, y: row, width: 1, height: 1))
                    context.fill(Path(cell), with: .color(color.opacity(0.04)))
                    context.stroke(Path(cell), with: .color(color.opacity(0.25)), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                }
            }
        }
        .frame(width: metrics.width, height: metrics.height(forRows: rows))
        .allowsHitTesting(false)
    }
}

/// A widget's card: heavy title plus a read-only preview of its module.
private struct WidgetCard: View {
    @Environment(ThemeStore.self) private var theme
    @Environment(\.contentLayerWidth) private var layerWidth
    let widget: DashboardWidget
    let isEditing: Bool
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel(title: widget.kind.title, systemImage: widget.kind.systemImage)
                Spacer(minLength: 0)
                if !isEditing {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(theme.text)
                }
            }

            // Explicit zero minimums stop content from growing the card past its grid cell.
            WidgetContent(kind: widget.kind)
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
                .clipped()
                .allowsHitTesting(false)
        }
        .padding(16)
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
        .themedSurface()
        .overlay {
            if isActive {
                // The widget being dragged gets a solid accent outline instead of a shadow.
                Rectangle().strokeBorder(theme.accent, lineWidth: 4)
            } else if isEditing {
                Rectangle()
                    .strokeBorder(theme.accent, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .padding(4)
            }
        }
    }
}

/// Maps each widget kind to its preview view.
private struct WidgetContent: View {
    let kind: WidgetKind

    var body: some View {
        switch kind {
        case .journalRecent: JournalRecentWidget()
        case .journalStats: JournalStatsWidget()
        case .academicsUpcoming: UpcomingExamsWidget()
        case .academicsProgress: SyllabusProgressWidget()
        }
    }
}

private struct ResizeHandle: View {
    @Environment(ThemeStore.self) private var theme
    @Environment(\.contentLayerWidth) private var layerWidth

    var body: some View {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
            .font(.system(size: 11, weight: .black))
            .foregroundStyle(.white)
            .frame(width: 26, height: 26)
            .background(theme.accent)
            .overlay { Rectangle().strokeBorder(theme.text, lineWidth: BoxStyle.borderWidth) }
            .contentShape(.rect)
            .pointerStyle(.frameResize(position: .bottomTrailing))
            .help("Drag to resize")
    }
}
