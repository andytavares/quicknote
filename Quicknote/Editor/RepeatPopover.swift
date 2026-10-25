import QuicknoteKit
import SwiftUI

/// Repeat picker (S13): presets, or free text read back in words with the next three dates.
struct RepeatPopover: View {
    let model: NoteEditorModel
    @State private var typedText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Repeat").font(.headline)
            ForEach(RepeatPreset.allCases) { preset in
                Button {
                    choose(preset.rule)
                } label: {
                    HStack {
                        Text(preset.title)
                        Spacer()
                        if model.note?.recurrence == preset.rule { Image(systemName: "checkmark") }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(preset.title)
            }
            Divider()
            Text("Or type your own").font(.caption).foregroundStyle(.secondary)
            TextField("every tue and thu", text: $typedText)
                .accessibilityLabel("Repeat in words")
            previewRows
        }
        .padding(14)
        .frame(width: 280)
    }

    @ViewBuilder private var previewRows: some View {
        if let preview = RepeatPreview.make(from: typedText, after: model.note?.dueAt ?? Date(), calendar: .current) {
            Text(preview.description)
            Text("Next: " + preview.nextDates.map(format).joined(separator: " · "))
                .font(.caption).foregroundStyle(.secondary)
            Button("Set repeat") { choose(preview.rule) }
                .accessibilityLabel("Set repeat")
        } else if !typedText.isEmpty {
            Text("Not understood yet").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func format(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    private func choose(_ rule: RecurrenceRule?) {
        model.update { $0.recurrence = rule }
    }
}
