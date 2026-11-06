//
//  AcademicsView.swift
//  water
//

import SwiftUI
import SwiftData

/// The Academics module: exams → subjects (datesheet + calendar) → syllabus.
struct AcademicsView: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ExamPlanListView(path: $path)
                .navigationDestination(for: ExamPlan.self) { ExamPlanDetailView(plan: $0) }
                .navigationDestination(for: Subject.self) { SubjectDetailView(subject: $0) }
        }
    }
}

/// Tomorrow at 10:00, a sensible starting point for a new exam date.
private func suggestedExamDate() -> Date {
    let calendar = Calendar.current
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now)) ?? .now
    return calendar.date(bySettingHour: 10, minute: 0, second: 0, of: tomorrow) ?? tomorrow
}

// MARK: - Exam list

private struct ExamPlanListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExamPlan.createdAt) private var plans: [ExamPlan]
    @Binding var path: NavigationPath

    @State private var isNaming = false
    @State private var newName = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(title: "Academics", subtitle: "Exams, subjects, datesheets and syllabi.")

                if plans.isEmpty {
                    EmptyCard(
                        systemImage: "graduationcap",
                        title: "No exams yet",
                        message: "Create one for something you're preparing for, like 12th Boards."
                    ) {
                        Button("New Exam") { isNaming = true }
                            .buttonStyle(.bold)
                    }
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 24)], alignment: .leading, spacing: 24) {
                        ForEach(plans) { plan in
                            NavigationLink(value: plan) {
                                ExamPlanCard(plan: plan)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Delete Exam", systemImage: "trash", role: .destructive) {
                                    modelContext.delete(plan)
                                }
                            }
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Academics")
        .toolbar {
            ToolbarItem {
                Button("New Exam", systemImage: "plus") { isNaming = true }
            }
        }
        .alert("New Exam", isPresented: $isNaming) {
            TextField("e.g. 12th Boards", text: $newName)
            Button("Create", action: createPlan)
            Button("Cancel", role: .cancel) { newName = "" }
        } message: {
            Text("Give it a name. You'll add subjects and dates next.")
        }
    }

    private func createPlan() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        newName = ""
        guard !name.isEmpty else { return }
        let plan = ExamPlan(name: name)
        modelContext.insert(plan)
        path.append(plan)
    }
}

private struct ExamPlanCard: View {
    @Environment(ThemeStore.self) private var theme
    let plan: ExamPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(plan.name)
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(theme.text)
                    .lineLimit(2)
                Text(plan.subjects.count == 1 ? "1 subject" : "\(plan.subjects.count) subjects")
                    .font(.headline)
                    .foregroundStyle(theme.secondaryText)
            }

            if let next = plan.nextExam {
                VStack(alignment: .leading, spacing: 0) {
                    Text(next.countdownText.uppercased())
                        .font(.system(.title2, weight: .black))
                        .foregroundStyle(next.color)
                    Text("Next: \(next.name)")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(theme.text)
                }
            } else {
                Text("No upcoming exams")
                    .font(.headline)
                    .foregroundStyle(theme.secondaryText)
            }

            VStack(alignment: .leading, spacing: 4) {
                BoxProgressBar(value: plan.progress)
                Text("\(Int((plan.progress * 100).rounded()))% of syllabus done")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedSurface()
        .contentShape(.rect)
    }
}

// MARK: - Exam detail

