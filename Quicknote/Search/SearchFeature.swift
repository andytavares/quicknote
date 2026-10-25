import AppKit
import QuicknoteKit
import SwiftUI

/// Search panel (S15): ⌃⌥F opens it over any app.
enum SearchFeature {
    private static var panel: SearchPanel?
    private static var focusLossObserver: NSObjectProtocol?
    private static let model = makeModel()

    static func showPanel() {
        model.requestFocus()
        if let panel, panel.isVisible {
            panel.makeKeyAndOrderFront(nil)
            return
        }
        let panel = SearchPanel(contentView: NSView())
        installContent(in: panel)
        panel.centerOnMouseScreen()
        panel.makeKeyAndOrderFront(nil)
        closeWhenFocusIsLost(panel)
        self.panel = panel
    }

    static func perform(_ action: SearchOpenAction) {
        switch action {
        case .note(let id): LibraryFeature.open(noteId: id)
        case .meeting(let id, let atMs): MeetingsFeature.open(meetingId: id, atMs: atMs)
        }
    }

    private static func makeModel() -> SearchModel {
        let index = SearchIndex(database: AppEnvironment.current.database)
        return SearchModel { query in (try? index.search(query, limitPerGroup: 8).rows) ?? [] }
    }

    private static func installContent(in panel: SearchPanel) {
        let view = SearchView(
            model: model,
            open: { row in
                perform(row.openAction); panel.close()
            },
            showLibrary: {
                LibraryFeature.show(); panel.close()
            })
        let host = NSHostingView(rootView: view)
        panel.contentView = host
        panel.setContentSize(host.fittingSize)
    }

    private static func closeWhenFocusIsLost(_ panel: SearchPanel) {
        focusLossObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: panel, queue: .main
        ) { _ in MainActor.assumeIsolated { panel.close() } }
    }
}
