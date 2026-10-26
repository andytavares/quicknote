import CoreGraphics
import Foundation
import QuicknoteKit
import Testing

@testable import Quicknote

@MainActor
struct SnapSaverTests {
    private func makeSaver() throws -> SnapSaver {
        let root = FileManager.default.temporaryDirectory.appending(
            path: UUID().uuidString, directoryHint: .isDirectory)
        let paths = AppPaths(root: root)
        try paths.createDirectories()
        let database = try AppDatabase.inMemory()
        return SnapSaver(
            repository: NoteRepository(database: database),
            attachments: AttachmentStore(paths: paths, database: database))
    }

    private let original = SnapTestSupport.image(width: 120, height: 80)
    private var document: CanvasDocument {
        var document = CanvasDocument(background: .image(attachmentId: 0, size: CGSize(width: 120, height: 80)))
        document.add(CanvasElement(kind: .box, frame: CGRect(x: 10, y: 10, width: 50, height: 30)))
        return document
    }

    @Test func aNewSnapKeepsTheOriginalThePreviewAndTheCanvas() async throws {
        let saver = try makeSaver()
        let id = try await saver.save(SnapContent(original: original, document: document), noteId: nil, now: Date())
        let note = try #require(try saver.repository.note(id: id))
        let attachments = try saver.attachments.attachments(of: id)
        #expect(note.onEdge && note.kind == .note)
        #expect(note.body.hasPrefix("Snap · "))
        #expect(attachments.map(\.kind) == [.image, .snap])
        #expect(attachments.map(\.fileName) == ["snap.png", "preview.png"])
        #expect(
            note.canvas?.background == .image(attachmentId: attachments[0].id!, size: CGSize(width: 120, height: 80)))
        #expect(note.canvas?.elements.count == 1)
    }

    @Test func aCaptureIsSavedBeforeAnyMarkup() async throws {
        let saver = try makeSaver()
        let id = try await saver.saveCapture(original, now: Date())
        let note = try #require(try saver.repository.note(id: id))
        let attachments = try saver.attachments.attachments(of: id)
        #expect(note.onEdge && note.body.hasPrefix("Snap · "))
        #expect(attachments.map(\.fileName) == ["snap.png", "preview.png"])
        #expect(
            note.canvas?.background == .image(attachmentId: attachments[0].id!, size: CGSize(width: 120, height: 80)))
        #expect(note.canvas?.elements.isEmpty == true)
    }

    @Test func savingAgainReplacesThePreviewAndKeepsTheOriginal() async throws {
        let saver = try makeSaver()
        let id = try await saver.save(SnapContent(original: original, document: document), noteId: nil, now: Date())
        var edited = document
        edited.caption = "Button padding collapses"
        _ = try await saver.save(SnapContent(original: original, document: edited), noteId: id, now: Date())
        let attachments = try saver.attachments.attachments(of: id)
        #expect(attachments.filter { $0.fileName == "preview.png" }.count == 1)
        #expect(attachments.filter { $0.kind == .image }.count == 1)
        #expect(try saver.repository.note(id: id)?.body == "Button padding collapses")
    }

    @Test func replacingThePreviewDeletesTheOldFile() throws {
        let saver = try makeSaver()
        var note = Note(body: "x")
        try saver.repository.save(&note, now: Date())
        try saver.replacePreview(original, noteId: note.id!)
        let first = try #require(try saver.attachments.attachments(of: note.id!).first)
        try saver.replacePreview(original, noteId: note.id!)
        #expect(!FileManager.default.fileExists(atPath: saver.attachments.fileURL(for: first).path))
        #expect(try saver.attachments.attachments(of: note.id!).count == 1)
    }
}
