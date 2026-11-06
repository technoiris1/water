//
//  AcademicsModels.swift
//  water
//

import SwiftUI
import SwiftData

/// An exam you're preparing for, e.g. "12th Boards". Holds its subjects and their datesheet.
@Model
final class ExamPlan {
    var name: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \Subject.plan)
    var subjects: [Subject] = []

    init(name: String) {
        self.name = name
        self.createdAt = .now
    }

    /// Subjects in datesheet order: dated exams soonest first, then undated ones by name.
    var datesheet: [Subject] {
        subjects.sorted(by: Subject.datesheetOrder)
    }

    /// The first exam that hasn't happened yet (today counts).
    var nextExam: Subject? {
        let today = Calendar.current.startOfDay(for: .now)
        return datesheet.first { ($0.examDate ?? .distantPast) >= today }
    }

    var topicCount: Int { subjects.reduce(0) { $0 + $1.topics.count } }
    var completedTopicCount: Int { subjects.reduce(0) { $0 + $1.completedTopicCount } }

    var progress: Double {
        topicCount == 0 ? 0 : Double(completedTopicCount) / Double(topicCount)
    }
}

/// A subject within an exam, with its exam date and syllabus.
@Model
final class Subject {
    var name: String
    var examDate: Date?
    var colorIndex: Int
    var notes: String = ""
    var plan: ExamPlan?
    @Relationship(deleteRule: .cascade, inverse: \SyllabusTopic.subject)
    var topics: [SyllabusTopic] = []

    init(name: String, examDate: Date? = nil, colorIndex: Int = 0) {
        self.name = name
        self.examDate = examDate
        self.colorIndex = colorIndex
    }

    /// Bold colours used to tell subjects apart on the calendar and datesheet.
    static let colors = ["#E63946", "#2A9D8F", "#F4A261", "#457B9D", "#8E44AD", "#E9C46A", "#1D3557", "#43AA8B", "#D62828", "#F77F00"]

    var color: Color {
        Color(hex: Self.colors[abs(colorIndex) % Self.colors.count])
    }

    var sortedTopics: [SyllabusTopic] {
        topics.sorted { $0.order < $1.order }
    }

    var completedTopicCount: Int { topics.filter(\.isDone).count }

    var progress: Double {
        topics.isEmpty ? 0 : Double(completedTopicCount) / Double(topics.count)
    }

    /// Whole days from today until the exam; negative once it's passed.
    func daysUntilExam(from now: Date = .now, calendar: Calendar = .current) -> Int? {
        guard let examDate else { return nil }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: examDate)).day
    }

    /// Short, human countdown such as "Today", "Tomorrow" or "In 12 days".
    var countdownText: String {
        guard let days = daysUntilExam() else { return "No date" }
        switch days {
        case ..<0: return "Done"
        case 0: return "Today"
        case 1: return "Tomorrow"
        default: return "In \(days) days"
        }
    }

    static func datesheetOrder(_ lhs: Subject, _ rhs: Subject) -> Bool {
        switch (lhs.examDate, rhs.examDate) {
        case let (left?, right?): left < right
        case (.some, nil): true
        case (nil, .some): false
        case (nil, nil): lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }
}

/// One item in a subject's syllabus checklist.
@Model
final class SyllabusTopic {
    var title: String
    var isDone: Bool
    var order: Int
    var subject: Subject?

    init(title: String, order: Int) {
        self.title = title
        self.isDone = false
        self.order = order
    }
}
