import AppKit
import QuicknoteKit
import SwiftUI

/// Snaps or Cards as a grid of previews (S24). A click reopens the note in its editor.
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
        Button {
            edit(note)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                thumbnail(for: note)
                Text(note.title.isEmpty ? "Untitled" : note.title).lineLimit(1)
                Text(note.createdAt.formatted(.dateTime.weekday(.abbreviated).hour().minute()))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Edit \(note.title)")
    }

    @ViewBuilder private func thumbnail(for note: Note) -> some View {
        let image = note.id.flatMap { model.previewURLs[$0] }.flatMap { NSImage(contentsOf: $0) }
        if let image {
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
