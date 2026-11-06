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

struct ContentView: View {
    @State private var selectedModule: AppModule? = .journal

    var body: some View {
        NavigationSplitView {
            List(AppModule.allCases, selection: $selectedModule) { module in
                Label(module.title, systemImage: module.systemImage)
                    .tag(module)
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
            switch selectedModule {
            case .journal:
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
        .modelContainer(for: JournalEntry.self, inMemory: true)
        .frame(width: 1000, height: 650)
}
