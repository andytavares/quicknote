import QuicknoteKit
import SwiftUI

/// The editor for one note (S10 right pane). The Library window embeds it.
struct NoteEditorView: View {
    let noteId: Int64

    var body: some View {
        NoteEditorContent(noteId: noteId).id(noteId)
    }
}

/// Owns the model for one note id; `.id(noteId)` above gives each note a fresh one.
private struct NoteEditorContent: View {
    @State private var model: NoteEditorModel

    init(noteId: Int64) {
        _model = State(initialValue: NoteEditorModel(noteId: noteId))
    }

    var body: some View {
        Group {
            if let note = model.note {
                editor(note)
            } else {
                ContentUnavailableView("Note not found", systemImage: "note.text")
            }
        }
        .task { await model.observeChanges() }
        .onDisappear { model.flush() }
        .alert(
            "Couldn't finish",
            isPresented: Binding(get: { model.errorMessage != nil }, set: { _ in model.errorMessage = nil })
        ) {
            Button("OK") {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private func editor(_ note: Note) -> some View {
        VStack(spacing: 0) {
            EditorToolbar(model: model)
            Divider()
            ZStack(alignment: .bottomLeading) {
                NoteTextView(model: model)
                if model.suggestionRowCount > 0 { LinkSuggestionList(model: model).padding(12) }
            }
            Divider()
            EditorFooter(model: model)
        }
        .background(Color(hex: note.color))
        .confirmationDialog("Also remove from Calendar?", isPresented: removalQuestion) {
            Button("Remove from Calendar") { model.answerRemoveFromCalendar(true) }
            Button("Keep the event") { model.answerRemoveFromCalendar(false) }
            Button("Cancel", role: .cancel) { model.kindAwaitingRemovalAnswer = nil }
        }
        .confirmationDialog("Delete this note?", isPresented: $model.isConfirmingDelete) {
            deleteButtons(for: note)
        }
    }

    @ViewBuilder private func deleteButtons(for note: Note) -> some View {
        if note.calendarEventId != nil {
            Button("Delete note and Calendar event", role: .destructive) { model.deleteNote(removingEvent: true) }
            Button("Delete note, keep Calendar event", role: .destructive) { model.deleteNote(removingEvent: false) }
        } else {
            Button("Delete", role: .destructive) { model.deleteNote(removingEvent: false) }
        }
        Button("Cancel", role: .cancel) {}
    }

    private var removalQuestion: Binding<Bool> {
        Binding(
            get: { model.kindAwaitingRemovalAnswer != nil }, set: { if !$0 { model.kindAwaitingRemovalAnswer = nil } })
    }
}
