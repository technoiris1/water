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
                Rectangle()
                    .fill(theme.text)
                    .frame(height: BoxStyle.borderWidth)
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
                    VStack(spacing: 12) {
                        Image(systemName: "book.pages")
                            .font(.system(size: 40, weight: .black))
                            .foregroundStyle(theme.accent)
                        Text("No entry selected")
                            .font(.system(.title2, weight: .black))
                            .foregroundStyle(theme.text)
                        Text("Pick an entry, or press ⌘N to write a new one.")
                            .foregroundStyle(theme.secondaryText)
                        Button("New Entry", action: addEntry)
                            .buttonStyle(.bold)
                            .padding(.top, 4)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .themedSurface()
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
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
            SectionLabel(title: "Journal", systemImage: "book.closed")
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
        .padding(14)
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
            VStack(spacing: 6) {
                Text("No entries")
                    .font(.system(.title3, weight: .black))
                    .foregroundStyle(theme.text)
                Text("Nothing matches this search or date range.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme.secondaryText)
            }
            .padding()
            .frame(maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(entries) { entry in
                        Button { selection = entry } label: {
                            EntryRow(entry: entry, isSelected: selection == entry)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Delete", systemImage: "trash", role: .destructive) { delete(entry) }
                        }
                    }
                }
                .padding(12)
            }
            // Focusable so the Delete key removes the selected entry.
            .focusable()
            .focusEffectDisabled()
            .onDeleteCommand {
                if let selection { delete(selection) }
            }
            .safeAreaInset(edge: .bottom) {
                Text(entries.count == 1 ? "1 entry" : "\(entries.count) entries")
                    .font(.caption.weight(.heavy))
                    .textCase(.uppercase)
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
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(entry.title.isEmpty ? "Untitled" : entry.title)
                .font(.system(.headline, weight: .heavy))
                .foregroundStyle(isSelected ? Color.white : theme.text)
                .lineLimit(1)
            Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                .font(.caption.weight(.bold))
                .foregroundStyle(isSelected ? Color.white.opacity(0.85) : theme.accent)
            if !entry.content.isEmpty {
                Text(entry.content)
                    .font(.callout)
                    .foregroundStyle(isSelected ? Color.white.opacity(0.85) : theme.secondaryText)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(isSelected ? theme.accent : theme.surface)
        .overlay {
            Rectangle().strokeBorder(theme.text, lineWidth: isSelected ? BoxStyle.borderWidth : 1)
        }
        .contentShape(.rect)
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
                .font(.system(size: 30, weight: .black))
                .foregroundStyle(theme.text)

            DatePicker("Date", selection: $entry.date)
                .labelsHidden()
                .fixedSize()

            Rectangle()
                .fill(theme.text)
                .frame(height: BoxStyle.borderWidth)

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
