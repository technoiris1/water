//
//  waterApp.swift
//  water
//
//  Created by Manan on 06/11/26.
//

import SwiftUI
import SwiftData

@main
struct waterApp: App {
    @State private var theme = ThemeStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(theme)
                .tint(theme.accent)
                .preferredColorScheme(.light)
                .frame(minWidth: 820, minHeight: 520)
        }
        .modelContainer(for: JournalEntry.self)
        .commands {
            // ⌘N creates a journal entry instead of opening another window.
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            SettingsView()
                .environment(theme)
                .tint(theme.accent)
                .preferredColorScheme(.light)
        }
    }
}
