import CoreGraphics
import Foundation
import QuicknoteKit
import Testing

@testable import Quicknote

@MainActor
struct CardTests {
    private func render(_ style: CardStyle) throws -> CGImage {
        let document = CanvasDocument(background: .card(style: style, size: .square))
        let resources = CanvasResources(image: { _ in nil }, paintBackground: CardBackgroundPainter.paint)
        return try #require(CanvasRenderer.render(document, resources: resources))
    }

    private func expectPaper(_ image: CGImage, x: Int, y: Int, _ style: CardStyle) {
        let digits = UInt32(style.paperColorHex.dropFirst(), radix: 16)!
        let expected = (Int(digits >> 16 & 0xFF), Int(digits >> 8 & 0xFF), Int(digits & 0xFF))
        let actual = SnapTestSupport.pixel(image, x: x, y: y)
        #expect(abs(actual.red - expected.0) <= 2 && abs(actual.green - expected.1) <= 2)
        #expect(abs(actual.blue - expected.2) <= 2)
    }

    private func brightness(_ image: CGImage, x: Int, y: Int) -> Int {
        let pixel = SnapTestSupport.pixel(image, x: x, y: y)
        return pixel.red + pixel.green + pixel.blue
    }

    // MARK: Painters

    @Test func everyStyleFillsItsPaperColourAwayFromItsMarks() throws {
        for style in [CardStyle.sticky, .postcard, .lined, .minimal] {
            expectPaper(try render(style), x: 300, y: 560, style)
        }
    }

    @Test func stickyHasAShadowBandAtTheTop() throws {
        let image = try render(.sticky)
        #expect(brightness(image, x: 300, y: 20) < brightness(image, x: 300, y: 300) - 30)
    }

    @Test func postcardHasADividerAndAddressLinesOnTheRight() throws {
        let image = try render(.postcard)
        #expect(brightness(image, x: 540, y: 500) < brightness(image, x: 300, y: 500) - 100)
        #expect(brightness(image, x: 800, y: 540) < brightness(image, x: 800, y: 590) - 100)
    }

    @Test func polaroidHasAPictureWindowAndAThickerBottomFrame() throws {
        let image = try render(.polaroid)
        expectPaper(image, x: 20, y: 500, .polaroid)  // side frame
        expectPaper(image, x: 500, y: 20, .polaroid)  // top frame
        #expect(brightness(image, x: 500, y: 500) < brightness(image, x: 20, y: 500))  // window
        expectPaper(image, x: 500, y: 900, .polaroid)  // bottom frame is taller than the top one
    }

    @Test func linedHasRuledLinesAndAMargin() throws {
        let image = try render(.lined)
        #expect(brightness(image, x: 600, y: 135) < brightness(image, x: 600, y: 160) - 60)  // line at 3 x 45
        #expect(brightness(image, x: 130, y: 500) < brightness(image, x: 300, y: 500) - 60)  // margin at 12%
    }

    @Test func kraftIsTexturedAndTheSameEveryTime() throws {
        let first = try render(.kraft)
        let second = try render(.kraft)
        let row = (0..<400).map { brightness(first, x: $0, y: 500) }
        #expect(Set(row).count > 5)
        #expect(row == (0..<400).map { brightness(second, x: $0, y: 500) })
    }

    // MARK: Model

    private func makeSaver() throws -> CardSaver {
        let root = FileManager.default.temporaryDirectory.appending(
            path: UUID().uuidString, directoryHint: .isDirectory)
        let paths = AppPaths(root: root)
        try paths.createDirectories()
        let database = try AppDatabase.inMemory()
        return CardSaver(
            repository: NoteRepository(database: database),
            attachments: AttachmentStore(paths: paths, database: database))
    }

    private func makeModel(text: String? = nil) throws -> CardEditorModel {
        CardEditorModel(
            document: CardEditorModel.startingDocument(text: text), noteId: nil, saver: try makeSaver())
    }

    @Test func sizeChoicesSetThePixelSizeAndWallpaperUsesTheScreen() throws {
        let model = try makeModel()
        model.screenPixelSize = CGSize(width: 3024, height: 1964)
        let expected: [(CardSizeChoice, CGSize)] = [
            (.story, CGSize(width: 1080, height: 1920)), (.wallpaper, CGSize(width: 3024, height: 1964)),
            (.square, CGSize(width: 1080, height: 1080)),
        ]
        for (choice, size) in expected {
            model.chooseSize(choice)
            #expect(CanvasRenderer.pixelSize(of: model.document) == size)
            #expect(model.sizeChoice == choice)
        }
    }

