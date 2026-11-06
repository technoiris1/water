//
//  ContentView.swift
//  water
//
//  Created by Manan on 06/11/26.
//

import SwiftUI
import SwiftData

/// The tools available in the sidebar. Add a case here to add a new module.
enum AppModule: String, CaseIterable, Identifiable {
    case journal
    case academics

    var id: Self { self }

    var title: String {
        switch self {
        case .journal: "Journal"
        case .academics: "Academics"
        }
    }

    var systemImage: String {
        switch self {
        case .journal: "book.closed"
        case .academics: "graduationcap"
        }
    }
}

/// What the sidebar can show: the Home dashboard or one of the modules.
enum SidebarItem: Hashable {
    case home
    case module(AppModule)
}

struct ContentView: View {
    @State private var selection: SidebarItem = .home
    @AppStorage("isSidebarVisible") private var isSidebarVisible = true

    var body: some View {
        // A plain HStack instead of NavigationSplitView: the sidebar is a fixed-width card
        // that slides in and out, so showing/hiding it never disturbs the detail layout.
        HStack(spacing: 0) {
            if isSidebarVisible {
                SidebarView(selection: $selection)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background { ThemedBackground() }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(isSidebarVisible ? "Hide Sidebar" : "Show Sidebar", systemImage: "sidebar.left") {
                    withAnimation(.snappy(duration: 0.25)) { isSidebarVisible.toggle() }
                }
                .keyboardShortcut("s", modifiers: [.command, .control])
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .home:
            NavigationStack {
                HomeView { module in selection = .module(module) }
            }
        case .module(.journal):
            NavigationStack {
                JournalView()
            }
        case .module(.academics):
            AcademicsView()
        }
    }
}

/// The boxy sidebar card: app name, Home, the tools, and Settings.
private struct SidebarView: View {
    @Environment(ThemeStore.self) private var theme
    @Binding var selection: SidebarItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WATER")
                .font(.system(size: 26, weight: .black))
                .tracking(3)
                .foregroundStyle(theme.text)
                .padding(.bottom, 10)

            SidebarRow(title: "Home", systemImage: "square.grid.3x3", isSelected: selection == .home) {
                selection = .home
            }

            SectionLabel(title: "Tools")
                .padding(.top, 14)
                .padding(.bottom, 2)

            ForEach(AppModule.allCases) { module in
                SidebarRow(title: module.title, systemImage: module.systemImage, isSelected: selection == .module(module)) {
                    selection = .module(module)
                }
            }

            Spacer()

            SettingsLink {
                Label("Settings", systemImage: "gearshape")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.boldSecondary)
        }
        .padding(16)
        .frame(width: 210)
        .frame(maxHeight: .infinity, alignment: .top)
        .themedSurface()
        .padding(.leading, 16)
        .padding(.vertical, 16)
        .padding(.trailing, 2)
    }
}

private struct SidebarRow: View {
    @Environment(ThemeStore.self) private var theme
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(.body, weight: .heavy))
                .foregroundStyle(isSelected ? Color.white : theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(isSelected ? theme.accent : (isHovering ? theme.text.opacity(0.08) : .clear))
                .overlay {
                    if isSelected {
                        Rectangle().strokeBorder(theme.text, lineWidth: BoxStyle.borderWidth)
                    }
                }
                .background {
                    if isSelected {
                        HardShadow(offset: 3).fill(theme.text)
                    }
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

#Preview {
    ContentView()
        .environment(ThemeStore())
        .environment(DashboardStore())
        .modelContainer(for: [JournalEntry.self, ExamPlan.self, Subject.self, SyllabusTopic.self], inMemory: true)
        .preferredColorScheme(.light)
        .frame(width: 1200, height: 800)
}