private struct ExamPlanDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeStore.self) private var theme
    @Bindable var plan: ExamPlan

    @State private var displayedMonth: Date
    @State private var isAddingSubject = false
    @State private var isConfirmingDelete = false
    @State private var isRenaming = false
    @State private var newName = ""
    @State private var contentWidth: CGFloat = 0

    init(plan: ExamPlan) {
        self.plan = plan
        // Open the calendar on the month of the next exam.
        _displayedMonth = State(initialValue: plan.nextExam?.examDate ?? .now)
    }

    var body: some View {
        let isWide = contentWidth > 820
        let layout = isWide
            ? AnyLayout(HStackLayout(alignment: .top, spacing: 24))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 24))

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                layout {
                    calendarCard
                        .frame(maxWidth: isWide ? 420 : 560)
                    datesheetCard
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { contentWidth = $0 }
        }
        .navigationTitle(plan.name)
        .toolbar {
            ToolbarItemGroup {
                Button("Add Subject", systemImage: "plus") { isAddingSubject = true }
                Button("Delete Exam", systemImage: "trash") { isConfirmingDelete = true }
            }
        }
        .sheet(isPresented: $isAddingSubject) {
            SubjectFormSheet(plan: plan)
        }
        .confirmationDialog("Delete \(plan.name)?", isPresented: $isConfirmingDelete) {
            Button("Delete", role: .destructive) {
                modelContext.delete(plan)
                dismiss()
            }
        } message: {
            Text("All its subjects, dates and syllabi will be deleted too.")
        }
        .alert("Rename Exam", isPresented: $isRenaming) {
            TextField("Exam name", text: $newName)
            Button("Save") {
                let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { plan.name = trimmed }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Shown as text (renamed via the pencil) so opening the page doesn't focus and select the name.
            HStack(spacing: 12) {
                Text(plan.name)
                    .font(.system(size: 40, weight: .black))
                    .foregroundStyle(theme.text)
                Button {
                    newName = plan.name
                    isRenaming = true
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.boldSecondary)
                .help("Rename Exam")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .themedSurface()

            if let next = plan.nextExam {
                NavigationLink(value: next) {
                    HStack(spacing: 14) {
                        Rectangle()
                            .fill(next.color)
                            .frame(width: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            SectionLabel(title: "Next up")
                            Text(next.name)
                                .font(.system(.title2, weight: .black))
                                .foregroundStyle(theme.text)
                            if let date = next.examDate {
                                Text(date.formatted(date: .complete, time: .shortened))
                                    .font(.subheadline)
                                    .foregroundStyle(theme.secondaryText)
                            }
                        }
                        .padding(.vertical, 12)
                        Spacer()
                        Text(next.countdownText.uppercased())
                            .font(.system(size: 28, weight: .black))
                            .foregroundStyle(next.color)
                            .padding(.trailing, 16)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .themedSurface()
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(title: "Calendar", systemImage: "calendar")
            ExamCalendarView(subjects: plan.subjects, month: $displayedMonth)
        }
        .padding(18)
        .themedSurface()
    }

    private var datesheetCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel(title: "Datesheet", systemImage: "list.bullet.rectangle")
                Spacer()
                Button("Add Subject", systemImage: "plus") { isAddingSubject = true }
                    .buttonStyle(.bold)
            }

            if plan.subjects.isEmpty {
                Text("Add your subjects and their exam dates to build your datesheet.")
                    .foregroundStyle(theme.secondaryText)
                    .padding(.vertical, 8)
            } else {
                ForEach(plan.datesheet) { subject in
                    NavigationLink(value: subject) {
                        DatesheetRow(subject: subject)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Delete Subject", systemImage: "trash", role: .destructive) {
                            modelContext.delete(subject)
                        }
                    }
                }
            }
        }
        .padding(18)
        .themedSurface()
    }
}

private struct DatesheetRow: View {
    @Environment(ThemeStore.self) private var theme
    let subject: Subject

    var body: some View {
        let isPast = (subject.daysUntilExam() ?? 0) < 0

        HStack(spacing: 12) {
            Rectangle()
                .fill(subject.color)
                .frame(width: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(subject.name)
                    .font(.system(.headline, weight: .heavy))
                    .foregroundStyle(theme.text)
                Text(subject.examDate?.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year().hour().minute()) ?? "No exam date yet")
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
                if !subject.topics.isEmpty {
                    HStack(spacing: 8) {
                        BoxProgressBar(value: subject.progress, color: subject.color, height: 8)
                            .frame(maxWidth: 160)
                        Text("\(subject.completedTopicCount)/\(subject.topics.count) topics")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(theme.secondaryText)
                    }
                }
            }
            .padding(.vertical, 10)

            Spacer(minLength: 8)

            Text(subject.countdownText.uppercased())
                .font(.system(.headline, weight: .black))
                .foregroundStyle(isPast ? theme.secondaryText : subject.color)
            Image(systemName: "chevron.right")
                .font(.headline.weight(.black))
                .foregroundStyle(theme.text)
                .padding(.trailing, 12)
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(theme.surface)
        .overlay { Rectangle().strokeBorder(theme.text, lineWidth: BoxStyle.borderWidth) }
        .opacity(isPast ? 0.6 : 1)
        .contentShape(.rect)
    }
}

