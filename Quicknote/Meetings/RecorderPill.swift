import AppKit
import QuicknoteKit
import SwiftUI

/// The floating pill (S17). It never takes focus, so the call or app in front stays in front.
final class RecorderPill {
    private var panel: NSPanel?

    func show(for recorder: MeetingRecorder) {
        let panel = panel ?? makePanel(for: recorder)
        self.panel = panel
        panel.orderFrontRegardless()
        resize()
    }

    func hide() { panel?.orderOut(nil) }

    func announce(_ message: String) {
        guard let panel else { return }
        NSAccessibility.post(
            element: panel, notification: .announcementRequested,
            userInfo: [.announcement: message, .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }

    private func makePanel(for recorder: MeetingRecorder) -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let view = RecorderPillView(recorder: recorder) { [weak self] in self?.resize() }
        panel.contentView = NSHostingView(rootView: view)
        return panel
    }

    private func resize() {
        guard let panel, let view = panel.contentView, let screen = NSScreen.main else { return }
        let size = view.fittingSize
        let frame = screen.visibleFrame
        panel.setFrame(
            NSRect(
                x: frame.midX - size.width / 2, y: frame.maxY - size.height - 12, width: size.width, height: size.height
            ),
            display: true)
    }
}

struct RecorderPillView: View {
    let recorder: MeetingRecorder
    let layoutChanged: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            pill
            if recorder.macAudioIsSilent { fixItBanner }
            if let atMs = recorder.bookmarkedAtMs { toast("Bookmarked at \(MeetingTime.format(ms: atMs))") }
            if let problem = recorder.problem { toast(problem) }
        }
        .fixedSize()
        .onChange(of: recorder.macAudioIsSilent) { layoutChanged() }
        .onChange(of: recorder.bookmarkedAtMs) { layoutChanged() }
        .onChange(of: recorder.problem) { layoutChanged() }
        .onChange(of: recorder.timeline.phase) { layoutChanged() }
        .onChange(of: recorder.outcome) { layoutChanged() }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private var pill: some View {
        if let outcome = recorder.outcome {
            savedPill(outcome)
        } else if let progress = recorder.progress {
            row { Text(progress).bold() }.accessibilityLabel(progress)
        } else if recorder.timeline.phase != .idle {
            recordingPill
        }
    }

    private var recordingPill: some View {
        row {
            Circle().fill(recorder.timeline.phase == .paused ? .orange : .red).frame(width: 9, height: 9)
                .accessibilityHidden(true)
            Text(recorder.title).bold().lineLimit(1).frame(maxWidth: 180)
            TimelineView(.periodic(from: .now, by: 0.5)) { context in
                Text(MeetingTime.format(ms: recorder.elapsedMs(at: context.date))).monospacedDigit()
                    .accessibilityLabel("Elapsed \(MeetingTime.format(ms: recorder.elapsedMs(at: context.date)))")
            }
            if recorder.hasMicrophone { levels("Mic", speaker: .me) }
            if recorder.hasMacAudio { levels("Mac audio", speaker: .others) }
            controls
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(recorder.timeline.phase == .paused ? "Recording paused" : "Recording")
    }

    private var controls: some View {
        HStack(spacing: 6) {
            Button {
                recorder.bookmark()
            } label: {
                Text("Bookmark \(Text(shortcutName).foregroundStyle(.secondary))")
            }
            .disabled(!recorder.timeline.canBookmark)
            .accessibilityLabel("Bookmark this moment")
            Button(recorder.timeline.phase == .paused ? "Resume" : "Pause") { recorder.togglePause() }
            Button("Stop", role: .destructive) { Task { await recorder.stop() } }
                .accessibilityHint("Saves the meeting and its transcript")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func levels(_ name: String, speaker: Speaker) -> some View {
        HStack(spacing: 4) {
            Text(name).font(.caption).foregroundStyle(.secondary)
            TimelineView(.periodic(from: .now, by: 0.1)) { _ in
                LevelBars(level: recorder.level(of: speaker))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name) level")
    }

    private func savedPill(_ outcome: RecordingOutcome) -> some View {
        row {
            Circle().fill(.green).frame(width: 9, height: 9).accessibilityHidden(true)
            Text("Saved").bold()
            if let note = outcome.summaryNote { Text(note).font(.caption).foregroundStyle(.secondary) }
            Button("Open") {
                MeetingsFeature.open(meetingId: outcome.meetingId, atMs: 0)
                recorder.dismissOutcome()
            }
            Button("Close") { recorder.dismissOutcome() }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private var fixItBanner: some View {
        row {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange).accessibilityHidden(true)
            Text("No Mac audio is coming through. Allow Quicknote under Screen & System Audio Recording.").font(
                .caption)
            Button("Open Settings") { Permissions.open(.systemAudio) }.buttonStyle(.bordered).controlSize(.small)
        }
    }

    private func toast(_ message: String) -> some View {
        row { Text(message).font(.caption) }.accessibilityLabel(message)
    }

    private func row<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 12, content: content)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(.regularMaterial, in: Capsule())
    }

    private var shortcutName: String {
        Shortcuts.label(for: .bookmarkMeeting)
    }
}

private struct LevelBars: View {
    private static let shape: [CGFloat] = [0.5, 0.9, 0.4, 0.75]
    let level: Float

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Self.shape.indices, id: \.self) { index in
                Capsule().fill(.tint).frame(width: 3, height: max(3, 16 * Self.shape[index] * CGFloat(level)))
            }
        }
        .frame(height: 16)
    }
}
