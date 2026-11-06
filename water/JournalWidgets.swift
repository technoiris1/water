//
//  JournalWidgets.swift
//  water
//

import SwiftUI
import SwiftData

/// Home widget listing the latest journal entries.
struct JournalRecentWidget: View {
    @Environment(ThemeStore.self) private var theme
    @Query(JournalRecentWidget.descriptor) private var entries: [JournalEntry]

    private static var descriptor: FetchDescriptor<JournalEntry> {
        var descriptor = FetchDescriptor<JournalEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 12
        return descriptor
    }

    var body: some View {
        if entries.isEmpty {
            Text("No entries yet — click to start writing.")
                .font(.callout)
                .foregroundStyle(theme.secondaryText)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(entries) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(entry.title.isEmpty ? "Untitled" : entry.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(theme.text)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(theme.secondaryText)
                        }
                        if !entry.content.isEmpty {
                            Text(entry.content)
                                .font(.caption)
                                .foregroundStyle(theme.secondaryText)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
    }
}

/// Home widget summarising journal activity.
struct JournalStatsWidget: View {
    @Environment(ThemeStore.self) private var theme
    @Query private var entries: [JournalEntry]

    var body: some View {
        // Side by side when there's room, stacked when the widget is narrow.
        ViewThatFits {
            HStack(spacing: 12) { tiles }
            VStack(alignment: .leading, spacing: 8) { tiles }
        }
    }

    @ViewBuilder
    private var tiles: some View {
        StatTile(value: entries.count, label: "Entries")
        StatTile(value: entriesThisWeek, label: "This Week")
        StatTile(value: currentStreak, label: "Day Streak")
    }

    private var entriesThisWeek: Int {
        guard let week = Calendar.current.dateInterval(of: .weekOfYear, for: .now) else { return 0 }
        return entries.filter { week.contains($0.date) }.count
    }

    /// Consecutive days with at least one entry, ending today (or yesterday if nothing is logged yet today).
    private var currentStreak: Int {
        let calendar = Calendar.current
        let days = Set(entries.map { calendar.startOfDay(for: $0.date) })
        var day = calendar.startOfDay(for: .now)
        if !days.contains(day), let yesterday = calendar.date(byAdding: .day, value: -1, to: day) {
            day = yesterday
        }
        var streak = 0
        while days.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }
}

private struct StatTile: View {
    @Environment(ThemeStore.self) private var theme
    let value: Int
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value, format: .number)
                .font(.title.bold())
                .foregroundStyle(theme.text)
            Text(label)
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
        }
        .fixedSize()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