// MARK: - Calendar

/// A month grid highlighting exam days in each subject's colour. Clicking an exam day opens that subject.
private struct ExamCalendarView: View {
    @Environment(ThemeStore.self) private var theme
    let subjects: [Subject]
    @Binding var month: Date

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Button { shiftMonth(by: -1) } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(.boldSecondary)
                    .help("Previous Month")
                Spacer()
                Text(month.formatted(.dateTime.month(.wide).year()))
                    .font(.system(.title3, weight: .black))
                    .textCase(.uppercase)
                    .foregroundStyle(theme.text)
                Spacer()
                Button("Today") { month = .now }
                    .buttonStyle(.boldSecondary)
                Button { shiftMonth(by: 1) } label: { Image(systemName: "chevron.right") }
                    .buttonStyle(.boldSecondary)
                    .help("Next Month")
            }

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption.weight(.black))
                        .textCase(.uppercase)
                        .foregroundStyle(theme.secondaryText)
                }

                let exams = examsByDay
                ForEach(Array(monthCells.enumerated()), id: \.offset) { _, day in
                    if let day {
                        CalendarDayCell(date: day, exams: exams[day] ?? [])
                    } else {
                        Color.clear.aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
    }

    private var examsByDay: [Date: [Subject]] {
        var result: [Date: [Subject]] = [:]
        for subject in subjects {
            guard let date = subject.examDate else { continue }
            result[calendar.startOfDay(for: date), default: []].append(subject)
        }
        return result.mapValues { $0.sorted(by: Subject.datesheetOrder) }
    }

    /// Weekday initials starting from the user's first weekday.
    private var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    /// Leading blanks so the 1st lands under the right weekday, followed by each day of the month.
    private var monthCells: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let dayCount = calendar.range(of: .day, in: .month, for: month)?.count else { return [] }
        let leadingBlanks = (calendar.component(.weekday, from: interval.start) - calendar.firstWeekday + 7) % 7
        let days = (0..<dayCount).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
        return Array(repeating: nil, count: leadingBlanks) + days
    }

    private func shiftMonth(by value: Int) {
        if let shifted = calendar.date(byAdding: .month, value: value, to: month) {
            month = shifted
        }
    }
}

private struct CalendarDayCell: View {
    @Environment(ThemeStore.self) private var theme
    let date: Date
    let exams: [Subject]

    var body: some View {
        if let first = exams.first {
            NavigationLink(value: first) { cell }
                .buttonStyle(.plain)
                .help(exams.map(\.name).formatted(.list(type: .and)))
        } else {
            cell
        }
    }

    private var cell: some View {
        let isToday = Calendar.current.isDateInToday(date)
        let hasExam = !exams.isEmpty

        return VStack(alignment: .leading, spacing: 0) {
            Text(date.formatted(.dateTime.day()))
                .font(.system(.callout, weight: .heavy))
            Spacer(minLength: 0)
            if let first = exams.first {
                Text(first.name)
                    .font(.system(size: 9, weight: .black))
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if exams.count > 1 {
                    Text("+\(exams.count - 1) more")
                        .font(.system(size: 8, weight: .heavy))
                }
            }
        }
        .padding(4)
        .foregroundStyle(hasExam ? Color.white : theme.text)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .aspectRatio(1, contentMode: .fit)
        .background(exams.first?.color ?? theme.surface.opacity(0.5))
        .overlay {
            Rectangle().strokeBorder(
                isToday ? theme.accent : theme.text.opacity(hasExam ? 1 : 0.15),
                lineWidth: isToday ? 3 : (hasExam ? BoxStyle.borderWidth : 1)
            )
        }
        .contentShape(.rect)
    }
}

