import AppKit
import QuicknoteKit
import SwiftUI

/// One window per meeting; opening the same meeting again brings it forward and seeks.
enum MeetingWindow {
    private static var windows: [Int64: (window: NSWindow, model: MeetingModel)] = [:]

    static func show(meetingId: Int64, atMs: Int) {
        if let open = windows[meetingId] {
            open.model.reload()
            open.model.seek(toMs: atMs)
            open.window.makeKeyAndOrderFront(nil)
            return NSApp.activate()
        }
        let repository = MeetingRepository(database: AppEnvironment.current.database)
        guard let meeting = try? repository.meeting(id: meetingId) else { return }
        let model = MeetingModel(meeting: meeting, atMs: atMs)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = meeting.title
        window.contentViewController = NSHostingController(rootView: MeetingView(model: model))
        window.isReleasedWhenClosed = false
        window.center()
        windows[meetingId] = (window, model)
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) {
            _ in
            MainActor.assumeIsolated {
                model.close()
                windows[meetingId] = nil
            }
        }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }
}
