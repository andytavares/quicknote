import AppKit
import QuicknoteKit
import SwiftUI

/// The row above the text (S10): Type, Due, Repeat, Priority, then Style, pin, share, card and delete.
struct EditorToolbar: View {
    let model: NoteEditorModel
    @State private var showsDue = false
    @State private var showsRepeat = false
    @State private var showsStyle = false

    var body: some View {
        if let note = model.note {
            // One row when it fits; a narrow pane wraps the buttons instead of squeezing them empty.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    fields(for: note)
                    Spacer()
                    actions(for: note)
                }
                FlowLayout {
                    fields(for: note)
                    actions(for: note)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder private func fields(for note: Note) -> some View {
        TypeMenu(model: model)
        Button(dueTitle(note)) { showsDue = true }
            .accessibilityLabel("Due date")
            .popover(isPresented: $showsDue) { DuePopover(model: model) }
        Button(repeatTitle(note)) { showsRepeat = true }
            .accessibilityLabel("Repeat")
            .popover(isPresented: $showsRepeat) { RepeatPopover(model: model) }
        PriorityMenu(model: model)
    }

    @ViewBuilder private func actions(for note: Note) -> some View {
        Button("Aa") { showsStyle = true }
            .accessibilityLabel("Style")
            .popover(isPresented: $showsStyle) { StylePopover(model: model) }
        if let place = note.siteHost ?? note.appName {
            Toggle(
                "Pin to \(place)",
                isOn: Binding(
                    get: { note.pinnedToContext }, set: { value in model.update { $0.pinnedToContext = value } })
            )
            .toggleStyle(.button)
            .accessibilityLabel("Pin to \(place)")
        }
        NoteShareMenu(model: model)
        Button("Make a card", systemImage: "rectangle.on.rectangle") {
            CardsFeature.newCard(fromNoteId: model.noteId)
        }
        .labelStyle(.iconOnly)
        .accessibilityLabel("Make a card")
        .help("Make a card")
        Button("Delete", systemImage: "trash") { model.isConfirmingDelete = true }
            .labelStyle(.iconOnly)
            .accessibilityLabel("Delete note")
            .help("Delete")
    }

    private func dueTitle(_ note: Note) -> String {
        guard let due = note.dueAt else { return "Due date" }
        let day = due.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        return note.dueHasTime ? "Due \(day) \(due.formatted(date: .omitted, time: .shortened))" : "Due \(day)"
    }

    private func repeatTitle(_ note: Note) -> String {
        note.recurrence.map(RecurrenceParser.describe) ?? "Repeat"
    }
}

extension NoteKind {
    /// Types offered in the Type menu (S12); "Where I stopped" notes come only from ⌃⌥S.
    static let editableKinds = allCases.filter { $0 != .context }
}

struct TypeMenu: View {
    let model: NoteEditorModel

    var body: some View {
        Menu("\(model.note?.kind.title ?? "Note") ▾") {
            Section("Turn into") {
                ForEach(NoteKind.editableKinds, id: \.self) { kind in
                    Toggle(
                        kind.title,
                        isOn: Binding(get: { model.note?.kind == kind }, set: { _ in model.changeKind(to: kind) }))
                }
            }
        }
        .accessibilityLabel("Type")
        .fixedSize()
    }
}

struct PriorityMenu: View {
    let model: NoteEditorModel
    private static let names = ["None", "Low", "Medium", "High"]

    var body: some View {
        Menu("Priority: \(Self.names[model.note?.priority ?? 0])") {
            Picker(
                "Priority",
                selection: Binding(
                    get: { model.note?.priority ?? 0 }, set: { value in model.update { $0.priority = value } })
            ) {
                ForEach(Self.names.indices, id: \.self) { Text(Self.names[$0]).tag($0) }
            }
            .pickerStyle(.inline)
        }
        .accessibilityLabel("Priority")
        .fixedSize()
    }
}
