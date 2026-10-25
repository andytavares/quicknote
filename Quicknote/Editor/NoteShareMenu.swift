import AppKit
import QuicknoteKit
import SwiftUI

/// Share the text with any system service, or save the note as a Markdown file.
struct NoteShareMenu: View {
    let model: NoteEditorModel

    var body: some View {
        Menu("Share", systemImage: "square.and.arrow.up") {
            ShareLink("Share text…", item: model.note?.body ?? "")
            Button("Export as Markdown…") { exportMarkdown() }
        }
        .menuIndicator(.hidden)
        .labelStyle(.iconOnly)
        .accessibilityLabel("Share")
        .fixedSize()
    }

    /// The exporter writes into a folder, so it runs in a temporary one and the files move to the chosen place.
    private func exportMarkdown() {
        guard let note = model.note else { return }
        let scratch = FileManager.default.temporaryDirectory.appending(
            path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: scratch) }
        do {
            let exporter = MarkdownExporter(paths: AppEnvironment.current.paths)
            let written = try exporter.export(note, attachments: model.attachments, to: scratch)
            let panel = NSSavePanel()
            panel.nameFieldStringValue = written.lastPathComponent
            guard panel.runModal() == .OK, let destination = panel.url else { return }
            try move(written, to: destination, from: scratch)
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }

    private func move(_ written: URL, to destination: URL, from scratch: URL) throws {
        let fileManager = FileManager.default
        let folder = destination.deletingLastPathComponent()
        let attachmentFolder = scratch.appending(path: written.deletingPathExtension().lastPathComponent)
        if fileManager.fileExists(atPath: attachmentFolder.path) {
            try fileManager.copyItem(
                at: attachmentFolder, to: folder.appending(path: attachmentFolder.lastPathComponent))
        }
        try? fileManager.removeItem(at: destination)
        try fileManager.copyItem(at: written, to: destination)
    }
}
