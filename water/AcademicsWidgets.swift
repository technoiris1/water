//
//  AcademicsWidgets.swift
//  water
//

import SwiftUI
import SwiftData

/// Home widget: a big countdown to the next exam plus the rest of the upcoming datesheet.
struct UpcomingExamsWidget: View {
    @Environment(ThemeStore.self) private var theme
    @Query private var subjects: [Subject]

    var body: some View {
        let upcoming = subjects
            .filter { ($0.daysUntilExam() ?? -1) >= 0 }
            .sorted(by: Subject.datesheetOrder)

        if let next = upcoming.first {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(next.countdownText.uppercased())
                        .font(.system(size: 30, weight: .black))
                        .foregroundStyle(next.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text([next.name, next.plan?.name].compactMap { $0 }.joined(separator: " · "))
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                }

                ForEach(upcoming.dropFirst().prefix(8)) { subject in
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(subject.color)
                            .frame(width: 6, height: 16)
                        Text(subject.name)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(theme.text)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text(subject.countdownText)
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(theme.secondaryText)
                    }
                }
            }
        } else {
            Text("No upcoming exams. Add a datesheet in Academics.")
                .font(.callout)
                .foregroundStyle(theme.secondaryText)
        }
    }
}

/// Home widget: how much of each subject's syllabus is done.
struct SyllabusProgressWidget: View {
    @Environment(ThemeStore.self) private var theme
    @Query private var subjects: [Subject]

    var body: some View {
        let tracked = subjects
            .filter { !$0.topics.isEmpty }
            .sorted(by: Subject.datesheetOrder)
        let total = tracked.reduce(0) { $0 + $1.topics.count }
        let done = tracked.reduce(0) { $0 + $1.completedTopicCount }

        if tracked.isEmpty {
            Text("Add syllabus topics to your subjects to track progress here.")
                .font(.callout)
                .foregroundStyle(theme.secondaryText)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(Int((Double(done) / Double(max(total, 1)) * 100).rounded()))%")
                        .font(.system(size: 30, weight: .black))
                        .foregroundStyle(theme.text)
                    Text("of syllabus done")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(theme.secondaryText)
                }

                ForEach(tracked) { subject in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(subject.name)
                                .font(.subheadline.weight(.heavy))
                                .foregroundStyle(theme.text)
                                .lineLimit(1)
                            Spacer()
                            Text("\(Int((subject.progress * 100).rounded()))%")
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(theme.secondaryText)
                        }
                        BoxProgressBar(value: subject.progress, color: subject.color, height: 8)
                    }
                }
            }
        }
    }
}
