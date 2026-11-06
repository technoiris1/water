//
//  HomeView.swift
//  water
//

import SwiftUI

/// The Home dashboard: a grid of widget previews that can be rearranged and resized in edit mode.
struct HomeView: View {
    @Environment(DashboardStore.self) private var dashboard
    @Environment(ThemeStore.self) private var theme

    /// Called when a widget is clicked outside of edit mode.
    var onOpen: (AppModule) -> Void

    @State private var isEditing = false
    @State private var interaction: Interaction?
    @State private var canvasWidth: CGFloat = 0

    private static let padding: CGFloat = 24

    /// An in-progress drag or resize of one widget.
    private struct Interaction {
        enum Kind { case move, resize }
        var widgetID: UUID
        var kind: Kind
        var translation: CGSize
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if dashboard.widgets.isEmpty {
                    emptyState
                } else {
                    canvas(metrics: DashboardMetrics(width: canvasWidth))
                }
            }
            .padding(Self.padding)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
            canvasWidth = max(width - Self.padding * 2, 0)
        }
        .navigationTitle("Home")
        .toolbar { toolbarContent }
    }

    // MARK: Header & toolbar

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greeting)
                .font(.largeTitle.bold())
                .foregroundStyle(theme.text)
            Text(isEditing ? "Drag widgets to move them, and drag the corner handle to resize." : Date.now.formatted(date: .complete, time: .omitted))
                .foregroundStyle(theme.secondaryText)
        }
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        default: "Good evening"
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup {
            if isEditing {
                addWidgetMenu
                Button("Reset Layout", systemImage: "arrow.counterclockwise") {
                    withAnimation(.snappy) { dashboard.resetLayout() }
                }
            }
            Button(isEditing ? "Done" : "Edit Layout", systemImage: isEditing ? "checkmark" : "rectangle.3.group") {
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
        ContentUnavailableView {
            Label("Your Home Is Empty", systemImage: "square.grid.2x2")
        } description: {
            Text("Add widgets to preview your tools here.")
        } actions: {
            addWidgetMenu
                .fixedSize()
        }
        .foregroundStyle(theme.secondaryText)
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    // MARK: Canvas

    private func canvas(metrics: DashboardMetrics) -> some View {
        let layout = proposedLayout(for: interaction, metrics: metrics)
        let rows = (layout.map { $0.y + $0.height }.max() ?? 0) + (isEditing ? 3 : 0)

        return ZStack(alignment: .topLeading) {
            if isEditing {
                columnGuides(metrics: metrics)
            }

            // Shows where the widget being dragged/resized will land.
            if let interaction, let target = layout.first(where: { $0.id == interaction.widgetID }) {
                let frame = metrics.frame(for: target)
                RoundedRectangle(cornerRadius: 14)
                    .fill(theme.accent.opacity(0.12))
                    .strokeBorder(theme.accent.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .frame(width: frame.width, height: frame.height)
                    .offset(x: frame.minX, y: frame.minY)
                    .animation(.snappy(duration: 0.2), value: frame)
            }

            ForEach(layout) { widget in
                widgetView(widget, metrics: metrics)
            }
        }
        .frame(width: metrics.width, height: metrics.height(forRows: rows), alignment: .topLeading)
        .coordinateSpace(.named(DashboardMetrics.coordinateSpace))
    }

    private func columnGuides(metrics: DashboardMetrics) -> some View {
        HStack(spacing: metrics.spacing) {
            ForEach(0..<DashboardLayout.columns, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 6)
                    .fill(theme.accent.opacity(0.05))
            }
        }
        .frame(width: metrics.width)
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private func widgetView(_ widget: DashboardWidget, metrics: DashboardMetrics) -> some View {
        let isActive = interaction?.widgetID == widget.id
        let frame = displayFrame(for: widget, metrics: metrics)

        WidgetCard(widget: widget, isEditing: isEditing, isActive: isActive)
            .frame(width: frame.width, height: frame.height)
            .overlay(alignment: .topLeading) {
                if isEditing {
                    Button {
                        withAnimation(.snappy) { dashboard.remove(widget) }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, theme.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .help("Remove Widget")
                    .offset(x: -8, y: -8)
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
            .animation(isActive ? nil : .snappy(duration: 0.25), value: frame)
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
            let minimum = metrics.frame(for: DashboardWidget(kind: widget.kind, x: 0, y: 0, width: widget.kind.minimumSize.width, height: widget.kind.minimumSize.height))
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

/// Converts between grid units and points.
private struct DashboardMetrics {
    static let coordinateSpace = "dashboard"

    let width: CGFloat
    let rowHeight: CGFloat = 64
    let spacing: CGFloat = 16

    var columnWidth: CGFloat {
        max((width - spacing * CGFloat(DashboardLayout.columns - 1)) / CGFloat(DashboardLayout.columns), 0)
    }
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

    func height(forRows rows: Int) -> CGFloat {
        max(CGFloat(rows) * rowStep - spacing, 0)
    }
}

/// A widget's card: title bar plus a read-only preview of its module.
private struct WidgetCard: View {
    @Environment(ThemeStore.self) private var theme
    let widget: DashboardWidget
    let isEditing: Bool
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(widget.kind.title, systemImage: widget.kind.systemImage)
                .font(.headline)
                .foregroundStyle(theme.accent)
                .lineLimit(1)

            WidgetContent(kind: widget.kind)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .allowsHitTesting(false)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipShape(.rect(cornerRadius: 14))
        .themedSurface()
        .overlay {
            if isEditing {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(theme.accent.opacity(isActive ? 0.9 : 0.35), style: StrokeStyle(lineWidth: 2, dash: isActive ? [] : [6, 4]))
            }
        }
        .scaleEffect(isActive ? 1.02 : 1)
        .shadow(color: .black.opacity(isActive ? 0.15 : 0), radius: 16, y: 6)
    }
}

/// Maps each widget kind to its preview view.
private struct WidgetContent: View {
    let kind: WidgetKind

    var body: some View {
        switch kind {
        case .journalRecent: JournalRecentWidget()
        case .journalStats: JournalStatsWidget()
        }
    }
}

private struct ResizeHandle: View {
    @Environment(ThemeStore.self) private var theme

    var body: some View {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
            .font(.caption.bold())
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(theme.accent, in: .circle)
            .padding(6)
            .contentShape(.rect)
            .pointerStyle(.frameResize(position: .bottomTrailing))
            .help("Drag to resize")
    }
}
