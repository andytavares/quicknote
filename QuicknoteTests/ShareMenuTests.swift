import AppKit
import Testing

@testable import Quicknote

@MainActor
struct ShareMenuTests {
    private let payload = SharePayload(
        image: SnapTestSupport.image(width: 20, height: 10), caption: "too cramped!", noteId: 1)

    private func pasteboard() -> NSPasteboard {
        NSPasteboard(name: NSPasteboard.Name("app.quicknote.tests.\(UUID().uuidString)"))
    }

    private final class Recorder {
        var opened: [URL] = []
    }

    @Test func copyImageWritesOnePasteboardItemWithPNGAndCaption() throws {
        let board = pasteboard()
        ShareActions.copyImage(of: payload, to: board)
        let item = try #require(board.pasteboardItems?.first)
        #expect(board.pasteboardItems?.count == 1)
        #expect(item.string(forType: .string) == "too cramped!")
        let png = try #require(item.data(forType: .png))
        #expect(NSBitmapImageRep(data: png)?.pixelsWide == 20)
    }

    @Test func slackCopiesThenOpensTheSlackScheme() {
        let board = pasteboard()
        let recorder = Recorder()
        let opener = SlackOpener(
            appURL: { URL(filePath: "/Applications/Slack.app") }, open: { recorder.opened.append($0) })
        let outcome = ShareActions.shareToSlack(payload, pasteboard: board, opener: opener)
        #expect(outcome == .copiedPasteInSlack)
        #expect(outcome.message == "Copied — paste in Slack with ⌘V")
        #expect(recorder.opened.map(\.absoluteString) == ["slack://open"])
        #expect(board.pasteboardItems?.first?.string(forType: .string) == "too cramped!")
    }

    @Test func withoutSlackItSaysSoStillCopiesAndOpensNothing() {
        let board = pasteboard()
        let recorder = Recorder()
        let opener = SlackOpener(appURL: { nil }, open: { recorder.opened.append($0) })
        let outcome = ShareActions.shareToSlack(payload, pasteboard: board, opener: opener)
        #expect(outcome == .slackNotInstalled)
        #expect(outcome.message.contains("Slack isn't installed"))
        #expect(recorder.opened.isEmpty)
        #expect(board.pasteboardItems?.first?.data(forType: .png) != nil)
    }

    @Test func captionlessPayloadCopiesOnlyTheImage() {
        let board = pasteboard()
        ShareActions.copyImage(of: SharePayload(image: payload.image, caption: "", noteId: 1), to: board)
        #expect(board.pasteboardItems?.first?.string(forType: .string) == nil)
    }
}
