import AppKit
import QuicknoteKit
import SwiftUI
import UniformTypeIdentifiers

/// What a share action sends. The note must already be saved so Markdown export can find it.
struct SharePayload {
    let image: CGImage
    let caption: String
    let noteId: Int64
}

/// How Slack is found and opened; tests replace it so no app launches.
struct SlackOpener {
    var appURL: () -> URL?
    var open: (URL) -> Void

    static let live = SlackOpener(
        appURL: { NSWorkspace.shared.urlForApplication(toOpen: ShareActions.slackURL) },
        open: { NSWorkspace.shared.open($0) })
}

enum ShareOutcome: Equatable {
    case copiedPasteInSlack, slackNotInstalled

    var message: String {
        switch self {
        case .copiedPasteInSlack: "Copied — paste in Slack with ⌘V"
        case .slackNotInstalled: "Slack isn't installed on this Mac. The image is copied; paste it where you like."
        }
    }
}

/// Every share target (S23). Slack has no share extension, so it copies and opens the app ([decision 0007]).
enum ShareActions {
    static let slackURL = URL(string: "slack://open")!

    /// One pasteboard item holding the PNG and the caption, so a paste takes whichever the target app wants.
    static func copyImage(of payload: SharePayload, to pasteboard: NSPasteboard = .general) {
        let item = NSPasteboardItem()
        if let data = payload.image.pngData { item.setData(data, forType: .png) }
        if !payload.caption.isEmpty { item.setString(payload.caption, forType: .string) }
        pasteboard.clearContents()
        pasteboard.writeObjects([item])
    }

    static func shareToSlack(
        _ payload: SharePayload, pasteboard: NSPasteboard = .general, opener: SlackOpener = .live
    ) -> ShareOutcome {
        copyImage(of: payload, to: pasteboard)
        guard opener.appURL() != nil else { return .slackNotInstalled }
        opener.open(slackURL)
        return .copiedPasteInSlack
    }

    /// Returns false when the service cannot take the items on this Mac.
    static func send(_ payload: SharePayload, via name: NSSharingService.Name) -> Bool {
        let size = CGSize(width: payload.image.width, height: payload.image.height)
        let items: [Any] = [NSImage(cgImage: payload.image, size: size), payload.caption]
        guard let service = NSSharingService(named: name), service.canPerform(withItems: items) else { return false }
        service.perform(withItems: items)
        return true
    }

    static func savePNG(_ payload: SharePayload) throws {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "Snap.png"
        guard panel.runModal() == .OK, let url = panel.url, let data = payload.image.pngData else { return }
        try data.write(to: url)
    }

    static func exportMarkdown(_ payload: SharePayload) throws {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Export"
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        let environment = AppEnvironment.current
        let store = AttachmentStore(paths: environment.paths, database: environment.database)
        guard let note = try NoteRepository(database: environment.database).note(id: payload.noteId) else { return }
        _ = try MarkdownExporter(paths: environment.paths).export(
            note, attachments: try store.attachments(of: payload.noteId), to: folder)
    }
}

/// The "Share ▾" menu. `payload` runs on every action so it always shares the latest edit
/// (the owner saves the note and renders the image there); nil cancels the action.
struct ShareMenu: View {
    let payload: () async -> SharePayload?
    @State private var notice: String?

    var body: some View {
        Menu("Share ▾") {
            Button("Messages") { send(.composeMessage, name: "Messages") }
            Button("Mail") { send(.composeEmail, name: "Mail") }
            Button("AirDrop") { send(.sendViaAirDrop, name: "AirDrop") }
            Button("Slack") { run { show(ShareActions.shareToSlack($0).message) } }
            Divider()
            Button("Copy image") { run { ShareActions.copyImage(of: $0) } }
            Button("Save as PNG…") { run { try ShareActions.savePNG($0) } }
            Button("Export as Markdown…") { run { try ShareActions.exportMarkdown($0) } }
        }
        .accessibilityLabel("Share")
        .popover(isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Text(notice ?? "").padding(12)
        }
    }

    private func run(_ action: @escaping (SharePayload) throws -> Void) {
        Task {
            guard let payload = await payload() else { return }
            do { try action(payload) } catch { show("That didn't work: \(error.localizedDescription)") }
        }
    }

    private func send(_ service: NSSharingService.Name, name: String) {
        run { if !ShareActions.send($0, via: service) { show("\(name) isn't available on this Mac.") } }
    }

    private func show(_ message: String) {
        notice = message
        Task {
            try? await Task.sleep(for: .seconds(3))
            notice = nil
        }
    }
}