    @Test func aCardFromANoteCarriesItsTextOnAStickyCard() throws {
        let model = try makeModel(text: "Lake day, September")
        #expect(model.document.background == .card(style: .sticky, size: .square))
        #expect(model.document.elements.map(\.kind) == [.text("Lake day, September")])
        #expect(try makeModel().document.elements.isEmpty)
    }

    @Test func aPhotoBecomesAnImageAttachmentAndAPhotoElement() throws {
        let saver = try makeSaver()
        let model = CardEditorModel(document: CardEditorModel.startingDocument(text: nil), noteId: nil, saver: saver)
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appending(path: "lake.png")
        try #require(SnapTestSupport.image(width: 40, height: 20).pngData).write(to: file)
        try model.addPhoto(fileAt: file)
        let noteId = try #require(model.noteId)
        let attachment = try #require(try saver.attachments.attachments(of: noteId).first)
        #expect(attachment.kind == .image)
        #expect(model.document.elements.map(\.kind) == [.photo(attachmentId: attachment.id!)])
        #expect(model.photos[attachment.id!] != nil)
    }

    @Test func inkPointsAreRelativeToTheFrameOrigin() {
        let element = CardEditorModel.inkElement(
            through: [CGPoint(x: 100, y: 200), CGPoint(x: 160, y: 230), CGPoint(x: 120, y: 260)], style: ElementStyle())
        #expect(element.frame == CGRect(x: 100, y: 200, width: 60, height: 60))
        #expect(element.kind == .ink(points: [CGPoint(x: 0, y: 0), CGPoint(x: 60, y: 30), CGPoint(x: 20, y: 60)]))
    }

    @Test func signingByPointerAddsOneInkElement() throws {
        let model = try makeModel()
        model.isSigning = true
        let points = [CGPoint(x: 50, y: 50), CGPoint(x: 90, y: 70), CGPoint(x: 130, y: 60)]
        model.handle(CanvasPointerEvent(phase: .began, point: points[0], zoom: 1))
        model.handle(CanvasPointerEvent(phase: .changed, point: points[1], zoom: 1))
        model.handle(CanvasPointerEvent(phase: .ended, point: points[2], zoom: 1))
        #expect(model.document.elements.count == 1)
        guard case .ink(let stored) = model.document.elements[0].kind else {
            Issue.record("not ink")
            return
        }
        #expect(stored.first == .zero)
        #expect(model.document.elements[0].frame.origin == CGPoint(x: 50, y: 50))
    }

    @Test func theMadeWithMarkPersistsInTheSavedCanvas() throws {
        let saver = try makeSaver()
        let model = CardEditorModel(document: CardEditorModel.startingDocument(text: "Hi"), noteId: nil, saver: saver)
        #expect(model.document.showsMadeWithMark == false)
        model.setShowsMadeWithMark(true)
        let id = try model.save()
        #expect(try saver.repository.note(id: id)?.canvas?.showsMadeWithMark == true)
        let attachments = try saver.attachments.attachments(of: id)
        #expect(attachments.map(\.fileName) == ["preview.png"])
        #expect(attachments.map(\.kind) == [.snap])
    }

    @Test func savingACardWhoseNoteWasDeletedReturnsTheNewNote() throws {
        let saver = try makeSaver()
        let model = CardEditorModel(document: CardEditorModel.startingDocument(text: "Hi"), noteId: nil, saver: saver)
        let first = try model.save()
        try saver.repository.delete(noteId: first)
        let second = try model.save()
        #expect(second != first)
        #expect(try saver.repository.note(id: second)?.canvas == model.document)
    }

    @Test func aCardWhoseNoteWasCreatedForAPhotoStillSavesAfterUndo() throws {
        let model = try makeModel()
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appending(path: "lake.png")
        try #require(SnapTestSupport.image(width: 40, height: 20).pngData).write(to: file)
        try model.addPhoto(fileAt: file)
        model.undo()
        #expect(model.document.elements.isEmpty)
        #expect(model.isEdited)
    }

    @Test func typingIntoOneTextIsOneUndoStep() throws {
        let model = try makeModel()
        model.addText()
        let added = model.document
        for typed in ["L", "La", "Lak", "Lake"] { model.setText(typed) }
        model.undo()
        #expect(model.document == added)
    }
}