// MARK: - Adding a subject

private struct SubjectFormSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeStore.self) private var theme
    let plan: ExamPlan

    @State private var name = ""
    @State private var hasExamDate = true
    @State private var examDate = suggestedExamDate()

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Subject")
                .font(.system(size: 26, weight: .black))
                .foregroundStyle(theme.text)

            BoxTextField(placeholder: "Subject name, e.g. Physics", text: $name)

            Toggle("Has an exam date", isOn: $hasExamDate)
            if hasExamDate {
                DatePicker("Exam date & time", selection: $examDate)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.boldSecondary)
                    .keyboardShortcut(.cancelAction)
                Button("Add Subject", action: add)
                    .buttonStyle(.bold)
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmedName.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 420)
        .background(theme.background)
    }

    private func add() {
        // Pick the next unused colour so subjects stay distinguishable even after deletions.
        let colorIndex = (plan.subjects.map(\.colorIndex).max() ?? -1) + 1
        let subject = Subject(name: trimmedName, examDate: hasExamDate ? examDate : nil, colorIndex: colorIndex)
        modelContext.insert(subject)
        plan.subjects.append(subject)
        dismiss()
    }
}

// MARK: - Subject detail & syllabus

private struct SubjectDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeStore.self) private var theme
    @Bindable var subject: Subject

    @State private var newTopic = ""
    @State private var isPastingTopics = false
    @State private var isConfirmingDelete = false
    @State private var isRenaming = false
    @State private var newName = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                syllabusCard
                notesCard
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(subject.name)
        .toolbar {
            ToolbarItem {
                Button("Delete Subject", systemImage: "trash") { isConfirmingDelete = true }
            }
        }
        .confirmationDialog("Delete \(subject.name)?", isPresented: $isConfirmingDelete) {
            Button("Delete", role: .destructive) {
                modelContext.delete(subject)
                dismiss()
            }
        } message: {
            Text("Its syllabus and notes will be deleted too.")
        }
        .sheet(isPresented: $isPastingTopics) {
            PasteTopicsSheet(onAdd: addTopics)
        }
        .alert("Rename Subject", isPresented: $isRenaming) {
            TextField("Subject name", text: $newName)
            Button("Save") {
                let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { subject.name = trimmed }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Rectangle()
                .fill(subject.color)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 10) {
                if let planName = subject.plan?.name {
                    SectionLabel(title: planName, systemImage: "graduationcap")
                }
                HStack(spacing: 12) {
                    Text(subject.name)
                        .font(.system(size: 40, weight: .black))
                        .foregroundStyle(theme.text)
                    Button {
                        newName = subject.name
                        isRenaming = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.boldSecondary)
                    .help("Rename Subject")
                }

                HStack(spacing: 12) {
                    Toggle("Exam date", isOn: hasExamDate)
                    if subject.examDate != nil {
                        DatePicker("Exam date", selection: examDate)
                            .labelsHidden()
                    }
                    Spacer()
                    Text(subject.countdownText.uppercased())
                        .font(.system(.title2, weight: .black))
                        .foregroundStyle(subject.color)
                }
            }
            .padding(.vertical, 14)
            .padding(.trailing, 16)
        }
        .fixedSize(horizontal: false, vertical: true)
        .themedSurface()
    }

    private var syllabusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionLabel(title: "Syllabus", systemImage: "checklist")
                Spacer()
                Text("\(subject.completedTopicCount) / \(subject.topics.count) done")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(theme.text)
            }
            BoxProgressBar(value: subject.progress, color: subject.color, height: 14)

            HStack(spacing: 10) {
                BoxTextField(placeholder: "Add a topic or chapter, then press Return", text: $newTopic, onSubmit: addTopic)
                Button("Add", action: addTopic)
                    .buttonStyle(.bold)
                    .disabled(newTopic.trimmingCharacters(in: .whitespaces).isEmpty)
                Button("Paste List…") { isPastingTopics = true }
                    .buttonStyle(.boldSecondary)
            }

            if subject.topics.isEmpty {
                Text("No topics yet. Add chapters one at a time, or paste your whole syllabus as a list.")
                    .foregroundStyle(theme.secondaryText)
            } else {
                VStack(spacing: 0) {
                    let topics = subject.sortedTopics
                    ForEach(topics) { topic in
                        TopicRow(
                            topic: topic,
                            color: subject.color,
                            canMoveUp: topic != topics.first,
                            canMoveDown: topic != topics.last,
                            onMove: { move(topic, by: $0) },
                            onDelete: { modelContext.delete(topic) }
                        )
                    }
                }
            }
        }
        .padding(18)
        .themedSurface()
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "Notes", systemImage: "note.text")
            TextEditor(text: $subject.notes)
                .font(.body)
                .foregroundStyle(theme.text)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 140)
        }
        .padding(18)
        .themedSurface()
    }

    private var hasExamDate: Binding<Bool> {
        Binding(
            get: { subject.examDate != nil },
            set: { subject.examDate = $0 ? (subject.examDate ?? suggestedExamDate()) : nil }
        )
    }

    private var examDate: Binding<Date> {
        Binding(
            get: { subject.examDate ?? suggestedExamDate() },
            set: { subject.examDate = $0 }
        )
    }

    private func addTopic() {
        addTopics([newTopic])
        newTopic = ""
    }

    private func addTopics(_ titles: [String]) {
        var order = (subject.topics.map(\.order).max() ?? -1) + 1
        for title in titles {
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let topic = SyllabusTopic(title: trimmed, order: order)
            modelContext.insert(topic)
            subject.topics.append(topic)
            order += 1
        }
    }

    /// Moves a topic up (-1) or down (+1) and renumbers the list.
    private func move(_ topic: SyllabusTopic, by offset: Int) {
        var topics = subject.sortedTopics
        guard let index = topics.firstIndex(of: topic), topics.indices.contains(index + offset) else { return }
        topics.swapAt(index, index + offset)
        for (order, topic) in topics.enumerated() {
            topic.order = order
        }
    }
}

