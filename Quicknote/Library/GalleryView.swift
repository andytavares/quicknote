import AppKit
import QuicknoteKit
import SwiftUI

/// Snaps or Cards as a grid of previews (S24). A click selects, a double-click opens the editor.
struct GalleryView: View {
    @Bindable var model: LibraryModel

    var body: some View {
        VStack(spacing: 0) {
            Picker("Gallery", selection: kind) {
                ForEach(GalleryKind.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden().frame(width: 220).padding(8)
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 16)], spacing: 16) {
                    ForEach(model.galleryNotes) { note in cell(for: note) }
                }
                .padding(16)
            }
            .focusable()
            .focusEffectDisabled()
            .onDeleteCommand { model.pendingDeletion = model.selection }
            .overlay {
                if model.galleryNotes.isEmpty { ContentUnavailableView("Nothing saved yet", systemImage: "photo") }
            }
        }
        .navigationTitle(model.section.title)
    }

    private var kind: Binding<GalleryKind> {
        Binding(
            get: { model.section.galleryKind ?? .snap },
            set: { model.section = $0 == .snap ? .snaps : .cards })
    }

    private func cell(for note: Note) -> some View {
        let noteId = note.id ?? 0
        let isSelected = model.selection.contains(noteId)
        return VStack(alignment: .leading, spacing: 4) {
            thumbnail(for: note)
            Text(note.title.isEmpty ? "Untitled" : note.title).lineLimit(1)
            Text(note.createdAt.formatted(.dateTime.weekday(.abbreviated).hour().minute()))
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(6)
        .background(isSelected ? Color.accentColor.opacity(0.25) : .clear, in: .rect(cornerRadius: 8))
        .contentShape(.rect)
        .onTapGesture(count: 2) { edit(note) }
        .onTapGesture { select(noteId) }
        .contextMenu { menu(for: note) }
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { select(noteId) }
        .accessibilityAction(named: "Open") { edit(note) }
    }

    /// ⌘-click adds or removes; a plain click selects only this one.
    private func select(_ noteId: Int64) {
        guard NSEvent.modifierFlags.contains(.command) else { return model.selection = [noteId] }
        if model.selection.remove(noteId) == nil { model.selection.insert(noteId) }
    }

    @ViewBuilder private func menu(for note: Note) -> some View {
        let noteId = note.id ?? 0
        Button("Open") { edit(note) }
        Button("Copy Image") { copyPreview(of: note) }.disabled(previewImage(for: note) == nil)
        Button("Show in Finder") { showInFinder(note) }.disabled(model.previewURLs[noteId] == nil)
        Divider()
        Button("Delete…", role: .destructive) {
            model.pendingDeletion = model.selection.contains(noteId) ? model.selection : [noteId]
        }
    }

    private func previewImage(for note: Note) -> NSImage? {
        note.id.flatMap { model.previewURLs[$0] }.flatMap { NSImage(contentsOf: $0) }
    }

    private func copyPreview(of note: Note) {
        guard let noteId = note.id,
            let image = previewImage(for: note)?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return }
        ShareActions.copyImage(of: SharePayload(image: image, caption: "", noteId: noteId))
    }

    private func showInFinder(_ note: Note) {
        guard let url = note.id.flatMap({ model.previewURLs[$0] }) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    @ViewBuilder private func thumbnail(for note: Note) -> some View {
        if let image = previewImage(for: note) {
            Image(nsImage: image).resizable().scaledToFit().frame(height: 120).frame(maxWidth: .infinity)
        } else {
            RoundedRectangle(cornerRadius: 8).fill(.quaternary).frame(height: 120)
                .overlay { Image(systemName: "photo").foregroundStyle(.secondary) }
        }
    }

    private func edit(_ note: Note) {
        guard let noteId = note.id else { return }
        if GalleryKind.classify(note) == .card {
            CardsFeature.edit(noteId: noteId)
        } else {
            SnapFeature.edit(noteId: noteId)
        }
    }
}
