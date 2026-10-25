import AppKit
import Foundation
import QuicknoteKit
import Testing

@testable import Quicknote

private let now = Date(timeIntervalSince1970: 1_792_000_000)
private let calendar = Calendar(identifier: .gregorian)
private let slack = CapturedContext(
    appBundleId: "com.tinyspeck.slackmacgap", appName: "Slack", siteHost: nil, url: nil)
private let figma = CapturedContext(
    appBundleId: "com.google.Chrome", appName: "Chrome", siteHost: "figma.com",
    url: "https://www.figma.com/design/pricing-v3")

struct CaptureDraftTests {
    @Test func classificationFillsKindDueAndRecurrence() {
        let draft = CaptureDraft(text: "water plants every tue and thu")
        let note = draft.makeNote(now: now, calendar: calendar)
        #expect(note.kind == .task)
        #expect(note.recurrence != nil)
    }

    @Test func timedEventKeepsDueAndTime() {
        let note = CaptureDraft(text: "Call Mira tomorrow at 10").makeNote(now: now, calendar: calendar)
        #expect(note.kind == .event)
        #expect(note.dueHasTime)
        #expect(note.dueAt != nil)
    }

    @Test func manualKindBeatsDetectedKind() {
        var draft = CaptureDraft(text: "Call Mira tomorrow at 10")
        draft.manualKind = .idea
        let note = draft.makeNote(now: now, calendar: calendar)
        #expect(note.kind == .idea)
        #expect(note.dueAt != nil)
    }

    @Test func contextFieldsColourAndProjectAreCopied() {
        var draft = CaptureDraft(text: "Lisbon was lovely", colorHex: "#C8DDF6", projectId: 4, context: slack)
        draft.pinsToContext = true
        let note = draft.makeNote(now: now, calendar: calendar)
        #expect(note.appBundleId == "com.tinyspeck.slackmacgap")
        #expect(note.appName == "Slack")
        #expect(note.color == "#C8DDF6")
        #expect(note.projectId == 4)
        #expect(note.pinnedToContext)
    }

    @Test func pinNeedsContext() {
        var draft = CaptureDraft(text: "Lisbon was lovely")
        draft.pinsToContext = true
        #expect(!draft.makeNote(now: now, calendar: calendar).pinnedToContext)
    }

    @Test func pastedLinkIsABookmarkTitledWithItsHost() {
        let note = CaptureDraft(text: "https://www.apple.com/macos/", context: slack).makeNote(
            now: now, calendar: calendar)
        #expect(note.kind == .bookmark)
        #expect(note.title == "www.apple.com")
        #expect(note.url == "https://www.apple.com/macos/")
    }

    @Test func pastedLinkEqualToContextUrlStaysBookmark() {
        let note = CaptureDraft(text: "https://www.figma.com/design/pricing-v3", context: figma).makeNote(
            now: now, calendar: calendar)
        #expect(note.kind == .bookmark)
        #expect(note.siteHost == "figma.com")
        #expect(note.body.hasSuffix("https://www.figma.com/design/pricing-v3"))
    }

    @Test func tabCyclesThroughTypesAndWraps() {
        var draft = CaptureDraft(text: "Lisbon was lovely")
        var seen: [NoteKind] = []
        for _ in 0..<CaptureDraft.cycleOrder.count + 1 {
            draft.cycleKind(now: now, calendar: calendar)
            seen.append(draft.manualKind!)
        }
        #expect(seen.first == .todoList)
        #expect(seen.last == .todoList)
        #expect(Set(seen) == Set(CaptureDraft.cycleOrder))
        #expect(!seen.contains(.context))
    }

    @Test func blankTextWithoutFilesIsEmpty() {
        var draft = CaptureDraft(text: " \n ")
        #expect(draft.isEmpty)
        draft.attachments = [URL(filePath: "/tmp/a.pdf")]
        #expect(!draft.isEmpty)
    }
}

struct StopNoteTests {
    @Test func bodyHasTitleAndThreeLabelledLines() {
        let stop = StopNote(
            done: "Edge tabs", blocked: " Chrome hides the URL ", next: "Try Apple Events", context: slack)
        #expect(
            stop.body
                == "Where I stopped — Slack\nDone: Edge tabs\nBlocked: Chrome hides the URL\nNext: Try Apple Events"
        )
        let note = stop.makeNote(now: now)
        #expect(note.kind == .context)
        #expect(note.appBundleId == "com.tinyspeck.slackmacgap")
        #expect(note.title == "Where I stopped — Slack")
    }

    @Test func emptyFieldsAreEmpty() {
        #expect(StopNote(done: " ").isEmpty)
        #expect(!StopNote(next: "x").isEmpty)
    }
}

struct ImageTextReaderTests {
    @Test func readsKnownTextFromRenderedImage() async throws {
        let url = try renderedImage(text: "Quarterly pricing review")
        let text = try #require(await ImageTextReader.text(inImageAt: url))
        #expect(text.localizedCaseInsensitiveContains("pricing"))
    }

    @Test func fallsBackToFastWhenAccurateThrows() async {
        struct NoNeuralEngine: Error {}
        let lines = await ImageTextReader.lines { level in
            if level == .accurate { throw NoNeuralEngine() }
            return ["Invoice number 4821"]
        }
        #expect(lines == ["Invoice number 4821"])
    }

    @Test func noTextWhenEveryLevelThrows() async {
        struct NoNeuralEngine: Error {}
        let lines = await ImageTextReader.lines { _ in throw NoNeuralEngine() }
        #expect(lines.isEmpty)
    }

    @Test func importerStoresImageTextForSearch() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let database = try AppDatabase.inMemory()
        let store = AttachmentStore(paths: AppPaths(root: root), database: database)
        var note = Note(body: "Scan")
        try NoteRepository(database: database).save(&note, now: now)
        let image = try renderedImage(text: "Invoice number 4821")
        await AttachmentImporter.importFiles([image], toNoteId: note.id!, using: store)
        let attachment = try #require(try store.attachments(of: note.id!).first)
        #expect(attachment.kind == .image)
        #expect(attachment.extractedText?.contains("4821") == true)
    }
}

private func renderedImage(text: String) throws -> URL {
    let size = NSSize(width: 800, height: 200)
    let image = NSImage(size: size, flipped: false) { rect in
        NSColor.white.setFill()
        rect.fill()
        text.draw(
            at: NSPoint(x: 20, y: 80),
            withAttributes: [.font: NSFont.systemFont(ofSize: 64), .foregroundColor: NSColor.black])
        return true
    }
    let tiff = try #require(image.tiffRepresentation)
    let bitmap = try #require(NSBitmapImageRep(data: tiff))
    let data = try #require(bitmap.representation(using: .png, properties: [:]))
    let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).png")
    try data.write(to: url)
    return url
}