private struct TopicRow: View {
    @Environment(ThemeStore.self) private var theme
    @Bindable var topic: SyllabusTopic
    let color: Color
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMove: (Int) -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button {
                topic.isDone.toggle()
            } label: {
                Rectangle()
                    .fill(topic.isDone ? color : theme.surface)
                    .frame(width: 22, height: 22)
                    .overlay { Rectangle().strokeBorder(theme.text, lineWidth: BoxStyle.borderWidth) }
                    .overlay {
                        if topic.isDone {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .black))
                                .foregroundStyle(.white)
                        }
                    }
            }
            .buttonStyle(.plain)
            .help(topic.isDone ? "Mark as not done" : "Mark as done")

            TextField("Topic", text: $topic.title)
                .textFieldStyle(.plain)
                .font(.body.weight(.semibold))
                .strikethrough(topic.isDone)
                .foregroundStyle(topic.isDone ? theme.secondaryText : theme.text)

            Menu {
                actions
            } label: {
                Image(systemName: "ellipsis")
                    .font(.headline.weight(.black))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.text.opacity(0.15))
                .frame(height: 1)
        }
        .contextMenu { actions }
    }

    @ViewBuilder
    private var actions: some View {
        Button("Move Up", systemImage: "arrow.up") { onMove(-1) }
            .disabled(!canMoveUp)
        Button("Move Down", systemImage: "arrow.down") { onMove(1) }
            .disabled(!canMoveDown)
        Divider()
        Button("Delete Topic", systemImage: "trash", role: .destructive, action: onDelete)
    }
}

