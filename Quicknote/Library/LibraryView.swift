import SwiftUI

/// Sidebar and detail (S10); the toolbar holds New note, Delete and Search.
struct LibraryView: View {
    @Bindable var model: LibraryModel

    var body: some View {
        NavigationSplitView {
            LibrarySidebar(model: model)
        } detail: {
            detail
        }
        .frame(minWidth: 900, minHeight: 520)
        .toolbar { toolbarContent }
        .task { await model.observe() }
        .confirmationDialog(deletionTitle, isPresented: isConfirmingDeletion, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { model.confirmDeletion() }
        } message: {
            Text("This cannot be undone.")
        }
    }

    @ViewBuilder private var detail: some View {
        switch model.section {
        case .sites: SitesAndAppsView(model: model)
        case .meetings: MeetingListView(meetings: model.meetings)
        case .snaps, .cards: GalleryView(model: model)
        default:
            HStack(spacing: 0) {
                TaskListView(model: model).frame(minWidth: 320, idealWidth: 380, maxWidth: 420)
                Divider()
                editor.frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder private var editor: some View {
        if model.selection.count == 1, let noteId = model.selection.first {
            NoteEditorView(noteId: noteId).id(noteId)
        } else {
            ContentUnavailableView(
                model.selection.isEmpty ? "No note selected" : "\(model.selection.count) notes selected",
                systemImage: "note.text")
        }
    }

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup {
            Button("New note", systemImage: "square.and.pencil") { CaptureFeature.showPanel() }
                .help("New note")
            Button("Delete", systemImage: "trash") { model.pendingDeletion = model.selection }
                .disabled(model.selection.isEmpty)
                .help("Delete the selected notes")
            Button("Search", systemImage: "magnifyingglass") { SearchFeature.showPanel() }
                .keyboardShortcut("f", modifiers: .command)
                .help("Search (\(Shortcuts.label(for: .search)))")
        }
    }

    private var deletionTitle: String {
        let count = model.pendingDeletion.count
        return count == 1 ? "Delete this note?" : "Delete \(count) notes?"
    }

    private var isConfirmingDeletion: Binding<Bool> {
        Binding(
            get: { !model.pendingDeletion.isEmpty },
            set: { if !$0 { model.pendingDeletion = [] } })
    }
}
