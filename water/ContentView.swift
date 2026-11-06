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

    var id: Self { self }

    var title: String {
        switch self {
        case .journal: "Journal"
        }
    }

    var systemImage: String {
        switch self {
        case .journal: "book.closed"
        }
    }
}

/// What the sidebar can show: the Home dashboard or one of the modules.
enum SidebarItem: Hashable {
    case home
    case module(AppModule)
}

struct ContentView: View {
    @State private var selection: SidebarItem? = .home

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label("Home", systemImage: "square.grid.2x2")
                    .tag(SidebarItem.home)

                Section("Tools") {
                    ForEach(AppModule.allCases) { module in
                        Label(module.title, systemImage: module.systemImage)
                            .tag(SidebarItem.module(module))
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 190)
            .safeAreaInset(edge: .bottom) {
                SettingsLink {
                    Label("Settings", systemImage: "gearshape")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderless)
                .padding(12)
            }
        } detail: {
            switch selection {
            case .home:
                HomeView { module in selection = .module(module) }
            case .module(.journal):
                JournalView()
            case nil:
                ContentUnavailableView("Pick a tool from the sidebar", systemImage: "sidebar.left")
            }
        }
        .background { ThemedBackground() }
    }
}

#Preview {
    ContentView()
        .environment(ThemeStore())
        .environment(DashboardStore())
        .modelContainer(for: JournalEntry.self, inMemory: true)
        .preferredColorScheme(.light)
        .frame(width: 1000, height: 650)
}
