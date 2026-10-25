import QuicknoteKit
import SwiftUI

/// The note list of every note section; Tasks adds the grouping control (S11).
struct TaskListView: View {
    @Bindable var model: LibraryModel

    var body: some View {
        VStack(spacing: 0) {
            if model.section == .tasks { groupingPicker }
            List(selection: $model.selection) {
                ForEach(groups) { group in
                    Section {
                        ForEach(group.notes) { note in row(for: note) }
                    } header: {
                        if !group.title.isEmpty { Text(group.title) }
                    }
                }
            }
            .onDeleteCommand { model.pendingDeletion = model.selection }
            .overlay { if model.listNotes.isEmpty { ContentUnavailableView("Nothing here", systemImage: "tray") } }
        }
        .navigationTitle(title)
    }

    private var grouper: TaskGrouper { TaskGrouper(now: Date(), calendar: .current, projects: model.projects) }

    private var groups: [TaskGroup] {
        switch model.section {
        case .tasks: grouper.groups(model.listNotes, by: model.grouping)
        case .reminders, .events: grouper.groups(model.listNotes, by: .dueDate)
        default: grouper.flat(model.listNotes)
        }
    }

    private var title: String {
        if case .project(let projectId) = model.section {
            return model.projects.first { $0.id == projectId }?.name ?? "Project"
        }
        return model.section.title
    }

    private var groupingPicker: some View {
        Picker("Group tasks", selection: $model.grouping) {
            ForEach(TaskGrouping.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(8)
    }

    private func row(for note: Note) -> some View {
        let noteId = note.id ?? 0
        return TaskRow(
            note: note, detail: grouper.detail(for: note), isOverdue: grouper.isOverdue(note),
            toggle: { model.toggleCompletion(of: note) }
        )
        .tag(noteId)
        .contextMenu {
            Button("Delete…", role: .destructive) {
                model.pendingDeletion = model.selection.contains(noteId) ? model.selection : [noteId]
            }
        }
    }
}

private struct TaskRow: View {
    let note: Note
    let detail: String
    let isOverdue: Bool
    let toggle: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2).fill(Color(hex: note.color)).frame(width: 4)
            Button(action: toggle) {
                Image(systemName: note.completedAt == nil ? "circle" : "checkmark.circle.fill")
            }
            .buttonStyle(.plain)
            .accessibilityLabel(note.completedAt == nil ? "Complete \(note.title)" : "Reopen \(note.title)")
            VStack(alignment: .leading, spacing: 2) {
                Text(note.title.isEmpty ? "Untitled" : note.title).lineLimit(1)
                Text(detail).font(.caption).foregroundStyle(isOverdue ? Color.red : .secondary).lineLimit(1)
            }
            Spacer()
            MeetingMomentButton(note: note)
        }
        .frame(minHeight: 36)
        .accessibilityElement(children: .contain)
    }
}

/// The mm:ss link on a task that came from a meeting action item.
private struct MeetingMomentButton: View {
    let note: Note

    var body: some View {
        if let meetingId = note.sourceMeetingId, let atMs = note.sourceMs {
            Button(MeetingTime.format(ms: atMs)) { MeetingsFeature.open(meetingId: meetingId, atMs: atMs) }
                .buttonStyle(.link)
                .monospacedDigit()
                .accessibilityLabel("Open meeting at \(MeetingTime.format(ms: atMs))")
        }
    }
}
