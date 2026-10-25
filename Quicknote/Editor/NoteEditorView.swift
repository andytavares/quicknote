import SwiftUI

/// The editor for one note (S10 right pane). Owned by the Editor unit; the Library window embeds it.
struct NoteEditorView: View {
    let noteId: Int64

    var body: some View {
        Text("Note \(noteId)")
    }
}