/// Lets the user paste a whole syllabus; each line becomes a topic.
private struct PasteTopicsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeStore.self) private var theme
    let onAdd: ([String]) -> Void

    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Paste Syllabus")
                .font(.system(size: 26, weight: .black))
                .foregroundStyle(theme.text)
            Text("One topic per line. Bullets and numbering are removed automatically.")
                .foregroundStyle(theme.secondaryText)

            TextEditor(text: $text)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(theme.surface)
                .overlay { Rectangle().strokeBorder(theme.text, lineWidth: BoxStyle.borderWidth) }
                .frame(height: 260)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.boldSecondary)
                    .keyboardShortcut(.cancelAction)
                Button(lines.count == 1 ? "Add 1 Topic" : "Add \(lines.count) Topics") {
                    onAdd(lines)
                    dismiss()
                }
                .buttonStyle(.bold)
                .disabled(lines.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 480)
        .background(theme.background)
    }

    private var lines: [String] {
        text.split(whereSeparator: \.isNewline)
            .map(Self.cleaned)
            .filter { !$0.isEmpty }
    }

    /// Strips leading bullets ("-", "•", "*") and numbering ("1.", "2)", "a.") from a line.
    private static func cleaned(_ line: Substring) -> String {
        var result = line.trimmingCharacters(in: .whitespaces)
        if let range = result.range(of: #"^([-•*–]|\d+[.)]|[a-zA-Z][.)])\s+"#, options: .regularExpression) {
            result.removeSubrange(range)
        }
        return result.trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Shared pieces

/// A plain text field drawn as a bordered box.
private struct BoxTextField: View {
    @Environment(ThemeStore.self) private var theme
    let placeholder: String
    @Binding var text: String
    var onSubmit: () -> Void = {}

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.body.weight(.medium))
            .foregroundStyle(theme.text)
            .padding(8)
            .background(theme.surface)
            .overlay { Rectangle().strokeBorder(theme.text, lineWidth: BoxStyle.borderWidth) }
            .onSubmit(onSubmit)
    }
}

private struct EmptyCard<Actions: View>: View {
    @Environment(ThemeStore.self) private var theme
    let systemImage: String
    let title: String
    let message: String
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .black))
                .foregroundStyle(theme.accent)
            Text(title)
                .font(.system(.title2, weight: .black))
                .foregroundStyle(theme.text)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.secondaryText)
            actions
                .padding(.top, 4)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .themedSurface()
    }
}

// MARK: - Previews

/// Sample "12th Boards" data for previews.
private func makeSampleBoards() -> (ModelContainer, ExamPlan) {
    guard let container = try? ModelContainer(
        for: ExamPlan.self, Subject.self, SyllabusTopic.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    ) else {
        fatalError("Couldn't create the preview container.")
    }
    let context = container.mainContext
    let plan = ExamPlan(name: "12th Boards")
    context.insert(plan)

    let calendar = Calendar.current
    let names = ["English", "Physics", "Chemistry", "Mathematics", "Computer Science"]
    for (index, name) in names.enumerated() {
        let date = calendar.date(byAdding: .day, value: 10 + index * 4, to: suggestedExamDate())
        let subject = Subject(name: name, examDate: date, colorIndex: index)
        context.insert(subject)
        plan.subjects.append(subject)
        for chapter in 0..<6 {
            let topic = SyllabusTopic(title: "Chapter \(chapter + 1)", order: chapter)
            topic.isDone = chapter < index + 1
            context.insert(topic)
            subject.topics.append(topic)
        }
    }
    return (container, plan)
}

#Preview("Exam Detail") {
    let (container, plan) = makeSampleBoards()
    NavigationStack {
        ExamPlanDetailView(plan: plan)
    }
    .background { ThemedBackground() }
    .environment(ThemeStore())
    .modelContainer(container)
    .preferredColorScheme(.light)
    .frame(width: 1100, height: 800)
}

#Preview("Subject Syllabus") {
    let (container, plan) = makeSampleBoards()
    NavigationStack {
        if let subject = plan.datesheet.first {
            SubjectDetailView(subject: subject)
        }
    }
    .background { ThemedBackground() }
    .environment(ThemeStore())
    .modelContainer(container)
    .preferredColorScheme(.light)
    .frame(width: 900, height: 800)
}
