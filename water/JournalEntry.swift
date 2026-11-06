//
//  JournalEntry.swift
//  water
//

import Foundation
import SwiftData

/// A single journal log, persisted locally with SwiftData.
@Model
final class JournalEntry {
    var title: String
    var content: String
    /// The date the log is "about" — editable, and used for date-range filtering.
    var date: Date
    var createdAt: Date

    init(title: String = "", content: String = "", date: Date = .now) {
        self.title = title
        self.content = content
        self.date = date
        self.createdAt = .now
    }
}

/// Preset and custom date ranges used to filter the journal.
enum DateRangeFilter: String, CaseIterable, Identifiable {
    case all = "All Time"
    case today = "Today"
    case week = "Past 7 Days"
    case month = "Past 30 Days"
    case year = "Past Year"
    case custom = "Custom Range"

    var id: Self { self }

    /// The half-open interval `[start, end)` entries must fall in.
    func interval(customStart: Date, customEnd: Date, now: Date = .now, calendar: Calendar = .current) -> DateInterval {
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now

        func daysBack(_ days: Int) -> DateInterval {
            let start = calendar.date(byAdding: .day, value: -days, to: startOfToday) ?? startOfToday
            return DateInterval(start: start, end: startOfTomorrow)
        }

        switch self {
        case .all:
            return DateInterval(start: .distantPast, end: .distantFuture)
        case .today:
            return DateInterval(start: startOfToday, end: startOfTomorrow)
        case .week:
            return daysBack(6)
        case .month:
            return daysBack(29)
        case .year:
            return daysBack(364)
        case .custom:
            // Include the whole of both end days, whichever order they were picked in.
            let lower = calendar.startOfDay(for: min(customStart, customEnd))
            let upperDay = calendar.startOfDay(for: max(customStart, customEnd))
            let upper = calendar.date(byAdding: .day, value: 1, to: upperDay) ?? upperDay
            return DateInterval(start: lower, end: upper)
        }
    }
}
