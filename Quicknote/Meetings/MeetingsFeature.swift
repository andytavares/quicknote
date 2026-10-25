import AppKit
import SwiftUI

/// Meeting recorder and detail (S17, S18). Owned by the Meetings unit.
enum MeetingsFeature {
    private static let recorder = MeetingRecorder()
    private static var startSheet: KeyPanel?

    static var isRecording: Bool { recorder.isRecording }

    /// Idle: opens the start sheet. Recording or paused: stops and saves.
    static func toggleRecording() {
        switch recorder.timeline.phase {
        case .idle: showStartSheet()
        case .recording, .paused: Task { await recorder.stop() }
        case .finishing: break
        }
    }

    /// Adds a bookmark at the current second; does nothing when no meeting is recording.
    static func bookmark() { recorder.bookmark() }

    /// Opens a meeting at a moment, used by tasks that came from an action item.
    static func open(meetingId: Int64, atMs: Int) {
        MeetingWindow.show(meetingId: meetingId, atMs: atMs)
    }

    private static func showStartSheet() {
        if let startSheet {
            startSheet.makeKeyAndOrderFront(nil)
            return
        }
        let title = "Meeting \(Date().formatted(.dateTime.day().month(.abbreviated).hour().minute()))"
        let view = StartMeetingView(title: title, cancel: closeStartSheet) { title, microphone, macAudio in
            closeStartSheet()
            Task { await recorder.start(title: title, microphone: microphone, macAudio: macAudio) }
        }
        let host = NSHostingView(rootView: view)
        let panel = KeyPanel(contentView: host)
        panel.setContentSize(host.fittingSize)
        panel.centerOnMouseScreen()
        panel.makeKeyAndOrderFront(nil)
        startSheet = panel
    }

    private static func closeStartSheet() {
        startSheet?.close()
        startSheet = nil
    }
}
