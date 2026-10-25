import QuicknoteKit
import SwiftUI

/// Due date (date, optional time) with a Clear button.
struct DuePopover: View {
    let model: NoteEditorModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DatePicker("Date", selection: dueDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .accessibilityLabel("Due date")
            Toggle("Add time", isOn: hasTime)
                .accessibilityLabel("Add a time")
            if model.note?.dueHasTime == true {
                DatePicker("Time", selection: dueDate, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .accessibilityLabel("Due time")
            }
            Button("Clear") {
                model.update {
                    $0.dueAt = nil; $0.dueHasTime = false
                }
            }
            .disabled(model.note?.dueAt == nil)
            .accessibilityLabel("Clear due date")
        }
        .padding(14)
        .frame(width: 260)
    }

    private var dueDate: Binding<Date> {
        Binding(
            get: { model.note?.dueAt ?? Date() },
            set: { date in model.update { $0.dueAt = date } })
    }

    private var hasTime: Binding<Bool> {
        Binding(
            get: { model.note?.dueHasTime ?? false },
            set: { value in
                model.update { note in
                    let day = note.dueAt ?? Date()
                    note.dueHasTime = value
                    note.dueAt = value ? Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: day) : day
                }
            })
    }
}
