//
//  JournalView.swift
//  water
//

import SwiftUI
import SwiftData

/// The journal module: a filterable list of entries next to an editor.
struct JournalView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeStore.self) private var theme

    @State private var searchText = ""
    @State private var range: DateRangeFilter = .all
    @State private var customStart = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
    @State private var customEnd = Date.now
    @State private var selection: JournalEntry?

    var body: some View {
        HStack(spacing: 16) {
            VStack(spacing: 0) {
                filterBar
                Divider()
                EntryListView(
                    interval: range.interval(customStart: customStart, customEnd: customEnd),
                    searchText: searchText,
                    selection: $selection
                )
            }
            .frame(width: 320)
            .themedSurface()

            Group {
                if let selection {
                    EntryEditorView(entry: selection)
                        .id(selection.persistentModelID)
                } else {
                    ContentUnavailableView {
                        Label("No Entry Selected", systemImage: "book.pages")
                    } description: {
                        Text("Pick an entry, or press ⌘N to write a new one.")
                    } actions: {
                        Button("New Entry", action: addEntry)
                            .buttonStyle(.borderedProminent)
                    }
                    .foregroundStyle(theme.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .themedSurface()
        }
        .padding(16)
        .navigationTitle("Journal")
        .searchable(text: $searchText, prompt: "Search entries")
        .toolbar {
            ToolbarItemGroup {
                Button("New Entry", systemImage: "square.and.pencil", action: addEntry)
                    .keyboardShortcut("n", modifiers: .command)
                if let selection {
                    Button("Delete Entry", systemImage: "trash") { delete(selection) }
                }
            }
        }
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Date Range", selection: $range) {
                ForEach(DateRangeFilter.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.menu)

            if range == .custom {
                DatePicker("From", selection: $customStart, displayedComponents: .date)
                DatePicker("To", selection: $customEnd, displayedComponents: .date)
            }
        }
        .padding(12)
    }

    private func addEntry() {
        let entry = JournalEntry()
        modelContext.insert(entry)
        // Make sure the new entry is visible even if a narrow filter was active.
        searchText = ""
        range = .all
        selection = entry
    }

    private func delete(_ entry: JournalEntry) {
        if selection == entry { selection = nil }
        modelContext.delete(entry)
    }
}

/// The filtered list. Its query is rebuilt whenever the filter inputs change.
private struct EntryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeStore.self) private var theme
    @Query private var entries: [JournalEntry]
    @Binding var selection: JournalEntry?

    init(interval: DateInterval, searchText: String, selection: Binding<JournalEntry?>) {
        let start = interval.start
        let end = interval.end
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        let predicate: Predicate<JournalEntry>
        if query.isEmpty {
            predicate = #Predicate { $0.date >= start && $0.date < end }
        } else {
            predicate = #Predicate {
                $0.date >= start && $0.date < end &&
                ($0.title.localizedStandardContains(query) || $0.content.localizedStandardContains(query))
            }
        }
        _entries = Query(filter: predicate, sort: \.date, order: .reverse)
        _selection = selection
    }

    var body: some View {
        if entries.isEmpty {
            ContentUnavailableView("No Entries", systemImage: "magnifyingglass", description: Text("Nothing matches this search or date range."))
                .foregroundStyle(theme.secondaryText)
                .frame(maxHeight: .infinity)
        } else {
            List(entries, selection: $selection) { entry in
                EntryRow(entry: entry)
                    .tag(entry)
                    .contextMenu {
                        Button("Delete", systemImage: "trash", role: .destructive) { delete(entry) }
                    }
            }
            .scrollContentBackground(.hidden)
            .onDeleteCommand {
                if let selection { delete(selection) }
            }
            .safeAreaInset(edge: .bottom) {
                Text(entries.count == 1 ? "1 entry" : "\(entries.count) entries")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
                    .padding(8)
            }
        }
    }

    private func delete(_ entry: JournalEntry) {
        if selection == entry { selection = nil }
        modelContext.delete(entry)
    }
}

private struct EntryRow: View {
    @Environment(ThemeStore.self) private var theme
    let entry: JournalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(entry.title.isEmpty ? "Untitled" : entry.title)
                .font(.headline)
                .foregroundStyle(theme.text)
                .lineLimit(1)
            Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(theme.accent)
            if !entry.content.isEmpty {
                Text(entry.content)
                    .font(.callout)
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Edits an entry in place; SwiftData autosaves the changes.
private struct EntryEditorView: View {
    @Environment(ThemeStore.self) private var theme
    @Bindable var entry: JournalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Title", text: $entry.title)
                .textFieldStyle(.plain)
                .font(.title.bold())
                .foregroundStyle(theme.text)

            DatePicker("Date", selection: $entry.date)
                .labelsHidden()
                .fixedSize()

            Divider()

            TextEditor(text: $entry.content)
                .font(.body)
                .foregroundStyle(theme.text)
                .scrollContentBackground(.hidden)
                .overlay(alignment: .topLeading) {
                    if entry.content.isEmpty {
                        Text("Write something…")
                            .foregroundStyle(theme.secondaryText)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }
        }
        .padding(20)
    }
}
