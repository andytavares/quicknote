import AppKit
import QuicknoteKit
import SwiftUI

/// Attachments, "Linked from" backlinks, and where an action item came from (S10).
struct EditorFooter: View {
    let model: NoteEditorModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !model.attachments.isEmpty { attachmentRow }
            if !model.backlinks.isEmpty { backlinkRow }
            if let meeting = model.meeting, let atMs = model.note?.sourceMs, let meetingId = meeting.id {
                Button("From \(meeting.title) at \(MeetingTime.format(ms: atMs))") {
                    MeetingsFeature.open(meetingId: meetingId, atMs: atMs)
                }
                .accessibilityLabel("Open meeting \(meeting.title) at \(MeetingTime.format(ms: atMs))")
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var attachmentRow: some View {
        HStack {
            Text("Attachments").font(.caption).foregroundStyle(.secondary)
            ForEach(model.attachments) { attachment in
                HStack(spacing: 2) {
                    Button(attachment.fileName) { NSWorkspace.shared.open(model.fileURL(for: attachment)) }
                        .accessibilityLabel("Open \(attachment.fileName)")
                    Button("Remove", systemImage: "xmark") { model.remove(attachment) }
                        .labelStyle(.iconOnly)
                        .accessibilityLabel("Remove \(attachment.fileName)")
                }
            }
        }
    }

    private var backlinkRow: some View {
        HStack {
            Text("Linked from").font(.caption).foregroundStyle(.secondary)
            ForEach(model.backlinks) { source in
                Button(source.title) { if let id = source.id { LibraryFeature.open(noteId: id) } }
                    .accessibilityLabel("Open note \(source.title)")
            }
        }
    }
}
